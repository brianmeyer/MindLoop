//
//  STTServiceTests.swift
//  MindLoopTests
//
//  Tests for Apple Speech Framework speech-to-text
//

import Testing
import Foundation
import AVFoundation
@testable import MindLoop

@MainActor
@Suite("STTService Tests")
struct STTServiceTests {

    // MARK: - Initialization Tests

    @Test("Initialize Apple Speech Framework")
    func testSpeechFrameworkInitialization() async throws {
        let stt = STTService.shared

        print("🧪 Testing Apple Speech Framework initialization...")

        try await stt.initialize()

        print("✅ Apple Speech Framework initialized and authorized")
    }

    // MARK: - Transcription Tests

    @Test("Transcribe test audio file")
    func testAudioTranscription() async throws {
        let stt = STTService.shared

        // Initialize if needed
        if !stt.isAuthorized {
            try await stt.initialize()
        }

        print("🧪 Testing audio transcription...")

        // Create a simple test audio file (or use fixture)
        let testAudioURL = try createTestAudio()

        var finalTranscript = ""
        var partialUpdates = 0

        for await update in stt.transcribe(audioURL: testAudioURL) {
            print("📝 Partial: \(update.text)")
            partialUpdates += 1

            if update.isFinal {
                finalTranscript = update.text
                print("✅ Final: \(finalTranscript)")
            }
        }

        // Verify we got updates
        #expect(partialUpdates > 0)
        // Note: finalTranscript may be empty for silent audio, so we just check that we got updates

        // Cleanup
        try? FileManager.default.removeItem(at: testAudioURL)
    }

    @Test("Transcription completes within timeout")
    func testTranscriptionTimeout() async throws {
        let stt = STTService.shared

        // Initialize if needed
        if !stt.isAuthorized {
            try await stt.initialize()
        }

        print("🧪 Testing transcription timeout (2.5s)...")

        let testAudioURL = try createTestAudio()

        let start = Date()
        let transcript = try await stt.transcribeSync(audioURL: testAudioURL, timeout: 2.5)
        let duration = Date().timeIntervalSince(start)

        print("⏱️  Transcription took \(Int(duration * 1000))ms")

        // Should complete under 2.5s
        #expect(duration < 2.5, "Transcription took \(duration)s, exceeds 2.5s timeout")

        // Cleanup
        try? FileManager.default.removeItem(at: testAudioURL)
    }

    @Test("Validate audio format")
    func testAudioValidation() throws {
        let stt = STTService.shared

        print("🧪 Testing audio validation...")

        // Create a minimal valid audio file without recording
        let testAudioPath = try createMinimalAudioFile()
        let isValid = stt.validateAudio(testAudioPath)

        #expect(isValid == true, "Valid audio should pass validation")

        print("✅ Audio validation passed")

        // Cleanup
        try? FileManager.default.removeItem(at: testAudioPath)
    }

    // MARK: - Helper Methods

    private func createTestAudio() throws -> URL {
        // Create a short silent audio file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: audioURL, settings: settings)
        recorder.record()
        Thread.sleep(forTimeInterval: 0.5) // Record 500ms of silence
        recorder.stop()

        // Wait for file to be fully written
        Thread.sleep(forTimeInterval: 0.1)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw NSError(domain: "STTServiceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file not created"])
        }

        return audioURL
    }

    private func createMinimalAudioFile() throws -> URL {
        // Create a minimal valid audio file using AVAssetWriter (no recording needed)
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        // Create a 1-second silent audio buffer
        let sampleRate: Double = 16000
        let channelCount: AVAudioChannelCount = 1
        let frameCount = AVAudioFrameCount(sampleRate)

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Write to file
        let audioFile = try AVAudioFile(
            forWriting: audioURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channelCount,
                AVEncoderBitRateKey: 64000
            ]
        )
        try audioFile.write(from: buffer)

        return audioURL
    }
}
