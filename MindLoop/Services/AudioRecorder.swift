//
//  AudioRecorder.swift
//  MindLoop
//
//  Audio recording service with real-time amplitude monitoring
//  Prepares audio for Apple Speech Framework transcription (Phase 2)
//

import Foundation
import AVFoundation

/// Audio recording service with amplitude monitoring
@MainActor
@Observable
class AudioRecorder: NSObject {
    // MARK: - Properties

    /// Current recording state
    private(set) var isRecording = false

    /// Current audio level (0.0 to 1.0)
    private(set) var audioLevel: Float = 0.0

    /// Recorded audio file URL
    private(set) var recordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?

    // MARK: - Recording Control

    /// Start recording audio
    func startRecording() throws {
        // Request microphone permission
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

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
        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()

        isRecording = true

        // Start monitoring audio levels
        startLevelMonitoring()
    }

    /// Pause recording
    func pauseRecording() {
        audioRecorder?.pause()
        isRecording = false
        stopLevelMonitoring()
    }

    /// Resume recording
    func resumeRecording() {
        audioRecorder?.record()
        isRecording = true
        startLevelMonitoring()
    }

    /// Stop recording and return audio file URL
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        stopLevelMonitoring()

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

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
            print("Recording failed")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        }
    }
}
