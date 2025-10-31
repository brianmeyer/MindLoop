//
//  TTSService.swift
//  MindLoop
//
//  Text-to-speech service using AVSpeechSynthesizer
//  Reads coach responses aloud
//

import Foundation
import AVFoundation

/// Text-to-speech service for voice output
@MainActor
@Observable
final class TTSService: NSObject {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = TTSService()

    /// Is currently speaking
    private(set) var isSpeaking = false

    /// Current speaking progress (0.0 to 1.0)
    private(set) var progress: Double = 0.0

    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speech Control

    /// Speak text aloud
    /// - Parameters:
    ///   - text: Text to speak
    ///   - voice: Language code (e.g., "en-US", "en-GB")
    ///   - rate: Speech rate (0.0-1.0, default 0.5)
    ///   - pitch: Pitch (0.5-2.0, default 1.0)
    func speak(
        _ text: String,
        voice: String = "en-US",
        rate: Float = 0.5,
        pitch: Float = 1.0
    ) {
        guard !text.isEmpty else { return }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)

        // Set voice (use enhanced neural voice if available)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)

        // Configure speech parameters
        utterance.rate = rate // 0.0 (slowest) to 1.0 (fastest)
        utterance.pitchMultiplier = pitch // 0.5 to 2.0
        utterance.volume = 1.0

        // Speak
        isSpeaking = true
        progress = 0.0
        synthesizer.speak(utterance)

        print("TTSService: Speaking \(text.count) characters...")
    }

    /// Stop speaking immediately
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        progress = 0.0
        print("TTSService: Stopped")
    }

    /// Pause speaking
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        print("TTSService: Paused")
    }

    /// Resume speaking
    func resume() {
        synthesizer.continueSpeaking()
        print("TTSService: Resumed")
    }

    // MARK: - Voice Management

    /// Get list of available voices for a language
    /// - Parameter language: Language code (e.g., "en")
    /// - Returns: Array of voice identifiers
    func availableVoices(for language: String? = nil) -> [String] {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        if let language = language {
            return voices
                .filter { $0.language.hasPrefix(language) }
                .map { $0.identifier }
        } else {
            return voices.map { $0.identifier }
        }
    }

    /// Check if neural voices are available (iOS 13+)
    var hasNeuralVoices: Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { voice in
            voice.quality == .premium
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = true
            print("TTSService: Started speaking")
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            progress = 1.0
            print("TTSService: Finished speaking")
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            print("TTSService: Paused at progress \(progress)")
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            print("TTSService: Resumed")
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            print("TTSService: Cancelled")
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            // Update progress
            let totalLength = utterance.speechString.count
            let currentPosition = characterRange.location + characterRange.length
            progress = Double(currentPosition) / Double(totalLength)
        }
    }
}
