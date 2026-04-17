//
//  SpeechTranscriptionService.swift
//  MindLoop
//
//  On-device speech-to-text using Apple Speech framework.
//  Streams partial transcripts in real-time during recording.
//  Owns the AVAudioSession while transcribing.
//

import Foundation
import Speech
import AVFoundation
import os.log

/// Authorization status for speech recognition
enum SpeechAuthStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Errors from the speech transcription service
enum SpeechTranscriptionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineFailure(Error)
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .audioEngineFailure(let error):
            return "Audio engine failed: \(error.localizedDescription)"
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        }
    }
}

/// On-device speech transcription service using SFSpeechRecognizer.
/// Streams partial transcripts via an AsyncStream and delivers a final transcript on stop.
/// Owns the AVAudioSession during transcription to prevent conflicts with AudioRecorder.
@MainActor
@Observable
final class SpeechTranscriptionService {

    // MARK: - Public State

    /// The current partial transcript (updated in real-time)
    private(set) var partialTranscript: String = ""

    /// Whether the service is actively transcribing
    private(set) var isTranscribing: Bool = false

    /// Current authorization status
    private(set) var authStatus: SpeechAuthStatus = .notDetermined

    /// Last error encountered (nil if none)
    private(set) var lastError: SpeechTranscriptionError?

    /// Most recent speech recognition metadata (speaking rate, pause duration).
    /// Populated from the recognition callback; used to extract prosody features
    /// for `EmotionAgent` via `NativeEmotionService`. (REC-288)
    private(set) var lastRecognitionMetadata: SFSpeechRecognitionMetadata?

    /// Most recent voice analytics (pitch, jitter, shimmer) from the last
    /// transcription segment with analytics data. (REC-288)
    private(set) var lastVoiceAnalytics: SFVoiceAnalytics?

    /// Live audio input level (0.0–1.0), normalized from RMS dB of the
    /// microphone tap. Used to drive the waveform visualizer. (REC-293)
    private(set) var audioLevel: Float = 0.0

    // MARK: - Private

    private let logger = Logger(subsystem: "com.lycan.MindLoop", category: "SpeechTranscription")

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Stored final transcript after stopping
    private var finalTranscript: String = ""

    /// Continuation for the stop-and-wait pattern
    private var stopContinuation: CheckedContinuation<String, Never>?

    // MARK: - Init

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        logger.debug("SpeechTranscriptionService initialized with locale: \(locale.identifier)")
    }

    // MARK: - Authorization

    /// Request speech recognition authorization.
    /// Must be called before starting transcription.
    func requestAuthorization() async -> SpeechAuthStatus {
        logger.info("Requesting speech recognition authorization")

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let mapped: SpeechAuthStatus
        switch status {
        case .authorized:
            mapped = .authorized
            logger.info("Speech recognition authorized")
        case .denied:
            mapped = .denied
            logger.warning("Speech recognition denied by user")
        case .restricted:
            mapped = .restricted
            logger.warning("Speech recognition restricted on this device")
        case .notDetermined:
            mapped = .notDetermined
            logger.info("Speech recognition authorization not determined")
        @unknown default:
            mapped = .denied
            logger.error("Unknown speech recognition authorization status")
        }

        authStatus = mapped
        return mapped
    }

    // MARK: - Start Transcription

    /// Start live transcription. Partial transcripts update `partialTranscript` in real-time.
    /// This service configures and owns the AVAudioSession while active.
    /// - Throws: `SpeechTranscriptionError` if authorization or setup fails.
    func startTranscribing() throws {
        guard authStatus == .authorized else {
            let error = SpeechTranscriptionError.notAuthorized
            lastError = error
            logger.error("Cannot start: not authorized")
            throw error
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let error = SpeechTranscriptionError.recognizerUnavailable
            lastError = error
            logger.error("Cannot start: recognizer unavailable")
            throw error
        }

        // Cancel any existing task
        cleanupAudioPipeline()

        lastError = nil
        partialTranscript = ""
        finalTranscript = ""
        lastRecognitionMetadata = nil
        lastVoiceAnalytics = nil
        audioLevel = 0.0

        logger.info("Starting speech transcription")

        // Configure audio session — STT owns the session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            logger.debug("Audio session configured for STT (.record, .measurement)")
        } catch {
            let wrappedError = SpeechTranscriptionError.audioEngineFailure(error)
            lastError = wrappedError
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            throw wrappedError
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // On iOS 26, addsPunctuation is available
        request.addsPunctuation = true
        self.recognitionRequest = request

        // Configure audio engine input (session is already active)
        let inputNode = audioEngine.inputNode

        // Remove any leftover tap to prevent "tap already installed" crash
        inputNode.removeTap(onBus: 0)

        // Validate the hardware format — a 0-channel or 0-sampleRate format
        // means the audio session hasn't fully activated yet.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            let error = SpeechTranscriptionError.audioEngineFailure(
                NSError(domain: "SpeechTranscriptionService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Audio input format invalid (sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)). Microphone may be unavailable."])
            )
            lastError = error
            logger.error("Invalid recording format: \(recordingFormat)")
            throw error
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self, weak request] buffer, _ in
            request?.append(buffer)

            // Compute RMS level for live waveform amplitude (REC-293).
            // The tap runs on an audio queue; hop to the main actor to
            // publish the @Observable property.
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let db = 20 * log10(max(rms, 0.000001))
            let normalized = max(0, min(1, (db + 60) / 60))
            Task { @MainActor [weak self] in
                self?.audioLevel = normalized
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            let wrappedError = SpeechTranscriptionError.audioEngineFailure(error)
            lastError = wrappedError
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
            cleanupAudioPipeline()
            throw wrappedError
        }

        // Start recognition task — callback fires on an arbitrary background queue.
        // Use Task { @MainActor in } instead of MainActor.assumeIsolated to avoid crashes.
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    self.partialTranscript = text

                    // Capture metadata + voice analytics for prosody extraction (REC-288).
                    // iOS 14.5+ moves voiceAnalytics from SFTranscriptionSegment onto
                    // SFSpeechRecognitionMetadata — read it from there.
                    if let metadata = result.speechRecognitionMetadata {
                        self.lastRecognitionMetadata = metadata
                        self.lastVoiceAnalytics = metadata.voiceAnalytics
                    }

                    if result.isFinal {
                        self.finalTranscript = text
                        self.logger.info("Final transcript received (\(text.count) chars)")
                        self.cleanupAudioPipeline()
                        // Resume any waiting stopTranscribing() call — capture-and-nil
                        // before resume to avoid double-resume on simultaneous error (REC-290).
                        let cont = self.stopContinuation
                        self.stopContinuation = nil
                        cont?.resume(returning: text)
                    }
                }

                if let error {
                    // Don't overwrite if we already have a final result
                    if self.finalTranscript.isEmpty {
                        self.logger.error("Recognition error: \(error.localizedDescription)")
                        self.lastError = .recognitionFailed(error)
                    }
                    self.cleanupAudioPipeline()
                    // Resume any waiting stopTranscribing() call with what we have.
                    // Capture-and-nil before resume (REC-290).
                    let transcript = self.finalTranscript.isEmpty ? self.partialTranscript : self.finalTranscript
                    let cont = self.stopContinuation
                    self.stopContinuation = nil
                    cont?.resume(returning: transcript)
                }
            }
        }

        isTranscribing = true
        logger.info("Speech transcription started successfully")
    }

    // MARK: - Pause / Resume

    /// Pause transcription (keeps recognition task alive but stops audio input).
    func pauseTranscribing() {
        guard isTranscribing else { return }

        logger.debug("Pausing speech transcription")
        audioEngine.pause()
        isTranscribing = false
    }

    /// Resume transcription after a pause.
    func resumeTranscribing() throws {
        guard !isTranscribing, recognitionTask != nil else { return }

        logger.debug("Resuming speech transcription")
        do {
            try audioEngine.start()
            isTranscribing = true
        } catch {
            let wrappedError = SpeechTranscriptionError.audioEngineFailure(error)
            lastError = wrappedError
            logger.error("Failed to resume audio engine: \(error.localizedDescription)")
            throw wrappedError
        }
    }

    // MARK: - Stop Transcription

    /// Stop transcription and await the final transcript.
    /// This is async to allow the recognizer to deliver the final result before cleanup.
    /// - Returns: The final transcribed text (may be empty if nothing was recognized).
    @discardableResult
    func stopTranscribing() async -> String {
        logger.info("Stopping speech transcription")

        guard recognitionRequest != nil || recognitionTask != nil else {
            // Nothing running — return what we have
            isTranscribing = false
            return finalTranscript.isEmpty ? partialTranscript : finalTranscript
        }

        // End audio input to trigger final result from recognizer
        recognitionRequest?.endAudio()

        // Wait for the final result callback (with a timeout)
        let transcript = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            // If we already have a final transcript, return immediately
            if !finalTranscript.isEmpty {
                continuation.resume(returning: finalTranscript)
                return
            }

            // Store continuation — the recognition callback will resume it
            stopContinuation = continuation

            // Timeout: don't wait forever for the final result
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                // If still waiting, resume with what we have. Capture-and-nil
                // before resume to avoid racing the recognition callback (REC-290).
                let pending = self.stopContinuation
                self.stopContinuation = nil
                if let pending {
                    let text = self.finalTranscript.isEmpty ? self.partialTranscript : self.finalTranscript
                    self.logger.warning("Stop transcription timed out, returning partial result")
                    self.cleanupAudioPipeline()
                    pending.resume(returning: text)
                }
            }
        }

        cleanupAudioPipeline()
        isTranscribing = false
        logger.info("Transcription stopped. Transcript length: \(transcript.count)")

        return transcript
    }

    // MARK: - Cleanup

    private func cleanupAudioPipeline() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        isTranscribing = false
        audioLevel = 0.0
    }
}
