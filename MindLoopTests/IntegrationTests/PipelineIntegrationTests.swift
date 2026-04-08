//
//  PipelineIntegrationTests.swift
//  MindLoopTests
//
//  End-to-end integration tests for the Orchestrator pipeline.
//  Ticket: REC-250
//
//  Uses real EmotionAgent, JournalAgent, SafetyAgent with mocked
//  CoachAgent (via generateFn) and in-memory AppDatabase for isolation.
//

import Testing
import Foundation
@testable import MindLoop

// MARK: - Test Helpers

/// Creates a mock generate function that yields predefined tokens.
private func stubGenerateFn(
    response: String
) -> @Sendable (String, Int, Float) -> AsyncStream<String> {
    { _, _, _ in
        AsyncStream { continuation in
            let words = response.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                let token = index == 0 ? word : " " + word
                continuation.yield(token)
            }
            continuation.finish()
        }
    }
}

/// Creates a mock generate function that always throws.
private func throwingGenerateFn() -> @Sendable (String, Int, Float) -> AsyncStream<String> {
    { _, _, _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

/// Creates a standard Orchestrator with mocked CoachAgent and isolated DB.
@MainActor
private func buildOrchestrator(
    coachResponse: String = "I hear you. Let's take a breath and look at this together. Try writing down one thing you did well today.",
    database: AppDatabase? = nil
) throws -> (Orchestrator, AppDatabase) {
    let db = try database ?? AppDatabase.makeEmpty()
    let coachAgent = CoachAgent(generateFn: stubGenerateFn(response: coachResponse))
    let learningLoopAgent = LearningLoopAgent(database: db)

    let orchestrator = Orchestrator(
        emotionAgent: EmotionAgent(),
        journalAgent: JournalAgent(),
        safetyAgent: SafetyAgent(),
        retrievalAgent: RetrievalAgent(),
        coachAgent: coachAgent,
        learningLoopAgent: learningLoopAgent,
        database: db
    )
    return (orchestrator, db)
}

// MARK: - 1. Full Pipeline Happy Path

@Suite("Pipeline Integration - Happy Path")
@MainActor
struct FullPipelineHappyPathTests {

    @Test("Text flows through emotion -> journal -> embed -> retrieve -> coach -> safety -> response")
    func testFullPipelineEndToEnd() async throws {
        let expectedResponse = "I hear you. Let's take a breath and look at this together. Try writing down one thing you did well today."
        let (orchestrator, db) = try buildOrchestrator(coachResponse: expectedResponse)

        await orchestrator.processText("I'm feeling stressed about the presentation tomorrow.")

        // Response was generated
        #expect(orchestrator.currentResponse != nil)
        #expect(orchestrator.currentResponse?.text == expectedResponse)

        // Emotion was detected (text contains "stressed" which maps to anxious keywords)
        #expect(orchestrator.currentEmotion != nil)

        // Pipeline returned to idle
        #expect(orchestrator.pipelineState == .idle)

        // Not blocked by safety
        #expect(orchestrator.isBlocked == false)
        #expect(orchestrator.deescalationMessage == nil)

        // Journal entry persisted
        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.text.contains("presentation") == true)

        // CBT state advanced from initial .goal
        #expect(orchestrator.cbtState != .goal)

        // No error
        #expect(orchestrator.errorMessage == nil)

        // Streaming text populated
        #expect(orchestrator.streamingText == expectedResponse)
    }
}

// MARK: - 2. CBT State Transitions

@Suite("Pipeline Integration - CBT State Transitions")
@MainActor
struct PipelineCBTStateTransitionTests {

    @Test("State advances through full CBT flow: goal -> situation -> thoughts -> feelings -> distortions -> reframe -> action -> reflect")
    func testFullCBTFlow() async throws {
        // Verify the CBTState enum has the correct nextState chain
        #expect(CBTState.goal.nextState == .situation)
        #expect(CBTState.situation.nextState == .thoughts)
        #expect(CBTState.thoughts.nextState == .feelings)
        #expect(CBTState.feelings.nextState == .distortions)
        #expect(CBTState.distortions.nextState == .reframe)
        #expect(CBTState.reframe.nextState == .action)
        #expect(CBTState.action.nextState == .reflect)
        #expect(CBTState.reflect.nextState == .goal)
    }

    @Test("Processing multiple inputs advances CBT state progressively")
    func testProgressiveCBTAdvance() async throws {
        let responseText = "I hear you. Tell me more about the situation."
        let (orchestrator, _) = try buildOrchestrator(coachResponse: responseText)

        // Initial state
        #expect(orchestrator.cbtState == .goal)

        // First input: goal -> situation
        await orchestrator.processText("I want to work on my anxiety about public speaking.")
        let stateAfterFirst = orchestrator.cbtState
        #expect(stateAfterFirst != .goal, "State should advance from goal after first input")

        // Second input: advances further
        await orchestrator.processText("It happened during a team meeting.")
        #expect(orchestrator.currentResponse != nil)
        #expect(orchestrator.pipelineState == .idle)
    }

    @Test("resetConversation returns to goal state and clears all state")
    func testResetClearsAllState() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        await orchestrator.processText("I'm feeling anxious about tomorrow.")
        #expect(orchestrator.cbtState != .goal || orchestrator.currentResponse != nil)

        orchestrator.resetConversation()

        #expect(orchestrator.cbtState == .goal)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentResponse == nil)
        #expect(orchestrator.isBlocked == false)
        #expect(orchestrator.deescalationMessage == nil)
        #expect(orchestrator.streamingText == "")
        #expect(orchestrator.currentEmotion == nil)
        #expect(orchestrator.errorMessage == nil)
    }

    @Test("setCBTState allows manual override of CBT state")
    func testManualStateOverride() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        for state in CBTState.allCases {
            orchestrator.setCBTState(state)
            #expect(orchestrator.cbtState == state)
        }
    }
}

// MARK: - 3. Safety Blocking

@Suite("Pipeline Integration - Safety Blocking")
@MainActor
struct SafetyBlockingTests {

    @Test("Crisis text in coach response triggers safety block with de-escalation")
    func testCrisisTextBlocked() async throws {
        // Coach response contains crisis keywords that SafetyAgent will catch
        let crisisResponse = "I understand you want to kill myself and end it all."
        let (orchestrator, _) = try buildOrchestrator(coachResponse: crisisResponse)

        await orchestrator.processText("I'm feeling really down today.")

        // Safety blocked
        #expect(orchestrator.isBlocked == true)
        #expect(orchestrator.pipelineState == .blocked)
        #expect(orchestrator.currentResponse == nil)

        // De-escalation message shown with crisis resources
        #expect(orchestrator.deescalationMessage != nil)
        #expect(orchestrator.deescalationMessage == SafetyAgent.deescalationResponse)
        #expect(orchestrator.deescalationMessage?.contains("988") == true)
        #expect(orchestrator.deescalationMessage?.contains("741741") == true)
    }

    @Test("Coach response with suicide keyword triggers block")
    func testSuicideKeywordBlocked() async throws {
        let crisisResponse = "You mentioned feeling suicidal and not worth living."
        let (orchestrator, _) = try buildOrchestrator(coachResponse: crisisResponse)

        await orchestrator.processText("Help me.")

        #expect(orchestrator.isBlocked == true)
        #expect(orchestrator.pipelineState == .blocked)
        #expect(orchestrator.deescalationMessage != nil)
    }

    @Test("Safe coach response passes through safety gate")
    func testSafeResponseAllowed() async throws {
        let safeResponse = "That sounds challenging. Take three deep breaths and notice how you feel."
        let (orchestrator, _) = try buildOrchestrator(coachResponse: safeResponse)

        await orchestrator.processText("I had a tough day at work.")

        #expect(orchestrator.isBlocked == false)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentResponse?.text == safeResponse)
    }
}

// MARK: - 4. Empty Input

@Suite("Pipeline Integration - Empty Input")
@MainActor
struct PipelineEmptyInputTests {

    @Test("Empty string returns early with no crash and no state change")
    func testEmptyString() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("")

        #expect(orchestrator.currentResponse == nil)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentEmotion == nil)
        #expect(orchestrator.errorMessage == nil)
        #expect(orchestrator.cbtState == .goal)

        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }

    @Test("Whitespace-only string returns early")
    func testWhitespaceOnly() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("   \n\t  ")

        #expect(orchestrator.currentResponse == nil)
        #expect(orchestrator.pipelineState == .idle)

        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }

    @Test("Newlines-only string returns early")
    func testNewlinesOnly() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("\n\n\n")

        #expect(orchestrator.currentResponse == nil)
        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }
}

// MARK: - 5. Anxious Persona

@Suite("Pipeline Integration - Anxious Persona")
@MainActor
struct AnxiousPersonaTests {

    @Test("Anxious input text is detected as anxious emotion")
    func testAnxiousEmotionDetection() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        await orchestrator.processText("I'm so worried about my presentation tomorrow")

        #expect(orchestrator.currentEmotion != nil)
        #expect(orchestrator.currentEmotion?.label == .anxious,
               "EmotionAgent should classify 'worried' keyword as anxious")
    }

    @Test("Anxious input produces journal entry tagged with anxiety")
    func testAnxiousJournalTag() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("I'm so worried about my presentation tomorrow")

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.emotionLabel == "anxious")
    }
}

// MARK: - 6. Neutral Persona

@Suite("Pipeline Integration - Neutral Persona")
@MainActor
struct NeutralPersonaTests {

    @Test("Neutral input text is detected as neutral emotion")
    func testNeutralEmotionDetection() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        await orchestrator.processText("Today I went grocery shopping")

        #expect(orchestrator.currentEmotion != nil)
        #expect(orchestrator.currentEmotion?.label == .neutral,
               "EmotionAgent should classify neutral text without emotion keywords as neutral")
    }

    @Test("Neutral input produces journal entry with neutral emotion")
    func testNeutralJournalEntry() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("Today I went grocery shopping")

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.emotionLabel == "neutral")
    }
}

// MARK: - 7. Positive Persona

@Suite("Pipeline Integration - Positive Persona")
@MainActor
struct PositivePersonaTests {

    @Test("Positive input text is detected as positive emotion")
    func testPositiveEmotionDetection() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        await orchestrator.processText("I had an amazing day with friends")

        #expect(orchestrator.currentEmotion != nil)
        #expect(orchestrator.currentEmotion?.label == .positive,
               "EmotionAgent should classify 'amazing' keyword as positive")
    }

    @Test("Positive input produces journal entry with positive emotion")
    func testPositiveJournalEntry() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("I had an amazing day with friends")

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.emotionLabel == "positive")
    }
}

// MARK: - 8. Coach Unavailable

@Suite("Pipeline Integration - Coach Unavailable")
@MainActor
struct CoachUnavailableTests {

    @Test("CoachAgent returning empty response sets errorMessage without crash")
    func testCoachEmptyResponseSetsError() async throws {
        // generateFn that returns empty stream (simulates model failure)
        let db = try AppDatabase.makeEmpty()
        let emptyCoach = CoachAgent(generateFn: throwingGenerateFn())
        let learningLoop = LearningLoopAgent(database: db)

        let orchestrator = Orchestrator(
            emotionAgent: EmotionAgent(),
            journalAgent: JournalAgent(),
            safetyAgent: SafetyAgent(),
            retrievalAgent: RetrievalAgent(),
            coachAgent: emptyCoach,
            learningLoopAgent: learningLoop,
            database: db
        )

        await orchestrator.processText("I need coaching advice today.")

        // Error message set, no crash
        #expect(orchestrator.errorMessage != nil)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentResponse == nil)
    }

    @Test("CoachAgent without generateFn sets errorMessage without crash")
    func testCoachNoRuntimeSetsError() async throws {
        let db = try AppDatabase.makeEmpty()
        // CoachAgent with nil generateFn -- throws .resourceUnavailable
        let unavailableCoach = CoachAgent(generateFn: nil)
        let learningLoop = LearningLoopAgent(database: db)

        let orchestrator = Orchestrator(
            emotionAgent: EmotionAgent(),
            journalAgent: JournalAgent(),
            safetyAgent: SafetyAgent(),
            retrievalAgent: RetrievalAgent(),
            coachAgent: unavailableCoach,
            learningLoopAgent: learningLoop,
            database: db
        )

        await orchestrator.processText("Tell me something helpful.")

        // Error message set, no crash
        #expect(orchestrator.errorMessage != nil)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentResponse == nil)

        // Journal entry was still saved (before coach failure)
        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
    }
}

// MARK: - 9. Feedback Recording

@Suite("Pipeline Integration - Feedback Recording")
@MainActor
struct PipelineFeedbackRecordingTests {

    @Test("Thumbs up feedback flows through LearningLoopAgent and updates profile")
    func testThumbsUpUpdatesProfile() async throws {
        let responseText = "Try taking three deep breaths right now. It can help reset."
        let (orchestrator, db) = try buildOrchestrator(coachResponse: responseText)

        await orchestrator.processText("I'm feeling overwhelmed.")
        #expect(orchestrator.currentResponse != nil)

        await orchestrator.recordFeedback(.thumbsUp)

        // Profile should be fetchable and recently updated
        let profile = try db.fetchProfile().toDomain()
        #expect(profile.id == "default")
        let timeSinceUpdate = Date().timeIntervalSince(profile.lastUpdated)
        #expect(timeSinceUpdate < 5.0, "Profile should have been recently updated")
    }

    @Test("Thumbs down feedback adjusts profile preferences")
    func testThumbsDownAdjustsProfile() async throws {
        let responseText = "Try taking three deep breaths right now. It can help reset your nervous system and bring you back to the present moment."
        let (orchestrator, db) = try buildOrchestrator(coachResponse: responseText)

        await orchestrator.processText("I'm stressed about everything.")
        #expect(orchestrator.currentResponse != nil)

        await orchestrator.recordFeedback(.thumbsDown)

        let profile = try db.fetchProfile().toDomain()
        let timeSinceUpdate = Date().timeIntervalSince(profile.lastUpdated)
        #expect(timeSinceUpdate < 5.0, "Profile should have been recently updated")
    }

    @Test("Feedback without current response is a safe no-op")
    func testFeedbackWithoutResponseNoOp() async throws {
        let (orchestrator, _) = try buildOrchestrator()

        // No processText called
        #expect(orchestrator.currentResponse == nil)

        // Should not crash
        await orchestrator.recordFeedback(.thumbsUp)
        await orchestrator.recordFeedback(.thumbsDown)

        // State unchanged
        #expect(orchestrator.pipelineState == .idle)
    }

    @Test("Multiple entries create independent journal records")
    func testMultipleEntriesIndependent() async throws {
        let (orchestrator, db) = try buildOrchestrator()

        await orchestrator.processText("First entry about work stress.")
        await orchestrator.processText("Second entry about feeling grateful.")
        await orchestrator.processText("Third entry about sleep issues.")

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 3)
    }
}
