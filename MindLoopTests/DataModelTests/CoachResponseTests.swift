//
//  CoachResponseTests.swift
//  MindLoopTests
//
//  Unit tests for CoachResponse data model
//

import Testing
import Foundation
@testable import MindLoop

@Suite("CoachResponse Tests")
struct CoachResponseTests {
    
    @Test("CoachResponse encodes and decodes correctly")
    func testCodable() throws {
        let response = CoachResponse.sample
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CoachResponse.self, from: data)
        
        #expect(decoded == response)
        #expect(decoded.id == response.id)
        #expect(decoded.text == response.text)
        #expect(decoded.citedEntries == response.citedEntries)
        #expect(decoded.nextState == response.nextState)
    }
    
    @Test("CoachResponse word count is accurate")
    func testWordCount() {
        let response1 = CoachResponse(
            text: "One two three four five",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 5,
                latencyMs: 1000,
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(response1.wordCount == 5)
        
        let response2 = CoachResponse(
            text: "Word   with    extra    spaces",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 4,
                latencyMs: 1000,
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(response2.wordCount == 4)
    }
    
    @Test("CoachResponse hasCitations property works")
    func testHasCitations() {
        let withCitations = CoachResponse.sample
        #expect(withCitations.hasCitations)
        #expect(withCitations.citedEntries.count > 0)
        
        let withoutCitations = CoachResponse.sampleInitial
        #expect(!withoutCitations.hasCitations)
        #expect(withoutCitations.citedEntries.isEmpty)
    }
    
    @Test("CoachResponse hasAction property works")
    func testHasAction() {
        let withAction = CoachResponse.sampleWithAction
        #expect(withAction.hasAction)
        #expect(withAction.suggestedAction != nil)
        
        let withoutAction = CoachResponse.sampleInitial
        #expect(!withoutAction.hasAction)
    }
    
    @Test("CoachResponse formatted latency displays correctly")
    func testFormattedLatency() {
        let response1 = CoachResponse(
            text: "Test",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 10,
                latencyMs: 1500,
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(response1.formattedLatency == "1.5s")
        
        let response2 = CoachResponse(
            text: "Test",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 10,
                latencyMs: 2850,
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(response2.formattedLatency == "2.8s")
    }
    
    @Test("CoachResponse performance level classification is correct")
    func testPerformanceLevel() {
        let good = CoachResponse(
            text: "Test",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 10,
                latencyMs: 1500, // < 2s
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(good.performanceLevel == .good)
        
        let acceptable = CoachResponse(
            text: "Test",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 10,
                latencyMs: 2500, // 2-3s
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(acceptable.performanceLevel == .acceptable)
        
        let slow = CoachResponse(
            text: "Test",
            nextState: .goal,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: 10,
                latencyMs: 3500, // > 3s
                model: "test",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 0,
                    cardId: nil
                )
            )
        )
        #expect(slow.performanceLevel == .slow)
    }
    
    @Test("CoachResponse CBT states have correct display names")
    func testCBTStateDisplayNames() {
        #expect(CoachResponse.CBTState.goal.displayName == "Goal Setting")
        #expect(CoachResponse.CBTState.situation.displayName == "Situation")
        #expect(CoachResponse.CBTState.thoughts.displayName == "Thoughts")
        #expect(CoachResponse.CBTState.feelings.displayName == "Feelings")
        #expect(CoachResponse.CBTState.distortions.displayName == "Distortions")
        #expect(CoachResponse.CBTState.reframe.displayName == "Reframe")
        #expect(CoachResponse.CBTState.action.displayName == "Action")
        #expect(CoachResponse.CBTState.reflect.displayName == "Reflect")
    }
    
    @Test("CoachResponse CBT states have prompt guides")
    func testCBTStatePromptGuides() {
        for state in CoachResponse.CBTState.allCases {
            #expect(!state.promptGuide.isEmpty)
            #expect(state.promptGuide.contains("?") || state.promptGuide.contains("..."))
        }
    }
    
    @Test("CoachResponse metadata is properly encoded")
    func testMetadataEncoding() throws {
        let metadata = CoachResponse.ResponseMetadata(
            tokenCount: 95,
            latencyMs: 1850,
            model: "qwen3-4b-int4",
            loraAdapter: "tone-warm",
            retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                entryCount: 3,
                cardId: "card_reframing"
            )
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CoachResponse.ResponseMetadata.self, from: data)
        
        #expect(decoded == metadata)
        #expect(decoded.tokenCount == 95)
        #expect(decoded.latencyMs == 1850)
        #expect(decoded.model == "qwen3-4b-int4")
        #expect(decoded.loraAdapter == "tone-warm")
        #expect(decoded.retrievalContext.entryCount == 3)
        #expect(decoded.retrievalContext.cardId == "card_reframing")
    }
}
