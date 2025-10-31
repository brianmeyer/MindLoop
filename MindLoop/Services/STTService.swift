//
//  STTService.swift
//  MindLoop
//
//  Speech-to-text service using Apple Speech Framework
//  Handles audio transcription with streaming support
//

import Foundation
import AVFoundation
import Speech

/// Speech-to-text service for audio transcription
@MainActor
@Observable
final class STTService {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = STTService()

    /// Transcription state
    private(set) var isTranscribing = false

    /// Current partial transcript
    private(set) var partialTranscript = ""

    /// Speech recognizer
    private var speechRecognizer: SFSpeechRecognizer?

    /// Authorization status
    private(set) var isAuthorized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize Speech Framework and request authorization
    func initialize() async throws {
        print("STTService: Initializing Apple Speech Framework...")

        // Create speech recognizer for device locale
        speechRecognizer = SFSpeechRecognizer()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw STTError.notAvailable
        }

        // Request authorization
        let status = await requestAuthorization()

        guard status == .authorized else {
            throw STTError.notAuthorized(status: status)
        }

        isAuthorized = true
        print("STTService: Apple Speech Framework initialized and authorized")
    }

    /// Request speech recognition authorization
    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Transcription

    /// Transcribe audio file with streaming updates
    /// - Parameter audioURL: URL to audio file (.m4a, .wav, etc.)
    /// - Returns: AsyncStream of transcription updates (partial + final)
    func transcribe(audioURL: URL) -> AsyncStream<TranscriptUpdate> {
        AsyncStream { continuation in
            Task {
                guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                    print("STTService: Speech recognizer not available")
                    continuation.finish()
                    return
                }

                guard isAuthorized else {
                    print("STTService: Not authorized for speech recognition")
                    continuation.finish()
                    return
                }

                isTranscribing = true
                partialTranscript = ""

                // Create recognition request
                let request = SFSpeechURLRecognitionRequest(url: audioURL)
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = true // Force on-device processing

                // Start recognition
                _ = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        print("STTService: Recognition error: \(error.localizedDescription)")
                        self.isTranscribing = false
                        continuation.finish()
                        return
                    }

                    guard let result = result else { return }

                    let transcription = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    let confidence = result.bestTranscription.segments.first?.confidence ?? 0.0

                    // Update partial transcript
                    self.partialTranscript = transcription

                    // Yield update
                    let update = TranscriptUpdate(
                        text: transcription,
                        isFinal: isFinal,
                        confidence: Double(confidence)
                    )

                    continuation.yield(update)

                    // Finish if final
                    if isFinal {
                        self.isTranscribing = false
                        continuation.finish()
                    }
                }
            }
        }
    }

    /// Transcribe audio file synchronously
    /// - Parameter audioURL: URL to audio file
    /// - Returns: Final transcript
    /// - Throws: If transcription fails or times out
    func transcribeSync(audioURL: URL, timeout: TimeInterval = 2.5) async throws -> String {
        return try await withTimeout(seconds: timeout) {
            var finalText = ""

            for await update in self.transcribe(audioURL: audioURL) {
                if update.isFinal {
                    finalText = update.text
                }
            }

            return finalText
        }
    }

    // MARK: - Audio Validation

    /// Validate audio file format
    /// - Parameter audioURL: URL to audio file
    /// - Returns: True if valid
    func validateAudio(_ audioURL: URL) -> Bool {
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let format = audioFile.processingFormat

            // Check channel count (mono or stereo)
            guard format.channelCount <= 2 else {
                print("STTService: Warning - Audio has \(format.channelCount) channels, expected 1-2")
                return false
            }

            // Sample rate (flexible, Apple Speech handles resampling)
            let sampleRate = format.sampleRate
            print("STTService: Audio sample rate: \(sampleRate)Hz")

            return true
        } catch {
            print("STTService: Failed to validate audio: \(error)")
            return false
        }
    }

    // MARK: - Utilities

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw STTError.timeout
            }

            // Add actual operation
            group.addTask {
                try await operation()
            }

            // Return first result (either success or timeout)
            let result = try await group.next()!

            // Cancel remaining task
            group.cancelAll()

            return result
        }
    }
}

// MARK: - Types

extension STTService {
    /// Transcription update (partial or final)
    struct TranscriptUpdate {
        let text: String
        let isFinal: Bool
        let confidence: Double
    }

    enum STTError: Error, CustomStringConvertible {
        case notAvailable
        case notAuthorized(status: SFSpeechRecognizerAuthorizationStatus)
        case invalidAudio
        case timeout
        case transcriptionFailed(reason: String)

        var description: String {
            switch self {
            case .notAvailable:
                return "Speech recognizer not available on this device"
            case .notAuthorized(let status):
                return "Speech recognition not authorized: \(status.rawValue)"
            case .invalidAudio:
                return "Invalid audio format"
            case .timeout:
                return "Transcription timeout (>2.5s)"
            case .transcriptionFailed(let reason):
                return "Transcription failed: \(reason)"
            }
        }
    }
}
