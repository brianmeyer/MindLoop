//
//  AudioRecorder.swift
//  MindLoop
//
//  Audio recording service with real-time amplitude monitoring
//  Defers audio session ownership to SpeechTranscriptionService when STT is active.
//

import Foundation
import AVFoundation
import os.log

/// Audio recording service with amplitude monitoring
@MainActor
@Observable
final class AudioRecorder: NSObject {

    private let logger = Logger(subsystem: "com.lycan.MindLoop", category: "AudioRecorder")

    // MARK: - Properties

    /// Current recording state
    private(set) var isRecording = false

    /// Current audio level (0.0 to 1.0)
    private(set) var audioLevel: Float = 0.0

    /// Recorded audio file URL
    private(set) var recordingURL: URL?

    /// Whether STT is actively owning the audio session
    var sttOwnsSession: Bool = false

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?

    // MARK: - Recording Control

    /// Start recording audio.
    /// When `sttOwnsSession` is true, the audio session is already configured by STT
    /// and this recorder will not claim ownership.
    func startRecording() throws {
        if !sttOwnsSession {
            // Only configure audio session if STT is not active
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            logger.debug("AudioRecorder owns audio session")
        } else {
            logger.debug("AudioRecorder deferring audio session to STT")
        }

        // Setup recording URL
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0, // 16kHz standard for speech recognition
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create recorder
        guard let url = recordingURL else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording URL not set"])
        }
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()

        isRecording = true
        logger.info("Recording started")

        // Start monitoring audio levels
        startLevelMonitoring()
    }

    /// Pause recording
    func pauseRecording() {
        audioRecorder?.pause()
        isRecording = false
        stopLevelMonitoring()
        logger.debug("Recording paused")
    }

    /// Resume recording
    func resumeRecording() {
        audioRecorder?.record()
        isRecording = true
        startLevelMonitoring()
        logger.debug("Recording resumed")
    }

    /// Stop recording and return audio file URL.
    /// Does NOT deactivate the audio session if STT still owns it.
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        stopLevelMonitoring()

        // Only deactivate audio session if STT is not running
        if !sttOwnsSession {
            try? AVAudioSession.sharedInstance().setActive(false)
            logger.debug("AudioRecorder deactivated audio session")
        } else {
            logger.debug("AudioRecorder skipping session deactivation — STT still active")
        }

        logger.info("Recording stopped")
        return recordingURL
    }

    // MARK: - Level Monitoring

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0.0
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0.0
            return
        }

        recorder.updateMeters()

        // Get average power (in decibels, typically -160 to 0)
        let avgPower = recorder.averagePower(forChannel: 0)

        // Convert to 0.0-1.0 range
        // -50 dB is near silence, 0 dB is max
        let normalized = max(0.0, min(1.0, (avgPower + 50.0) / 50.0))

        audioLevel = normalized
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            let logger = Logger(subsystem: "com.lycan.MindLoop", category: "AudioRecorder")
            logger.error("Recording finished unsuccessfully")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            let logger = Logger(subsystem: "com.lycan.MindLoop", category: "AudioRecorder")
            logger.error("Recording encode error: \(error.localizedDescription)")
        }
    }
}
