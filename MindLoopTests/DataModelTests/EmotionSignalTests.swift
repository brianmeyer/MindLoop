//
//  EmotionSignalTests.swift
//  MindLoopTests
//
//  Unit tests for EmotionSignal data model
//

import Testing
import Foundation
@testable import MindLoop

@Suite("EmotionSignal Tests")
struct EmotionSignalTests {
    
    @Test("EmotionSignal encodes and decodes correctly")
    func testCodable() throws {
        let emotion = EmotionSignal.sampleAnxious
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(emotion)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EmotionSignal.self, from: data)
        
        #expect(decoded == emotion)
        #expect(decoded.label == emotion.label)
        #expect(decoded.confidence == emotion.confidence)
        #expect(decoded.valence == emotion.valence)
        #expect(decoded.arousal == emotion.arousal)
    }
    
    @Test("EmotionSignal clamps values to valid ranges")
    func testValueClamping() {
        let emotion = EmotionSignal(
            label: .neutral,
            confidence: 1.5, // Over max
            valence: -2.0,   // Under min
            arousal: 1.2     // Over max
        )
        
        #expect(emotion.confidence == 1.0)
        #expect(emotion.valence == -1.0)
        #expect(emotion.arousal == 1.0)
    }
    
    @Test("EmotionSignal confidence percentage is correct")
    func testConfidencePercentage() {
        let emotion1 = EmotionSignal(
            label: .positive,
            confidence: 0.75,
            valence: 0.5,
            arousal: 0.4
        )
        #expect(emotion1.confidencePercentage == 75)
        
        let emotion2 = EmotionSignal(
            label: .anxious,
            confidence: 0.923,
            valence: -0.4,
            arousal: 0.7
        )
        #expect(emotion2.confidencePercentage == 92)
    }
    
    @Test("EmotionSignal high confidence detection works")
    func testHighConfidence() {
        let high = EmotionSignal(
            label: .positive,
            confidence: 0.85,
            valence: 0.6,
            arousal: 0.3
        )
        #expect(high.isHighConfidence)
        
        let low = EmotionSignal(
            label: .neutral,
            confidence: 0.45,
            valence: 0.0,
            arousal: 0.2
        )
        #expect(!low.isHighConfidence)
    }
    
    @Test("EmotionSignal valence classification is correct")
    func testValenceClassification() {
        let negative = EmotionSignal(
            label: .sad,
            confidence: 0.8,
            valence: -0.5,
            arousal: 0.3
        )
        #expect(negative.isNegative)
        #expect(!negative.isPositive)
        
        let positive = EmotionSignal(
            label: .positive,
            confidence: 0.8,
            valence: 0.6,
            arousal: 0.4
        )
        #expect(positive.isPositive)
        #expect(!positive.isNegative)
        
        let neutral = EmotionSignal(
            label: .neutral,
            confidence: 0.9,
            valence: 0.0,
            arousal: 0.2
        )
        #expect(!neutral.isPositive)
        #expect(!neutral.isNegative)
    }
    
    @Test("EmotionSignal arousal classification is correct")
    func testArousalClassification() {
        let highArousal = EmotionSignal(
            label: .anxious,
            confidence: 0.8,
            valence: -0.4,
            arousal: 0.8
        )
        #expect(highArousal.isHighArousal)
        
        let lowArousal = EmotionSignal(
            label: .sad,
            confidence: 0.8,
            valence: -0.5,
            arousal: 0.3
        )
        #expect(!lowArousal.isHighArousal)
    }
    
    @Test("EmotionSignal circumplex categorization is accurate")
    func testCircumplex() {
        let excited = EmotionSignal(
            label: .positive,
            confidence: 0.8,
            valence: 0.7,
            arousal: 0.8
        )
        #expect(excited.circumplex == "Excited")
        
        let content = EmotionSignal(
            label: .positive,
            confidence: 0.8,
            valence: 0.5,
            arousal: 0.2
        )
        #expect(content.circumplex == "Content")
        
        let distressed = EmotionSignal(
            label: .anxious,
            confidence: 0.8,
            valence: -0.6,
            arousal: 0.8
        )
        #expect(distressed.circumplex == "Distressed")
        
        let sad = EmotionSignal(
            label: .sad,
            confidence: 0.8,
            valence: -0.5,
            arousal: 0.2
        )
        #expect(sad.circumplex == "Sad")
        
        let neutral = EmotionSignal.sampleNeutral
        #expect(neutral.circumplex == "Neutral")
    }
    
    @Test("EmotionSignal unknown emotion has zero confidence")
    func testUnknownEmotion() {
        let unknown = EmotionSignal.unknown
        
        #expect(unknown.label == .neutral)
        #expect(unknown.confidence == 0.0)
        #expect(unknown.valence == 0.0)
        #expect(unknown.arousal == 0.0)
        #expect(unknown.prosodyFeatures.isEmpty)
    }
    
    @Test("EmotionSignal fromTextSentiment creates valid signal")
    func testFromTextSentiment() {
        let emotion = EmotionSignal.fromTextSentiment(
            label: .positive,
            confidence: 0.85,
            valence: 0.7
        )
        
        #expect(emotion.label == .positive)
        #expect(emotion.confidence == 0.85)
        #expect(emotion.valence == 0.7)
        #expect(emotion.arousal == 0.5) // Default neutral arousal
        #expect(emotion.prosodyFeatures.isEmpty)
    }
}
