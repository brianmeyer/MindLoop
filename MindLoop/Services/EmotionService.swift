//
//  EmotionService.swift
//  MindLoop
//
//  Native prosody extraction using Apple Speech framework
//  Replaces OpenSMILE C++ bridge with SFVoiceAnalytics + SpeechRecognitionMetadata
//

import Foundation
import Speech

// MARK: - Protocol

/// Protocol for extracting prosody features from speech recognition results
protocol EmotionServiceProtocol {
    /// Extract prosody features from Apple Speech framework metadata
    /// - Parameters:
    ///   - metadata: Speech recognition metadata (speaking rate, pause duration)
    ///   - voiceAnalytics: Voice analytics (pitch, jitter, shimmer)
    /// - Returns: Dictionary with keys: pitch_mean, pitch_std, jitter, shimmer, speaking_rate, pause_duration
    func extractProsodyFeatures(
        from metadata: SFSpeechRecognitionMetadata?,
        voiceAnalytics: SFVoiceAnalytics?
    ) -> [String: Double]
}

// MARK: - Native Implementation

/// Prosody feature extraction using Apple native frameworks (SFVoiceAnalytics + SpeechRecognitionMetadata)
final class NativeEmotionService: EmotionServiceProtocol {

    // MARK: - Singleton

    static let shared = NativeEmotionService()

    private init() {}

    // MARK: - Feature Extraction

    func extractProsodyFeatures(
        from metadata: SFSpeechRecognitionMetadata?,
        voiceAnalytics: SFVoiceAnalytics?
    ) -> [String: Double] {
        var features: [String: Double] = [:]

        // Extract from SFVoiceAnalytics (pitch, jitter, shimmer)
        if let analytics = voiceAnalytics {
            // Pitch (F0) from acousticFeature
            let pitchFeature = analytics.pitch
            features["pitch_mean"] = pitchFeature.acousticFeatureValuePerFrame.mean()
            features["pitch_std"] = pitchFeature.acousticFeatureValuePerFrame.standardDeviation()

            // Jitter (pitch perturbation)
            let jitterFeature = analytics.jitter
            features["jitter"] = jitterFeature.acousticFeatureValuePerFrame.mean()

            // Shimmer (amplitude perturbation)
            let shimmerFeature = analytics.shimmer
            features["shimmer"] = shimmerFeature.acousticFeatureValuePerFrame.mean()
        }

        // Extract from SFSpeechRecognitionMetadata (speaking rate, pause duration)
        if let meta = metadata {
            // Speaking rate in words per minute
            features["speaking_rate"] = meta.speakingRate

            // Average pause duration in seconds
            features["pause_duration"] = meta.averagePauseDuration
        }

        return features
    }
}

// MARK: - Mock Implementation

/// Mock emotion service for testing with configurable prosody features
final class MockEmotionService: EmotionServiceProtocol {

    /// Features to return from extractProsodyFeatures
    var stubbedFeatures: [String: Double]

    init(stubbedFeatures: [String: Double] = [:]) {
        self.stubbedFeatures = stubbedFeatures
    }

    func extractProsodyFeatures(
        from metadata: SFSpeechRecognitionMetadata?,
        voiceAnalytics: SFVoiceAnalytics?
    ) -> [String: Double] {
        return stubbedFeatures
    }

    // MARK: - Preset Configurations

    /// Anxious prosody: high pitch variance, fast rate, high jitter
    static var anxious: MockEmotionService {
        MockEmotionService(stubbedFeatures: [
            "pitch_mean": 240.0,
            "pitch_std": 45.0,
            "jitter": 3.5,
            "shimmer": 2.0,
            "speaking_rate": 180.0,
            "pause_duration": 0.2
        ])
    }

    /// Sad prosody: low pitch, slow rate, long pauses, high shimmer
    static var sad: MockEmotionService {
        MockEmotionService(stubbedFeatures: [
            "pitch_mean": 150.0,
            "pitch_std": 10.0,
            "jitter": 1.0,
            "shimmer": 4.5,
            "speaking_rate": 100.0,
            "pause_duration": 0.8
        ])
    }

    /// Positive prosody: moderate pitch, moderate rate, low jitter
    static var positive: MockEmotionService {
        MockEmotionService(stubbedFeatures: [
            "pitch_mean": 210.0,
            "pitch_std": 20.0,
            "jitter": 0.8,
            "shimmer": 1.0,
            "speaking_rate": 140.0,
            "pause_duration": 0.3
        ])
    }

    /// Neutral prosody: baseline values
    static var neutral: MockEmotionService {
        MockEmotionService(stubbedFeatures: [
            "pitch_mean": 195.0,
            "pitch_std": 18.0,
            "jitter": 1.2,
            "shimmer": 1.5,
            "speaking_rate": 135.0,
            "pause_duration": 0.35
        ])
    }
}

// MARK: - Array Helpers

private extension Array where Element == Double {
    /// Arithmetic mean of the array
    func mean() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0.0, +) / Double(count)
    }

    /// Population standard deviation
    func standardDeviation() -> Double {
        guard count > 1 else { return 0.0 }
        let avg = mean()
        let variance = reduce(0.0) { $0 + ($1 - avg) * ($1 - avg) } / Double(count)
        return variance.squareRoot()
    }
}
