//
//  ModelDownloader.swift
//  MindLoop
//
//  Downloads the Gemma 4 E2B-it model from HuggingFace using a background
//  URLSession so downloads continue when the app is suspended or terminated.
//  Stores files in Documents/gemma-4-e2b-it-4bit/ for persistence across updates.
//

import Foundation
import Observation
import os

/// Downloads and manages the on-device LLM model files from HuggingFace.
///
/// Uses a background `URLSession` so the 3.3GB download continues even when
/// the user backgrounds the app. iOS may relaunch the app in the background
/// to deliver completion events via `AppDelegate`.
@MainActor
@Observable
final class ModelDownloader: NSObject {

    // MARK: - Types

    enum State: Equatable {
        case idle
        case checking
        case downloading
        case ready
        case failed(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking),
                 (.downloading, .downloading), (.ready, .ready):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Shared Instance

    /// Shared downloader — the background URLSession must be a singleton so
    /// iOS can reattach in-flight tasks after an app relaunch. Declared
    /// `@MainActor` so lazy init runs on the main actor under Swift 6.
    @MainActor static let shared: ModelDownloader = ModelDownloader()

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var progress: Double = 0.0
    private(set) var statusMessage: String = ""

    var isModelAvailable: Bool { state == .ready }

    /// URL of the model directory in the app's Documents folder.
    var modelDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("gemma-4-e2b-it-4bit")
    }

    /// Set by `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    /// We invoke it once all events for the background session have been delivered.
    @ObservationIgnored var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Private

    nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.mindloop",
        category: "ModelDownloader"
    )

    /// Identifier for the background URLSession. Must be stable across app launches.
    nonisolated static let sessionIdentifier = "com.lycan.MindLoop.modelDownload"

    /// PLE-safe Gemma 4 E2B weights from Unsloth. The mlx-community
    /// variant has a quantization bug (PLE layers quantized, producing
    /// garbage output). Unsloth's UD variant preserves PLE layers in
    /// full precision. See mlx-vlm PR #893. (REC-305)
    nonisolated static let repoBase = "https://huggingface.co/unsloth/gemma-4-E2B-it-UD-MLX-4bit/resolve/main/"

    /// Files to download in order (small files first, .safetensors last).
    /// Note: unsloth variant does NOT include processor_config.json
    /// (the mlx-community variant did). Removed from required list.
    nonisolated static let requiredFiles: [(name: String, sizeBytes: Int64)] = [
        ("config.json", 6_000),
        ("tokenizer.json", 33_000_000),
        ("tokenizer_config.json", 50_000),
        ("generation_config.json", 1_000),
        ("chat_template.jinja", 5_000),
        ("model.safetensors.index.json", 2_000),
        ("model.safetensors", 3_600_000_000),
    ]

    /// Total estimated download size in bytes.
    nonisolated static let totalSizeBytes: Int64 = requiredFiles.reduce(0) { $0 + $1.sizeBytes }

    /// The background session — created lazily so we can pass `self` as delegate.
    @ObservationIgnored private var _session: URLSession?

    private var session: URLSession {
        if let existing = _session { return existing }
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true      // Wake app when download finishes
        config.isDiscretionary = false              // User-initiated; don't defer
        config.allowsCellularAccess = true
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60  // 7 days
        config.httpAdditionalHeaders = [
            "User-Agent": "MindLoop/1.0 (iOS; MLX Model Downloader)"
        ]
        // Background sessions REQUIRE delegateQueue = nil (iOS uses a private serial queue)
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        _session = session
        return session
    }

    override private init() {
        super.init()
        // Touch session to eagerly create it — iOS will reattach any in-flight tasks
        // from a prior app launch and begin delivering delegate callbacks immediately.
        _ = session
    }

    // MARK: - Public API

    /// Check if model exists locally; if not, start background downloads.
    func ensureModelAvailable() async {
        #if targetEnvironment(simulator)
        Self.logger.info("Simulator detected — skipping model download")
        state = .ready
        return
        #else
        state = .checking
        statusMessage = "Checking for AI model..."

        if verifyModelFiles() {
            Self.logger.info("Model files already present")
            state = .ready
            progress = 1.0
            return
        }

        // Reattach to any downloads already running (from a previous launch
        // or a background relaunch). If any exist, let their delegates drive
        // completion; we just update UI state.
        let runningTasks = await session.allTasks
        if !runningTasks.isEmpty {
            Self.logger.info("Reattached to \(runningTasks.count) in-flight download(s)")
            state = .downloading
            statusMessage = "Resuming download..."
            updateOverallProgress()
            return
        }

        do {
            try createModelDirectory()
            state = .downloading
            progress = completedByteCount() / Double(Self.totalSizeBytes)
            statusMessage = "Downloading AI model..."
            enqueueNextFile()
        } catch {
            Self.logger.error("Download setup failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
        #endif
    }

    /// Cancel any in-progress downloads.
    func cancelDownload() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        Task { @MainActor in
            state = .idle
            progress = 0.0
            statusMessage = ""
        }
    }

    /// Delete downloaded model files (e.g. to re-download).
    func deleteModelFiles() {
        cancelDownload()
        try? FileManager.default.removeItem(at: modelDirectoryURL)
        state = .idle
        progress = 0.0
    }

    // MARK: - Private Helpers

    private func verifyModelFiles() -> Bool {
        let fm = FileManager.default
        for file in Self.requiredFiles {
            let fileURL = modelDirectoryURL.appendingPathComponent(file.name)
            guard fm.fileExists(atPath: fileURL.path) else {
                return false
            }
        }
        return true
    }

    private func createModelDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: modelDirectoryURL.path) {
            try fm.createDirectory(at: modelDirectoryURL, withIntermediateDirectories: true)
        }
    }

    /// Sum of sizes of files already present on disk.
    private func completedByteCount() -> Double {
        var total: Int64 = 0
        for file in Self.requiredFiles {
            let dest = modelDirectoryURL.appendingPathComponent(file.name)
            if FileManager.default.fileExists(atPath: dest.path) {
                total += file.sizeBytes
            }
        }
        return Double(total)
    }

    /// Find the first missing file and enqueue a background download task for it.
    /// Marks state `.ready` if all files are present.
    private func enqueueNextFile() {
        for file in Self.requiredFiles {
            let dest = modelDirectoryURL.appendingPathComponent(file.name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                guard let url = URL(string: Self.repoBase + file.name) else {
                    state = .failed("Invalid URL for \(file.name)")
                    return
                }
                let task = session.downloadTask(with: url)
                // taskDescription survives task persistence across app launches,
                // letting us identify which file each delegate callback refers to.
                task.taskDescription = file.name
                task.resume()
                statusMessage = "Downloading \(file.name)..."
                Self.logger.info("Enqueued background download: \(file.name)")
                return
            }
        }

        // All files downloaded
        Self.logger.info("All model files present")
        state = .ready
        progress = 1.0
        statusMessage = "Model ready"
    }

    /// Recompute overall progress from current on-disk size (coarse).
    /// The fine-grained progress for the in-flight file is updated in the
    /// delegate callback itself.
    private func updateOverallProgress() {
        progress = completedByteCount() / Double(Self.totalSizeBytes)
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // CRITICAL: `location` is deleted the moment this callback returns.
        // We MUST move the file synchronously here before dispatching to main.
        guard let filename = downloadTask.taskDescription else {
            Self.logger.error("Download task missing filename")
            return
        }

        // Capture the destination path (modelDirectoryURL is MainActor-isolated,
        // so build it from scratch here on the background queue).
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelDir = documents.appendingPathComponent("gemma-4-e2b-it-4bit")
        let destination = modelDir.appendingPathComponent(filename)

        do {
            // Ensure parent directory exists (session may have been restored
            // before ensureModelAvailable() ran).
            try FileManager.default.createDirectory(
                at: modelDir,
                withIntermediateDirectories: true
            )

            // Remove any stale file at destination
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.moveItem(at: location, to: destination)
            Self.logger.info("Saved downloaded file: \(filename)")
        } catch {
            Self.logger.error("Failed to save \(filename): \(error.localizedDescription)")
            Task { @MainActor in
                self.state = .failed("Failed to save \(filename): \(error.localizedDescription)")
            }
            return
        }

        // Dispatch to main to update state and enqueue next file
        Task { @MainActor in
            self.updateOverallProgress()
            self.enqueueNextFile()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let filename = downloadTask.taskDescription else { return }

        // Find the file's declared size to compute overall progress weight
        let fileSize = Self.requiredFiles.first(where: { $0.name == filename })?.sizeBytes ?? 0
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : fileSize
        guard expected > 0 else { return }

        // Sum of completed files (excluding current) + fractional progress on current
        let completedExcludingCurrent: Int64 = Self.requiredFiles
            .filter { $0.name != filename }
            .reduce(0) { acc, file in
                let dest = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("gemma-4-e2b-it-4bit")
                    .appendingPathComponent(file.name)
                return FileManager.default.fileExists(atPath: dest.path) ? acc + file.sizeBytes : acc
            }

        let overallBytes = Double(completedExcludingCurrent) + Double(totalBytesWritten)
        let overallFraction = min(overallBytes / Double(Self.totalSizeBytes), 1.0)

        let downloadedMB = Int(totalBytesWritten / (1024 * 1024))
        let totalMB = Int(expected / (1024 * 1024))

        Task { @MainActor in
            self.progress = overallFraction
            if filename == "model.safetensors" {
                self.statusMessage = "Downloading model... \(downloadedMB) MB / \(totalMB) MB"
            } else {
                self.statusMessage = "Downloading \(filename)..."
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Only handle actual errors here; successful completion is already
        // handled by didFinishDownloadingTo above.
        guard let error else { return }

        let nsError = error as NSError
        // Ignore cancellation (user-initiated)
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        let filename = task.taskDescription ?? "unknown"
        Self.logger.error("Download failed for \(filename): \(error.localizedDescription)")

        Task { @MainActor in
            self.state = .failed("\(filename): \(error.localizedDescription)")
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // iOS has delivered all outstanding events for the background session.
        // Call the completion handler stashed by AppDelegate so the system knows
        // it can suspend us again.
        Task { @MainActor in
            if let handler = self.backgroundCompletionHandler {
                self.backgroundCompletionHandler = nil
                handler()
            }
        }
    }
}
