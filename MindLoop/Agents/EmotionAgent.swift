//
//  EmotionAgent.swift
//  MindLoop
//
//  Hybrid emotion detection: text sentiment + prosody classification
//  Weighted merge: 0.6 * text + 0.4 * prosody
//

import Foundation

/// Hybrid emotion analysis agent combining text sentiment and prosody features
struct EmotionAgent {

    // MARK: - Keyword Dictionaries

    private static let positiveKeywords: Set<String> = [
        "happy", "grateful", "excited", "good", "great",
        "wonderful", "love", "amazing", "blessed", "thankful", "joy"
    ]

    private static let anxiousKeywords: Set<String> = [
        "worried", "anxious", "nervous", "scared", "panic",
        "stress", "overwhelm", "afraid", "tense", "dread"
    ]

    private static let sadKeywords: Set<String> = [
        "sad", "depressed", "hopeless", "lonely", "grief",
        "loss", "empty", "numb", "hurt", "crying"
    ]

    // MARK: - Weights

    /// Text sentiment weight in the final merge
    private static let textWeight: Double = 0.6

    /// Prosody classification weight in the final merge
    private static let prosodyWeight: Double = 0.4

    // MARK: - Public API

    /// Analyze text and prosody features to produce a hybrid EmotionSignal
    /// - Parameters:
    ///   - text: Transcript or user input text
    ///   - prosodyFeatures: Dictionary from EmotionService (may be empty)
    /// - Returns: Combined EmotionSignal with label, confidence, valence, and arousal
    func analyze(text: String, prosodyFeatures: [String: Double] = [:]) -> EmotionSignal {
        let textResult = analyzeText(text)
        let prosodyResult = analyzeProsody(prosodyFeatures)

        // If no prosody data, rely on text only
        guard !prosodyFeatures.isEmpty else {
            return EmotionSignal(
                label: textResult.label,
                confidence: textResult.confidence,
                valence: valenceFor(label: textResult.label, confidence: textResult.confidence),
                arousal: arousalFor(label: textResult.label, confidence: textResult.confidence),
                prosodyFeatures: prosodyFeatures
            )
        }

        // If no text (empty string), rely on prosody only
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return EmotionSignal(
                label: prosodyResult.label,
                confidence: prosodyResult.confidence,
                valence: valenceFor(label: prosodyResult.label, confidence: prosodyResult.confidence),
                arousal: arousalFor(label: prosodyResult.label, confidence: prosodyResult.confidence),
                prosodyFeatures: prosodyFeatures
            )
        }

        // Weighted merge
        let mergedLabel = mergeLabels(
            textLabel: textResult.label,
            textConfidence: textResult.confidence,
            prosodyLabel: prosodyResult.label,
            prosodyConfidence: prosodyResult.confidence
        )

        let mergedConfidence = Self.textWeight * textResult.confidence
            + Self.prosodyWeight * prosodyResult.confidence

        let mergedValence = valenceFor(label: mergedLabel, confidence: mergedConfidence)
        let mergedArousal = arousalFor(label: mergedLabel, confidence: mergedConfidence)

        return EmotionSignal(
            label: mergedLabel,
            confidence: mergedConfidence,
            valence: mergedValence,
            arousal: mergedArousal,
            prosodyFeatures: prosodyFeatures
        )
    }

    // MARK: - Text Sentiment Analysis (v1 Rule-Based)

    /// Classify text sentiment by keyword frequency
    internal func analyzeText(_ text: String) -> (label: EmotionSignal.Label, confidence: Double) {
        let lowercased = text.lowercased()
        let words = lowercased.components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else {
            return (.neutral, 0.0)
        }

        var positiveCount = 0
        var anxiousCount = 0
        var sadCount = 0

        for word in words {
            if Self.positiveKeywords.contains(word) { positiveCount += 1 }
            if Self.anxiousKeywords.contains(word) { anxiousCount += 1 }
            if Self.sadKeywords.contains(word) { sadCount += 1 }
        }

        let totalKeywords = positiveCount + anxiousCount + sadCount

        // No keywords found -> neutral with low confidence
        guard totalKeywords > 0 else {
            return (.neutral, 0.3)
        }

        // Determine dominant label
        let scores: [(EmotionSignal.Label, Int)] = [
            (.positive, positiveCount),
            (.anxious, anxiousCount),
            (.sad, sadCount)
        ]

        let dominant = scores.max { $0.1 < $1.1 }!

        // Confidence based on keyword density (capped at 1.0)
        let density = Double(dominant.1) / Double(words.count)
        let confidence = min(1.0, density * 5.0 + 0.4)

        return (dominant.0, confidence)
    }

    // MARK: - Prosody Classification (v1 Rule-Based)

    /// Classify emotion from prosody features using rule-based thresholds
    /// - Anxious: high pitch variance (>30) + fast speaking rate (>160 wpm) + high jitter (>2.0)
    /// - Sad: low pitch (<180 Hz) + slow rate (<120 wpm) + long pauses (>0.5s) + high shimmer (>3.0)
    /// - Positive: moderate pitch + moderate rate + low jitter
    /// - Neutral: everything else
    internal func analyzeProsody(_ features: [String: Double]) -> (label: EmotionSignal.Label, confidence: Double) {
        guard !features.isEmpty else {
            return (.neutral, 0.0)
        }

        let pitchMean = features["pitch_mean"] ?? 195.0
        let pitchStd = features["pitch_std"] ?? 18.0
        let jitter = features["jitter"] ?? 1.2
        let shimmer = features["shimmer"] ?? 1.5
        let speakingRate = features["speaking_rate"] ?? 135.0
        let pauseDuration = features["pause_duration"] ?? 0.35

        // Score each category
        var anxiousScore: Double = 0.0
        var sadScore: Double = 0.0
        var positiveScore: Double = 0.0

        // Anxious indicators
        if pitchStd > 30.0 { anxiousScore += 0.35 }
        if speakingRate > 160.0 { anxiousScore += 0.35 }
        if jitter > 2.0 { anxiousScore += 0.30 }

        // Sad indicators
        if pitchMean < 180.0 { sadScore += 0.25 }
        if speakingRate < 120.0 { sadScore += 0.25 }
        if pauseDuration > 0.5 { sadScore += 0.25 }
        if shimmer > 3.0 { sadScore += 0.25 }

        // Positive indicators
        if pitchMean >= 180.0 && pitchMean <= 240.0 { positiveScore += 0.35 }
        if speakingRate >= 120.0 && speakingRate <= 160.0 { positiveScore += 0.35 }
        if jitter < 1.5 { positiveScore += 0.30 }

        let scores: [(EmotionSignal.Label, Double)] = [
            (.anxious, anxiousScore),
            (.sad, sadScore),
            (.positive, positiveScore)
        ]

        let dominant = scores.max { $0.1 < $1.1 }!

        // Require a minimum score to classify as non-neutral
        guard dominant.1 >= 0.5 else {
            return (.neutral, 0.4)
        }

        return (dominant.0, dominant.1)
    }

    // MARK: - Merge Logic

    /// Merge text and prosody labels using weighted confidence
    private func mergeLabels(
        textLabel: EmotionSignal.Label,
        textConfidence: Double,
        prosodyLabel: EmotionSignal.Label,
        prosodyConfidence: Double
    ) -> EmotionSignal.Label {
        // If both agree, use that label
        if textLabel == prosodyLabel {
            return textLabel
        }

        // Weighted confidence comparison
        let textWeighted = Self.textWeight * textConfidence
        let prosodyWeighted = Self.prosodyWeight * prosodyConfidence

        return textWeighted >= prosodyWeighted ? textLabel : prosodyLabel
    }

    // MARK: - Valence & Arousal Mapping

    /// Map emotion label to valence (-1.0 to +1.0)
    private func valenceFor(label: EmotionSignal.Label, confidence: Double) -> Double {
        let baseValence: Double
        switch label {
        case .positive: baseValence = 0.7
        case .neutral:  baseValence = 0.0
        case .anxious:  baseValence = -0.4
        case .sad:      baseValence = -0.6
        }
        return baseValence * confidence
    }

    /// Map emotion label to arousal (0.0 to 1.0)
    private func arousalFor(label: EmotionSignal.Label, confidence: Double) -> Double {
        let baseArousal: Double
        switch label {
        case .positive: baseArousal = 0.5
        case .neutral:  baseArousal = 0.3
        case .anxious:  baseArousal = 0.8
        case .sad:      baseArousal = 0.2
        }
        return baseArousal * confidence
    }
}
