//
//  PersonalizationProfileTests.swift
//  MindLoopTests
//
//  Unit tests for PersonalizationProfile data model
//

import Testing
import Foundation
@testable import MindLoop

@Suite("PersonalizationProfile Tests")
struct PersonalizationProfileTests {
    
    @Test("PersonalizationProfile encodes and decodes correctly")
    func testCodable() throws {
        let profile = PersonalizationProfile.sampleCustomized
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersonalizationProfile.self, from: data)
        
        #expect(decoded == profile)
        #expect(decoded.id == profile.id)
        #expect(decoded.tonePref == profile.tonePref)
        #expect(decoded.responseLength == profile.responseLength)
        #expect(decoded.emotionTriggers == profile.emotionTriggers)
    }
    
    @Test("PersonalizationProfile initializes with default values")
    func testDefaultInitialization() {
        let profile = PersonalizationProfile()
        
        #expect(profile.id == "default")
        #expect(profile.tonePref == .warm)
        #expect(profile.responseLength == .medium)
        #expect(profile.emotionTriggers.isEmpty)
        #expect(profile.avoidTopics.isEmpty)
        #expect(profile.preferredActions.count == 2) // reframing + breathing
    }
    
    @Test("PersonalizationProfile feedback adjusts response length correctly")
    func testFeedbackResponseLength() {
        var profile = PersonalizationProfile.default
        
        // Test too long feedback
        profile.applyFeedback(
            feedbackType: .tooLong,
            context: PersonalizationProfile.FeedbackContext(
                action: nil,
                responseId: "test"
            )
        )
        #expect(profile.responseLength == .short) // medium -> short
        
        // Test too short feedback
        var profile2 = PersonalizationProfile.default
        profile2.applyFeedback(
            feedbackType: .tooShort,
            context: PersonalizationProfile.FeedbackContext(
                action: nil,
                responseId: "test"
            )
        )
        #expect(profile2.responseLength == .long) // medium -> long
        
        // Test boundary: short can't get shorter
        var profile3 = PersonalizationProfile.default
        profile3.responseLength = .short
        profile3.applyFeedback(
            feedbackType: .tooLong,
            context: PersonalizationProfile.FeedbackContext(
                action: nil,
                responseId: "test"
            )
        )
        #expect(profile3.responseLength == .short) // stays short
        
        // Test boundary: long can't get longer
        var profile4 = PersonalizationProfile.default
        profile4.responseLength = .long
        profile4.applyFeedback(
            feedbackType: .tooShort,
            context: PersonalizationProfile.FeedbackContext(
                action: nil,
                responseId: "test"
            )
        )
        #expect(profile4.responseLength == .long) // stays long
    }
    
    @Test("PersonalizationProfile feedback manages preferred actions")
    func testFeedbackPreferredActions() {
        var profile = PersonalizationProfile.default
        let initialActions = profile.preferredActions
        
        // Add helpful action
        profile.applyFeedback(
            feedbackType: .actionHelpful,
            context: PersonalizationProfile.FeedbackContext(
                action: .mindfulness,
                responseId: "test"
            )
        )
        #expect(profile.preferredActions.contains(.mindfulness))
        #expect(profile.preferredActions.count == initialActions.count + 1)
        
        // Remove unhelpful action
        profile.applyFeedback(
            feedbackType: .actionUnhelpful,
            context: PersonalizationProfile.FeedbackContext(
                action: .breathing,
                responseId: "test"
            )
        )
        #expect(!profile.preferredActions.contains(.breathing))
    }
    
    @Test("PersonalizationProfile emotion triggers can be added and removed")
    func testEmotionTriggers() {
        var profile = PersonalizationProfile.default
        
        // Add trigger
        profile.addEmotionTrigger("work_stress")
        #expect(profile.emotionTriggers.contains("work_stress"))
        
        // Adding duplicate doesn't duplicate
        profile.addEmotionTrigger("work_stress")
        #expect(profile.emotionTriggers.filter { $0 == "work_stress" }.count == 1)
        
        // Remove trigger
        profile.removeEmotionTrigger("work_stress")
        #expect(!profile.emotionTriggers.contains("work_stress"))
    }
    
    @Test("PersonalizationProfile isPreferred action check works")
    func testIsPreferredAction() {
        let profile = PersonalizationProfile.default
        
        #expect(profile.isPreferred(action: .reframing))
        #expect(profile.isPreferred(action: .breathing))
        #expect(!profile.isPreferred(action: .mindfulness)) // not in default
    }
    
    @Test("PersonalizationProfile tone descriptions are descriptive")
    func testToneDescriptions() {
        for tone in PersonalizationProfile.Tone.allCases {
            #expect(!tone.description.isEmpty)
            #expect(tone.description.count > 10) // Should be descriptive
        }
    }
    
    @Test("PersonalizationProfile response length has valid token ranges")
    func testResponseLengthTokenRanges() {
        #expect(PersonalizationProfile.ResponseLength.short.tokenRange == 50...80)
        #expect(PersonalizationProfile.ResponseLength.medium.tokenRange == 80...120)
        #expect(PersonalizationProfile.ResponseLength.long.tokenRange == 120...150)
        
        // Verify ranges don't overlap incorrectly
        let shortMax = PersonalizationProfile.ResponseLength.short.tokenRange.upperBound
        let mediumMin = PersonalizationProfile.ResponseLength.medium.tokenRange.lowerBound
        #expect(shortMax == mediumMin)
    }
    
    @Test("PersonalizationProfile prompt instructions are well-formed")
    func testPromptInstructions() {
        let profile = PersonalizationProfile.sampleCustomized
        let instructions = profile.promptInstructions
        
        #expect(!instructions.isEmpty)
        #expect(instructions.contains("Tone:"))
        #expect(instructions.contains("Response length:"))
        #expect(instructions.contains("Preferred techniques:"))
        #expect(instructions.contains("Known triggers:"))
        #expect(instructions.contains("\n")) // Multiple lines
    }
    
    @Test("PersonalizationProfile preferred action display names are clear")
    func testPreferredActionDisplayNames() {
        let actions: [PersonalizationProfile.PreferredAction: String] = [
            .breathing: "Breathing Exercises",
            .journaling: "Journaling",
            .reframing: "Cognitive Reframing",
            .behavioralActivation: "Behavioral Activation",
            .mindfulness: "Mindfulness",
            .evidenceTesting: "Evidence Testing",
            .thoughtRecords: "Thought Records"
        ]
        
        for (action, expectedName) in actions {
            #expect(action.displayName == expectedName)
        }
    }
    
    @Test("PersonalizationProfile lastUpdated updates on changes")
    func testLastUpdatedTracking() {
        var profile = PersonalizationProfile.default
        let originalTimestamp = profile.lastUpdated
        
        // Wait a tiny bit to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)
        
        profile.addEmotionTrigger("test")
        #expect(profile.lastUpdated > originalTimestamp)
        
        let secondTimestamp = profile.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        
        profile.removeEmotionTrigger("test")
        #expect(profile.lastUpdated > secondTimestamp)
    }
}
