//
//  MindLoopApp.swift
//  MindLoop
//
//  Created by Brian Meyer on 10/26/25.
//

import SwiftUI
import os

@main
struct MindLoopApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let modelDownloader = ModelDownloader.shared
    @State private var isModelWarmedUp = false
    @State private var warmUpProgress: Double = 0.0

    /// Human-readable error string from the last warmUpModel attempt.
    /// Non-nil = the loading overlay stays up with a retry button
    /// instead of dismissing. (REC-301)
    @State private var warmUpError: String?

    init() {
        // XCUITest harness support: when `-UITest 1` is passed as a launch
        // argument, seed a deterministic state so UI tests don't have to
        // walk through onboarding on every run. Safe in production builds
        // because launch arguments are set by the test runner only.
        if CommandLine.arguments.contains("-UITest") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set("Tester", forKey: "userName")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(isModelWarmedUp ? 1 : 0)

                if !hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else if !isModelWarmedUp {
                    ModelLoadingOverlay(
                        downloader: modelDownloader,
                        warmUpProgress: warmUpProgress,
                        isWarmingUp: modelDownloader.isModelAvailable && !isModelWarmedUp,
                        warmUpError: warmUpError,
                        onRetry: {
                            warmUpError = nil
                            Task { await warmUpModel() }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isModelWarmedUp)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .task {
                guard hasCompletedOnboarding else { return }
                // Skip model download/load in test context
                guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                    isModelWarmedUp = true
                    return
                }
                await modelDownloader.ensureModelAvailable()
                guard modelDownloader.isModelAvailable else { return }
                await warmUpModel()
            }
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if completed {
                    Task {
                        await modelDownloader.ensureModelAvailable()
                        guard modelDownloader.isModelAvailable else { return }
                        await warmUpModel()
                    }
                }
            }
        }
    }

    private func warmUpModel() async {
        #if targetEnvironment(simulator)
        // Skip model loading on simulator
        warmUpError = nil
        isModelWarmedUp = true
        #else
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mindloop", category: "App")
        warmUpError = nil
        do {
            // Load the big LLM first (bulk of warmup time).
            try await ModelRuntime.shared.loadModel(
                from: modelDownloader.modelDirectoryURL
            ) { progress in
                warmUpProgress = progress
            }
            // Load the bundled bge-small-en-v1.5 embedder (~19 MB, <1s).
            // Failure here is non-fatal — retrieval just won't have semantic
            // embeddings until the next launch. (REC-289)
            do {
                try await ModelRuntime.shared.loadEmbeddingModel()
            } catch {
                logger.error("Embedding model warm-up failed: \(error.localizedDescription)")
            }
            isModelWarmedUp = true
        } catch {
            // REC-301: Keep the overlay visible with the error instead of
            // silently dismissing and producing a broken coach. User sees
            // a retry button. The error string is the type + first 100
            // chars of description — safe per CLAUDE.md privacy policy.
            let errorType = String(describing: type(of: error))
            let desc = String(describing: error).prefix(100)
            warmUpError = "\(errorType): \(desc)"
            logger.error(
                "Model warm-up failed (\(errorType, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            // Deliberately do NOT set isModelWarmedUp = true.
        }
        #endif
    }
}

// MARK: - Model Loading Overlay

/// Full-screen overlay shown during model download and warm-up.
private struct ModelLoadingOverlay: View {
    let downloader: ModelDownloader
    let warmUpProgress: Double
    let isWarmingUp: Bool
    /// Non-nil when LLM warmup failed. Overrides the other states. (REC-301)
    let warmUpError: String?
    /// Triggered when the user taps the retry button in the warmup-failure state.
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // App icon area
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(Color("Primary"))
                    .accessibilityHidden(true)

                Text("MindLoop")
                    .typography(.largeTitle)
                    .foregroundStyle(Color("Foreground"))

                Spacer()

                // Status content
                statusContent

                Spacer()
                    .frame(height: Spacing.xxxxl)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusContent: some View {
        // REC-301: warmUpError takes precedence over downloader state —
        // if the LLM failed to load, show a retry prompt instead of
        // silently letting the user proceed to a broken coach.
        if let warmUpError {
            warmUpFailedContent(message: warmUpError)
        } else {
            switch downloader.state {
            case .idle, .checking:
                VStack(spacing: Spacing.m) {
                    ProgressView()
                        .tint(Color("Primary"))
                    Text("Preparing...")
                        .typography(.body)
                        .foregroundStyle(Color("MutedForeground"))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Preparing app")

            case .downloading:
                downloadingContent

            case .ready where isWarmingUp:
                warmUpContent

            case .ready:
                // Brief flash before app shows
                EmptyView()

            case .failed(let message):
                failedContent(message: message)
            }
        }
    }

    /// Shown when `ModelRuntime.loadModel()` throws after the download
    /// completed. Separate from `.failed` (download failure) because the
    /// remedy is different: download-retry restarts URLSession, warmup-retry
    /// restarts MLX model loading without re-downloading. (REC-301)
    private func warmUpFailedContent(message: String) -> some View {
        VStack(spacing: Spacing.base) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color("Destructive"))
                .accessibilityHidden(true)

            Text("AI Model Load Failed")
                .typography(.heading)
                .foregroundStyle(Color("Foreground"))

            Text(message)
                .typography(.small)
                .foregroundStyle(Color("MutedForeground"))
                .multilineTextAlignment(.center)
                .lineLimit(4)

            Button(action: onRetry) {
                Text("Retry")
                    .typography(.emphasized)
                    .foregroundStyle(Color("PrimaryForeground"))
                    .frame(maxWidth: .infinity)
                    .frame(height: Dimensions.primaryButtonHeight)
                    .background(Color("Primary"))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .accessibilityLabel("Retry AI model load")
            .accessibilityHint("Attempts to load the AI model again")
        }
        .accessibilityElement(children: .contain)
    }

    private var downloadingContent: some View {
        VStack(spacing: Spacing.base) {
            Text("Downloading AI Model")
                .typography(.heading)
                .foregroundStyle(Color("Foreground"))

            ProgressView(value: downloader.progress, total: 1.0)
                .tint(Color("Primary"))
                .accessibilityLabel("Download progress")
                .accessibilityValue("\(Int(downloader.progress * 100)) percent")

            Text(downloader.statusMessage)
                .typography(.small)
                .foregroundStyle(Color("MutedForeground"))
                .multilineTextAlignment(.center)

            Text("\(Int(downloader.progress * 100))%")
                .typography(.subheading)
                .foregroundStyle(Color("Primary"))
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: Spacing.s) {
                Text("One-time download, approximately 3.3 GB")
                    .typography(.caption)
                    .foregroundStyle(Color("MutedForeground"))

                Label("Wi-Fi recommended", systemImage: "wifi")
                    .typography(.caption)
                    .foregroundStyle(Color("MutedForeground"))
            }
            .padding(.top, Spacing.m)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Downloading AI model, \(Int(downloader.progress * 100)) percent complete. One-time download, approximately 3.3 gigabytes. Wi-Fi recommended.")
    }

    private var warmUpContent: some View {
        VStack(spacing: Spacing.base) {
            Text("Loading AI Model")
                .typography(.heading)
                .foregroundStyle(Color("Foreground"))

            ProgressView(value: warmUpProgress, total: 1.0)
                .tint(Color("Primary"))
                .accessibilityLabel("Loading progress")
                .accessibilityValue("\(Int(warmUpProgress * 100)) percent")

            Text("Preparing model for use...")
                .typography(.small)
                .foregroundStyle(Color("MutedForeground"))

            Text("\(Int(warmUpProgress * 100))%")
                .typography(.subheading)
                .foregroundStyle(Color("Primary"))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading AI model into memory, \(Int(warmUpProgress * 100)) percent complete")
    }

    private func failedContent(message: String) -> some View {
        VStack(spacing: Spacing.base) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color("Destructive"))
                .accessibilityHidden(true)

            Text("Download Failed")
                .typography(.heading)
                .foregroundStyle(Color("Foreground"))

            Text(message)
                .typography(.small)
                .foregroundStyle(Color("MutedForeground"))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await downloader.ensureModelAvailable()
                }
            } label: {
                Text("Retry Download")
                    .typography(.emphasized)
                    .foregroundStyle(Color("PrimaryForeground"))
                    .frame(maxWidth: .infinity)
                    .frame(height: Dimensions.primaryButtonHeight)
                    .background(Color("Primary"))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .accessibilityLabel("Retry download")
            .accessibilityHint("Attempts to download the AI model again")
        }
    }
}
