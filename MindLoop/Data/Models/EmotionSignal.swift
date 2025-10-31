//
//  EmotionSignal.swift
//  MindLoop
//
//  Represents emotion analysis from hybrid text + prosody detection
//  Source: CLAUDE.md - EmotionAgent output
//

import Foundation

/// Emotion signal from hybrid analysis (text sentiment + prosody features)
struct EmotionSignal: Codable, Equatable {
    // MARK: - Emotion Label

    /// Primary emotion category
    enum Label: String, Codable, CaseIterable {
        case neutral
        case positive
        case anxious
        case sad

        /// Display name for UI
        var displayName: String {
            switch self {
            case .neutral: return "Neutral"
            case .positive: return "Positive"
            case .anxious: return "Anxious"
            case .sad: return "Sad"
            }
        }

        /// Color associated with this emotion (for badges, charts)
        var colorName: String {
            switch self {
            case .neutral: return "MutedForeground"
            case .positive: return "Accent" 
            case .anxious: return "Destructive"
            case .sad: return "Primary"
            }
        }
    }

    // MARK: - Properties

    /// Primary emotion label
    let label: Label

    /// Confidence score (0.0 - 1.0)
    let confidence: Double

    /// Valence: negative (-1.0) to positive (+1.0)
    let valence: Double

    /// Arousal: low (0.0) to high (1.0)
    let arousal: Double

    /// Raw prosody features from OpenSMILE
    /// Keys: pitch_mean, pitch_std, energy_mean, energy_std, speaking_rate, etc.
    let prosodyFeatures: [String: Double]

    // MARK: - Initialization

    init(
        label: Label,
        confidence: Double,
        valence: Double,
        arousal: Double,
        prosodyFeatures: [String: Double] = [:]
    ) {
        self.label = label
        self.confidence = max(0.0, min(1.0, confidence)) // Clamp 0-1
        self.valence = max(-1.0, min(1.0, valence))      // Clamp -1 to 1
        self.arousal = max(0.0, min(1.0, arousal))       // Clamp 0-1
        self.prosodyFeatures = prosodyFeatures
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case label
        case confidence
        case valence
        case arousal
        case prosodyFeatures
    }

    // MARK: - Computed Properties

    /// Human-readable confidence percentage
    var confidencePercentage: Int {
        Int(confidence * 100)
    }

    /// Indicates if this is a high-confidence signal
    var isHighConfidence: Bool {
        confidence >= 0.7
    }

    /// Indicates if emotion is negative (valence < -0.3)
    var isNegative: Bool {
        valence < -0.3
    }

    /// Indicates if emotion is positive (valence > 0.3)
    var isPositive: Bool {
        valence > 0.3
    }

    /// Indicates high arousal (> 0.6)
    var isHighArousal: Bool {
        arousal > 0.6
    }

    /// Two-dimensional emotion category (Russell's circumplex model)
    var circumplex: String {
        switch (valence, arousal) {
        case (0.3..., 0.6...):
            return "Excited"
        case (0.3..., ..<0.4):
            return "Content"
        case (..<(-0.3), 0.6...):
            return "Distressed"
        case (..<(-0.3), ..<0.4):
            return "Sad"
        default:
            return "Neutral"
        }
    }

    /// Formatted valence/arousal for debug display
    var debugDescription: String {
        """
        Emotion: \(label.displayName) (\(confidencePercentage)%)
        Valence: \(String(format: "%.2f", valence))
        Arousal: \(String(format: "%.2f", arousal))
        Circumplex: \(circumplex)
        """
    }
}

// MARK: - Factory Methods

extension EmotionSignal {
    /// Default emotion signal when analysis fails or is unavailable
    static let unknown = EmotionSignal(
        label: .neutral,
        confidence: 0.0,
        valence: 0.0,
        arousal: 0.0,
        prosodyFeatures: [:]
    )

    /// Creates an emotion signal from text sentiment only (no prosody)
    static func fromTextSentiment(
        label: Label,
        confidence: Double,
        valence: Double
    ) -> EmotionSignal {
        EmotionSignal(
            label: label,
            confidence: confidence,
            valence: valence,
            arousal: 0.5, // Neutral arousal when prosody unavailable
            prosodyFeatures: [:]
        )
    }
}

// MARK: - Sample Data

extension EmotionSignal {
    /// Sample anxious emotion
    static let sampleAnxious = EmotionSignal(
        label: .anxious,
        confidence: 0.78,
        valence: -0.4,
        arousal: 0.7,
        prosodyFeatures: [
            "pitch_mean": 220.5,
            "pitch_std": 35.2,
            "energy_mean": 0.62,
            "speaking_rate": 1.3
        ]
    )

    /// Sample positive emotion
    static let samplePositive = EmotionSignal(
        label: .positive,
        confidence: 0.85,
        valence: 0.7,
        arousal: 0.4,
        prosodyFeatures: [
            "pitch_mean": 210.0,
            "pitch_std": 28.1,
            "energy_mean": 0.58,
            "speaking_rate": 1.1
        ]
    )

    /// Sample neutral emotion
    static let sampleNeutral = EmotionSignal(
        label: .neutral,
        confidence: 0.92,
        valence: 0.0,
        arousal: 0.2,
        prosodyFeatures: [
            "pitch_mean": 195.3,
            "pitch_std": 18.5,
            "energy_mean": 0.45,
            "speaking_rate": 1.0
        ]
    )

    /// Sample sad emotion
    static let sampleSad = EmotionSignal(
        label: .sad,
        confidence: 0.81,
        valence: -0.6,
        arousal: 0.3,
        prosodyFeatures: [
            "pitch_mean": 180.2,
            "pitch_std": 15.8,
            "energy_mean": 0.38,
            "speaking_rate": 0.85
        ]
    )
}
