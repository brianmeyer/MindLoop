//
//  EmotionAgent.swift
//  MindLoop
//
//  Hybrid emotion detection: text sentiment + prosody classification
//  Weighted merge: 0.6 * text + 0.4 * prosody
//

import Foundation
import NaturalLanguage

/// Hybrid emotion analysis agent combining text sentiment and prosody features
struct EmotionAgent: AgentProtocol, Sendable {

    // MARK: - AgentProtocol

    typealias Input = (text: String, prosodyFeatures: [String: Double])
    typealias Output = EmotionSignal

    var name: String { "EmotionAgent" }

    /// Satisfy `AgentProtocol.process(_:)` by delegating to the convenience method.
    func process(_ input: Input) async throws -> EmotionSignal {
        analyze(text: input.text, prosodyFeatures: input.prosodyFeatures)
    }

    // MARK: - Sub-label Hint Keywords
    //
    // NLTagger's `.sentimentScore` gives us continuous VALENCE (-1..+1) but
    // not arousal, so it can't distinguish "anxious" (high arousal negative)
    // from "sad" (low arousal negative) on text alone. These small keyword
    // sets are only used as a fallback TIE-BREAKER when prosody is absent
    // and the sentiment is negative — they do NOT drive confidence or the
    // primary classification.

    private static let anxiousHints: Set<String> = [
        // adjective + verb forms
        "worried", "anxious", "nervous", "scared", "panicking",
        "stressed", "overwhelmed", "afraid", "tense", "dreading",
        "racing", "frantic", "restless", "uneasy", "jittery",
        // noun forms — critical for "i have anxiety" to classify correctly
        "anxiety", "worry", "fear", "stress", "dread", "panic",
        "tension", "pressure", "nerves", "overwhelm"
    ]

    private static let sadHints: Set<String> = [
        // adjective + verb forms
        "sad", "depressed", "hopeless", "lonely", "crying",
        "exhausted", "tired", "heavy", "down", "unmotivated",
        "empty", "numb", "hurt", "grieving",
        // noun forms
        "sadness", "depression", "loneliness", "grief",
        "loss", "sorrow", "despair", "misery"
    ]

    /// Valence threshold above which we classify as positive / below as negative.
    /// `NLTagger.sentimentScore` returns small non-zero values for mundane
    /// descriptive text (e.g. "I went to the store" reads as faintly
    /// negative) so we need a generous neutral band. 0.3 empirically keeps
    /// mundane text in the `.neutral` bucket while still triggering on
    /// emotionally loaded sentences.
    private static let valenceThreshold: Double = 0.3

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

    // MARK: - Text Sentiment Analysis (NLTagger)

    /// Classify text sentiment using Apple's on-device `NLTagger` with the
    /// `.sentimentScore` scheme. Returns continuous valence in `[-1, +1]`
    /// mapped onto our 4-class label space. (REC-299)
    ///
    /// - Negative valence below `valenceThreshold` → anxious or sad
    ///   (tie-broken by small hint-keyword sets since sentimentScore
    ///   doesn't expose arousal).
    /// - Positive valence above `valenceThreshold` → positive
    /// - |valence| ≤ threshold → neutral
    ///
    /// Confidence is the absolute valence magnitude — a 0.8 score becomes
    /// 80% confident. This gives much more meaningful confidence than the
    /// old keyword-density heuristic that floored at 40%.
    internal func analyzeText(_ text: String) -> (label: EmotionSignal.Label, confidence: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (.neutral, 0.0)
        }

        let valence = sentimentScore(for: trimmed)
        let magnitude = abs(valence)

        // Positive band — NLTagger handles "I feel great" directly
        if valence > Self.valenceThreshold {
            return (.positive, min(1.0, magnitude))
        }

        // Negative band — need to disambiguate anxious vs sad on text alone.
        // Prosody (if present) provides arousal and will correct this in
        // the blended signal.
        //
        // Guard against false-positive negativity: NLTagger assigns small
        // negative scores to mundane descriptive text ("I went to the store")
        // even though nothing emotional is happening. Only commit to a
        // negative label when we ALSO see a hint word — otherwise stay
        // neutral so the keyword presence acts as a semantic guardrail.
        if valence < -Self.valenceThreshold {
            let lowered = trimmed.lowercased()
            let words = lowered.components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty }
            let wordSet = Set(words)

            let anxiousHits = wordSet.intersection(Self.anxiousHints).count
            let sadHits = wordSet.intersection(Self.sadHints).count

            if anxiousHits > sadHits {
                return (.anxious, min(1.0, magnitude))
            }
            if sadHits > anxiousHits {
                return (.sad, min(1.0, magnitude))
            }
            if anxiousHits > 0 && anxiousHits == sadHits {
                // Equal hits — pick anxious (higher arousal default for ties).
                return (.anxious, min(1.0, magnitude))
            }

            // No hint words at all — likely a false negative from NLTagger
            // scoring mundane descriptive text. Return neutral with modest
            // confidence so the prosody path (if present) can still override.
            return (.neutral, 0.4)
        }

        // Neutral band — low-confidence neutral.
        return (.neutral, 0.4)
    }

    /// Run `NLTagger.sentimentScore` on the full text and return the
    /// parsed valence score in `[-1, +1]`. Returns 0 if the tagger fails
    /// to produce a tag or the tag cannot be parsed as a Double.
    private func sentimentScore(for text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )
        guard let tagValue = tag?.rawValue,
              let score = Double(tagValue) else {
            return 0
        }
        // Clamp defensively — Apple's docs say [-1, +1] but we never want
        // runaway values propagating into downstream arousal math.
        return max(-1.0, min(1.0, score))
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

        guard let dominant = scores.max(by: { $0.1 < $1.1 }) else {
            return (.neutral, 0.0)
        }

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
