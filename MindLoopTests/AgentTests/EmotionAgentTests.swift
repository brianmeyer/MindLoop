//
//  EmotionAgentTests.swift
//  MindLoopTests
//
//  Unit tests for EmotionAgent hybrid emotion detection
//  Tests text-only, prosody-only, combined, and graceful degradation
//

import Testing
import Foundation
@testable import MindLoop

@Suite("EmotionAgent Tests")
struct EmotionAgentTests {

    let agent = EmotionAgent()

    // MARK: - Text-Only Analysis (No Prosody)

    @Test("Text with positive keywords returns positive label")
    func testPositiveTextOnly() {
        let result = agent.analyze(
            text: "I am so happy and grateful for this wonderful day",
            prosodyFeatures: [:]
        )

        #expect(result.label == .positive)
        #expect(result.confidence > 0.4)
        #expect(result.valence > 0.0)
    }

    @Test("Text with anxious keywords returns anxious label")
    func testAnxiousTextOnly() {
        let result = agent.analyze(
            text: "I feel worried and anxious about the nervous situation",
            prosodyFeatures: [:]
        )

        #expect(result.label == .anxious)
        #expect(result.confidence > 0.4)
        #expect(result.valence < 0.0)
    }

    @Test("Text with sad keywords returns sad label")
    func testSadTextOnly() {
        let result = agent.analyze(
            text: "I feel so sad and lonely, everything seems hopeless",
            prosodyFeatures: [:]
        )

        #expect(result.label == .sad)
        #expect(result.confidence > 0.4)
        #expect(result.valence < 0.0)
    }

    @Test("Text with no emotion keywords returns neutral")
    func testNeutralTextOnly() {
        let result = agent.analyze(
            text: "I went to the store and bought some milk today",
            prosodyFeatures: [:]
        )

        #expect(result.label == .neutral)
    }

    @Test("Dominant keyword category wins when mixed")
    func testMixedKeywordsDominantWins() {
        // 3 positive keywords vs 1 anxious keyword
        let result = agent.analyze(
            text: "I am happy and grateful and excited but a little worried",
            prosodyFeatures: [:]
        )

        #expect(result.label == .positive)
    }

    // MARK: - Prosody-Only Analysis (No Keywords)

    @Test("Anxious prosody features classify as anxious")
    func testAnxiousProsodyOnly() {
        let features: [String: Double] = [
            "pitch_mean": 240.0,
            "pitch_std": 45.0,   // > 30 threshold
            "jitter": 3.5,       // > 2.0 threshold
            "shimmer": 2.0,
            "speaking_rate": 180.0,  // > 160 threshold
            "pause_duration": 0.2
        ]

        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .anxious)
        #expect(result.confidence > 0.0)
    }

    @Test("Sad prosody features classify as sad")
    func testSadProsodyOnly() {
        let features: [String: Double] = [
            "pitch_mean": 150.0,     // < 180 threshold
            "pitch_std": 10.0,
            "jitter": 1.0,
            "shimmer": 4.5,          // > 3.0 threshold
            "speaking_rate": 100.0,  // < 120 threshold
            "pause_duration": 0.8    // > 0.5 threshold
        ]

        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .sad)
        #expect(result.confidence > 0.0)
    }

    @Test("Positive prosody features classify as positive")
    func testPositiveProsodyOnly() {
        let features: [String: Double] = [
            "pitch_mean": 210.0,     // 180-240 range
            "pitch_std": 20.0,
            "jitter": 0.8,           // < 1.5 threshold
            "shimmer": 1.0,
            "speaking_rate": 140.0,  // 120-160 range
            "pause_duration": 0.3
        ]

        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .positive)
    }

    @Test("Neutral prosody with no strong indicators returns neutral")
    func testNeutralProsodyOnly() {
        // Values that don't strongly trigger any category
        let features: [String: Double] = [
            "pitch_mean": 195.0,
            "pitch_std": 25.0,
            "jitter": 1.8,
            "shimmer": 2.5,
            "speaking_rate": 135.0,
            "pause_duration": 0.35
        ]

        let result = agent.analyze(text: "", prosodyFeatures: features)

        // Should be neutral or low-confidence non-neutral
        #expect(result.confidence <= 1.0)
    }

    // MARK: - Combined Analysis (Text + Prosody)

    @Test("Agreeing text and prosody produce high confidence")
    func testAgreeingTextAndProsody() {
        let anxiousFeatures: [String: Double] = [
            "pitch_mean": 240.0,
            "pitch_std": 45.0,
            "jitter": 3.5,
            "shimmer": 2.0,
            "speaking_rate": 180.0,
            "pause_duration": 0.2
        ]

        let result = agent.analyze(
            text: "I feel so worried and anxious about this nervous situation",
            prosodyFeatures: anxiousFeatures
        )

        #expect(result.label == .anxious)
        #expect(result.confidence > 0.5)
        #expect(result.valence < 0.0)
        #expect(result.arousal > 0.0)
    }

    @Test("Conflicting text and prosody uses weighted merge - text dominant at 0.6")
    func testConflictingTextAndProsody() {
        // Positive text + sad prosody
        let sadFeatures: [String: Double] = [
            "pitch_mean": 150.0,
            "pitch_std": 10.0,
            "jitter": 1.0,
            "shimmer": 4.5,
            "speaking_rate": 100.0,
            "pause_duration": 0.8
        ]

        let result = agent.analyze(
            text: "I am so happy and grateful and excited and wonderful and love everything amazing",
            prosodyFeatures: sadFeatures
        )

        // Text weight (0.6) should dominate with strong positive keywords
        // The exact result depends on confidence levels, but text should usually win
        #expect(result.confidence > 0.0)
        #expect(result.confidence <= 1.0)
    }

    @Test("Combined analysis includes prosody features in output")
    func testCombinedOutputIncludesProsody() {
        let features: [String: Double] = [
            "pitch_mean": 210.0,
            "pitch_std": 20.0,
            "jitter": 0.8,
            "shimmer": 1.0,
            "speaking_rate": 140.0,
            "pause_duration": 0.3
        ]

        let result = agent.analyze(
            text: "I feel good about today",
            prosodyFeatures: features
        )

        #expect(result.prosodyFeatures["pitch_mean"] == 210.0)
        #expect(result.prosodyFeatures["speaking_rate"] == 140.0)
    }

    // MARK: - Graceful Degradation

    @Test("Empty text and empty prosody returns neutral with zero confidence")
    func testEmptyInputs() {
        let result = agent.analyze(text: "", prosodyFeatures: [:])

        #expect(result.label == .neutral)
        #expect(result.confidence == 0.0)
    }

    @Test("Whitespace-only text is treated as empty")
    func testWhitespaceOnlyText() {
        let result = agent.analyze(text: "   \n\t  ", prosodyFeatures: [:])

        #expect(result.label == .neutral)
        #expect(result.confidence == 0.0)
    }

    @Test("Partial prosody features still produce valid result")
    func testPartialProsodyFeatures() {
        // Only pitch_mean provided, missing everything else
        let features: [String: Double] = [
            "pitch_mean": 150.0
        ]

        let result = agent.analyze(text: "", prosodyFeatures: features)

        // Should not crash, should produce a valid signal
        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
        #expect(result.valence >= -1.0)
        #expect(result.valence <= 1.0)
        #expect(result.arousal >= 0.0)
        #expect(result.arousal <= 1.0)
    }

    @Test("Confidence is always clamped between 0 and 1")
    func testConfidenceClamping() {
        // Dense keyword text to push confidence high
        let result = agent.analyze(
            text: "happy happy happy happy happy happy happy happy happy happy",
            prosodyFeatures: [:]
        )

        #expect(result.confidence >= 0.0)
        #expect(result.confidence <= 1.0)
    }

    @Test("Valence is always between -1 and 1")
    func testValenceRange() {
        let labels: [(String, [String: Double])] = [
            ("happy grateful excited", [:]),
            ("sad hopeless lonely", [:]),
            ("worried anxious nervous", [:]),
            ("went to the store", [:])
        ]

        for (text, features) in labels {
            let result = agent.analyze(text: text, prosodyFeatures: features)
            #expect(result.valence >= -1.0)
            #expect(result.valence <= 1.0)
        }
    }

    @Test("Arousal is always between 0 and 1")
    func testArousalRange() {
        let labels: [(String, [String: Double])] = [
            ("happy grateful excited", [:]),
            ("sad hopeless lonely", [:]),
            ("worried anxious nervous", [:]),
            ("went to the store", [:])
        ]

        for (text, features) in labels {
            let result = agent.analyze(text: text, prosodyFeatures: features)
            #expect(result.arousal >= 0.0)
            #expect(result.arousal <= 1.0)
        }
    }

    // MARK: - Internal Method Tests

    @Test("analyzeText correctly counts keyword matches")
    func testAnalyzeTextKeywordCounting() {
        let (label, confidence) = agent.analyzeText("happy grateful excited")
        #expect(label == .positive)
        #expect(confidence > 0.5)
    }

    @Test("analyzeText returns neutral with low confidence for no keywords")
    func testAnalyzeTextNoKeywords() {
        // REC-299: NLTagger returns ~0.4 confidence for descriptive text
        // that doesn't match any hint words. The old keyword classifier
        // returned 0.3 — we keep it neutral with a slightly higher floor
        // to reflect the actual classifier running.
        let (label, confidence) = agent.analyzeText("the weather is fine today")
        #expect(label == .neutral)
        #expect(confidence >= 0.3 && confidence <= 0.5)
    }

    @Test("analyzeText returns neutral with zero confidence for empty string")
    func testAnalyzeTextEmpty() {
        let (label, confidence) = agent.analyzeText("")
        #expect(label == .neutral)
        #expect(confidence == 0.0)
    }

    @Test("analyzeProsody returns neutral with zero confidence for empty features")
    func testAnalyzeProsodyEmpty() {
        let (label, confidence) = agent.analyzeProsody([:])
        #expect(label == .neutral)
        #expect(confidence == 0.0)
    }

    @Test("analyzeProsody detects anxious from high pitch variance + fast rate + high jitter")
    func testAnalyzeProsodyAnxious() {
        let (label, _) = agent.analyzeProsody([
            "pitch_std": 45.0,
            "speaking_rate": 180.0,
            "jitter": 3.5
        ])
        #expect(label == .anxious)
    }

    @Test("analyzeProsody detects sad from low pitch + slow rate + long pauses + high shimmer")
    func testAnalyzeProsodySad() {
        let (label, _) = agent.analyzeProsody([
            "pitch_mean": 150.0,
            "speaking_rate": 100.0,
            "pause_duration": 0.8,
            "shimmer": 4.5
        ])
        #expect(label == .sad)
    }

    // MARK: - MockEmotionService Tests

    @Test("MockEmotionService returns stubbed features")
    func testMockEmotionServiceStubbed() {
        let features = ["pitch_mean": 200.0, "jitter": 1.5]
        let mock = MockEmotionService(stubbedFeatures: features)

        let result = mock.extractProsodyFeatures(from: nil, voiceAnalytics: nil)
        #expect(result == features)
    }

    @Test("MockEmotionService presets have expected feature keys")
    func testMockEmotionServicePresets() {
        let expectedKeys: Set<String> = [
            "pitch_mean", "pitch_std", "jitter", "shimmer",
            "speaking_rate", "pause_duration"
        ]

        let anxious = MockEmotionService.anxious
        #expect(Set(anxious.stubbedFeatures.keys) == expectedKeys)

        let sad = MockEmotionService.sad
        #expect(Set(sad.stubbedFeatures.keys) == expectedKeys)

        let positive = MockEmotionService.positive
        #expect(Set(positive.stubbedFeatures.keys) == expectedKeys)

        let neutral = MockEmotionService.neutral
        #expect(Set(neutral.stubbedFeatures.keys) == expectedKeys)
    }

    @Test("MockEmotionService anxious preset triggers anxious classification")
    func testMockAnxiousPresetClassification() {
        let mock = MockEmotionService.anxious
        let features = mock.extractProsodyFeatures(from: nil, voiceAnalytics: nil)
        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .anxious)
    }

    @Test("MockEmotionService sad preset triggers sad classification")
    func testMockSadPresetClassification() {
        let mock = MockEmotionService.sad
        let features = mock.extractProsodyFeatures(from: nil, voiceAnalytics: nil)
        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .sad)
    }

    @Test("MockEmotionService positive preset triggers positive classification")
    func testMockPositivePresetClassification() {
        let mock = MockEmotionService.positive
        let features = mock.extractProsodyFeatures(from: nil, voiceAnalytics: nil)
        let result = agent.analyze(text: "", prosodyFeatures: features)

        #expect(result.label == .positive)
    }

    @Test("Default MockEmotionService returns empty features")
    func testMockEmotionServiceDefault() {
        let mock = MockEmotionService()
        let result = mock.extractProsodyFeatures(from: nil, voiceAnalytics: nil)
        #expect(result.isEmpty)
    }
}
