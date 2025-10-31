//
//  CBTCardTests.swift
//  MindLoopTests
//
//  Unit tests for CBTCard data model
//

import Testing
import Foundation
@testable import MindLoop

@Suite("CBTCard Tests")
struct CBTCardTests {
    
    @Test("CBTCard encodes and decodes correctly")
    func testCodable() throws {
        let card = CBTCard.sampleReframing
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(card)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CBTCard.self, from: data)
        
        #expect(decoded == card)
        #expect(decoded.id == card.id)
        #expect(decoded.title == card.title)
        #expect(decoded.technique == card.technique)
        #expect(decoded.example == card.example)
    }
    
    @Test("CBTCard initializes with all required fields")
    func testInitialization() {
        let card = CBTCard(
            id: "test-card",
            title: "Test Technique",
            technique: "This is a test technique description.",
            example: "Example of the technique in action."
        )
        
        #expect(card.id == "test-card")
        #expect(card.title == "Test Technique")
        #expect(card.distortionType == nil)
        #expect(card.difficulty == .beginner) // Default
    }
    
    @Test("CBTCard preview truncates long technique text")
    func testTechniquePreview() {
        let shortTechnique = "Short technique"
        let shortCard = CBTCard(
            id: "short",
            title: "Test",
            technique: shortTechnique,
            example: "Example"
        )
        #expect(shortCard.techniquePreview == shortTechnique)
        
        let longTechnique = String(repeating: "a", count: 200)
        let longCard = CBTCard(
            id: "long",
            title: "Test",
            technique: longTechnique,
            example: "Example"
        )
        #expect(longCard.techniquePreview.count == 123) // 120 chars + "..."
        #expect(longCard.techniquePreview.hasSuffix("..."))
    }
    
    @Test("CBTCard distortion types have correct display names")
    func testDistortionTypeDisplayNames() {
        let types: [CBTCard.DistortionType: String] = [
            .allOrNothing: "All-or-Nothing Thinking",
            .overgeneralization: "Overgeneralization",
            .mentalFilter: "Mental Filter",
            .catastrophizing: "Catastrophizing",
            .emotionalReasoning: "Emotional Reasoning"
        ]
        
        for (type, expectedName) in types {
            #expect(type.displayName == expectedName)
        }
    }
    
    @Test("CBTCard difficulty levels have correct display names")
    func testDifficultyDisplayNames() {
        #expect(CBTCard.Difficulty.beginner.displayName == "Beginner")
        #expect(CBTCard.Difficulty.intermediate.displayName == "Intermediate")
        #expect(CBTCard.Difficulty.advanced.displayName == "Advanced")
    }
    
    @Test("CBTCard sample cards are valid")
    func testSampleCards() {
        let samples = CBTCard.allSamples
        
        #expect(samples.count == 6)
        
        // Check that all sample cards have required fields
        for card in samples {
            #expect(!card.id.isEmpty)
            #expect(!card.title.isEmpty)
            #expect(!card.technique.isEmpty)
            #expect(!card.example.isEmpty)
        }
        
        // Check specific samples
        #expect(samples.contains(where: { $0.id == "card_reframing" }))
        #expect(samples.contains(where: { $0.id == "card_mindfulness" }))
        #expect(samples.contains(where: { $0.id == "card_evidence_testing" }))
    }
    
    @Test("CBTCard handles optional distortion type correctly")
    func testOptionalDistortionType() {
        let withDistortion = CBTCard(
            id: "test1",
            title: "Test",
            technique: "Technique",
            example: "Example",
            distortionType: .catastrophizing
        )
        #expect(withDistortion.distortionType == .catastrophizing)
        
        let withoutDistortion = CBTCard(
            id: "test2",
            title: "Test",
            technique: "Technique",
            example: "Example",
            distortionType: nil
        )
        #expect(withoutDistortion.distortionType == nil)
    }
}
