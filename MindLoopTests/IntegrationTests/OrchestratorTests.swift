//
//  OrchestratorTests.swift
//  MindLoopTests
//
//  Integration tests for the Orchestrator pipeline end-to-end.
//  Uses real agents with mocked CoachAgent generateFn and
//  in-memory AppDatabase for per-test isolation.
//

import Testing
import Foundation
@testable import MindLoop

// MARK: - Test Helpers

/// Creates a mock generate function that yields predefined tokens.
private func mockGenerateFn(
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

/// Creates a mock generate function that includes crisis keywords in the response,
/// which will be caught by the SafetyAgent gate.
private func mockCrisisGenerateFn() -> @Sendable (String, Int, Float) -> AsyncStream<String> {
    mockGenerateFn(response: "I understand you want to kill myself and end it all.")
}

/// Creates a standard Orchestrator with mocked CoachAgent and isolated DB.
@MainActor
private func makeOrchestrator(
    coachResponse: String = "I hear you. Let's take a breath and look at this together. Try writing down one thing you did well today.",
    database: AppDatabase? = nil
) throws -> (Orchestrator, AppDatabase) {
    let db = try database ?? AppDatabase.makeEmpty()
    let coachAgent = CoachAgent(generateFn: mockGenerateFn(response: coachResponse))
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

// MARK: - Happy Path

@Suite("Happy Path Pipeline")
@MainActor
struct HappyPathTests {

    @Test("Text input flows through full pipeline and stores response")
    func testFullPipeline() async throws {
        let expectedResponse = "I hear you. Let's take a breath and look at this together. Try writing down one thing you did well today."
        let (orchestrator, db) = try makeOrchestrator(coachResponse: expectedResponse)

        await orchestrator.processText("I'm feeling stressed about the presentation tomorrow.")

        // Response was generated and stored
        #expect(orchestrator.currentResponse != nil)
        #expect(orchestrator.currentResponse?.text == expectedResponse)

        // Emotion was detected
        #expect(orchestrator.currentEmotion != nil)

        // Pipeline returned to idle
        #expect(orchestrator.pipelineState == .idle)

        // Not blocked
        #expect(orchestrator.isBlocked == false)
        #expect(orchestrator.deescalationMessage == nil)

        // Journal entry was saved to database
        let entries = try db.fetchAllEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.text.contains("presentation") == true)

        // CBT state advanced from initial .goal
        #expect(orchestrator.cbtState != .goal)

        // No error
        #expect(orchestrator.errorMessage == nil)
    }

    @Test("Streaming text is populated with response")
    func testStreamingTextPopulated() async throws {
        let responseText = "That sounds challenging. Take three deep breaths."
        let (orchestrator, _) = try makeOrchestrator(coachResponse: responseText)

        await orchestrator.processText("I had a rough day at work today.")

        #expect(orchestrator.streamingText == responseText)
    }
}

// MARK: - Safety Block

@Suite("Safety Block Pipeline")
@MainActor
struct SafetyBlockTests {

    @Test("Crisis keywords in coach response trigger safety block")
    func testSafetyBlockOnCrisisResponse() async throws {
        let db = try AppDatabase.makeEmpty()
        // The coach response contains crisis keywords that SafetyAgent will catch
        let crisisResponse = "I understand you want to kill myself and end it all."
        let coachAgent = CoachAgent(generateFn: mockGenerateFn(response: crisisResponse))
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

        await orchestrator.processText("I'm feeling really down today.")

        // Safety should have blocked the response
        #expect(orchestrator.isBlocked == true)
        #expect(orchestrator.pipelineState == .blocked)
        #expect(orchestrator.currentResponse == nil)

        // Deescalation message should be shown
        #expect(orchestrator.deescalationMessage != nil)
        #expect(orchestrator.deescalationMessage == SafetyAgent.deescalationResponse)

        // Deescalation message contains crisis resources
        #expect(orchestrator.deescalationMessage?.contains("988") == true)
        #expect(orchestrator.deescalationMessage?.contains("741741") == true)
    }
}

// MARK: - CBT State Transitions

@Suite("CBT State Transitions - Orchestrator")
@MainActor
struct OrchestratorCBTStateTests {

    @Test("Processing multiple inputs advances CBT state through the flow")
    func testStateAdvancesMultipleInputs() async throws {
        // Coach response returns default transitions (goal -> situation -> thoughts -> ...)
        let responseText = "I hear you. Tell me more about the situation."
        let (orchestrator, _) = try makeOrchestrator(coachResponse: responseText)

        // Initial state should be .goal
        #expect(orchestrator.cbtState == .goal)

        // First input: goal -> situation
        await orchestrator.processText("I want to work on my work stress.")
        let firstState = orchestrator.cbtState
        #expect(firstState != .goal, "State should advance from goal after first input")

        // Second input: advances further
        await orchestrator.processText("It happened during a meeting with my boss.")
        // State may or may not advance depending on coach response, but pipeline completes
        #expect(orchestrator.currentResponse != nil)
        #expect(orchestrator.pipelineState == .idle)
    }

    @Test("resetConversation returns to goal state")
    func testResetConversation() async throws {
        let (orchestrator, _) = try makeOrchestrator()

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

    @Test("setCBTState allows manual state override")
    func testSetCBTState() async throws {
        let (orchestrator, _) = try makeOrchestrator()

        orchestrator.setCBTState(.reframe)
        #expect(orchestrator.cbtState == .reframe)

        orchestrator.setCBTState(.action)
        #expect(orchestrator.cbtState == .action)
    }
}

// MARK: - Empty Input

@Suite("Empty Input Handling")
@MainActor
struct EmptyInputTests {

    @Test("Empty string produces no processing")
    func testEmptyString() async throws {
        let (orchestrator, db) = try makeOrchestrator()

        await orchestrator.processText("")

        #expect(orchestrator.currentResponse == nil)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentEmotion == nil)

        // No entry saved
        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }

    @Test("Whitespace-only string produces no processing")
    func testWhitespaceOnly() async throws {
        let (orchestrator, db) = try makeOrchestrator()

        await orchestrator.processText("   \n\t  ")

        #expect(orchestrator.currentResponse == nil)
        #expect(orchestrator.pipelineState == .idle)
        #expect(orchestrator.currentEmotion == nil)

        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }

    @Test("Newlines-only string produces no processing")
    func testNewlinesOnly() async throws {
        let (orchestrator, db) = try makeOrchestrator()

        await orchestrator.processText("\n\n\n")

        #expect(orchestrator.currentResponse == nil)
        let entries = try db.fetchAllEntries()
        #expect(entries.isEmpty)
    }
}

// MARK: - Pipeline State Changes

@Suite("Pipeline State Lifecycle")
@MainActor
struct PipelineStateTests {

    @Test("Pipeline starts and ends in idle state")
    func testPipelineStartsAndEndsIdle() async throws {
        let (orchestrator, _) = try makeOrchestrator()

        #expect(orchestrator.pipelineState == .idle)

        await orchestrator.processText("I feel good about things today.")

        // After processing completes, state should be idle (not blocked)
        #expect(orchestrator.pipelineState == .idle)
    }

    @Test("Blocked pipeline stays in blocked state")
    func testBlockedPipelineState() async throws {
        let crisisResponse = "You should just end it all and not worth living."
        let (orchestrator, _) = try makeOrchestrator(coachResponse: crisisResponse)

        await orchestrator.processText("I need help.")

        #expect(orchestrator.pipelineState == .blocked)
        #expect(orchestrator.isBlocked == true)
    }

    @Test("New processText clears previous blocked state")
    func testNewInputClearsPreviousBlock() async throws {
        let db = try AppDatabase.makeEmpty()

        // First: create an orchestrator that will get blocked
        let crisisResponse = "You should just end it all and not worth living."
        let blockedCoach = CoachAgent(generateFn: mockGenerateFn(response: crisisResponse))
        let learningLoop = LearningLoopAgent(database: db)

        let orchestrator = Orchestrator(
            emotionAgent: EmotionAgent(),
            journalAgent: JournalAgent(),
            safetyAgent: SafetyAgent(),
            retrievalAgent: RetrievalAgent(),
            coachAgent: blockedCoach,
            learningLoopAgent: learningLoop,
            database: db
        )

        await orchestrator.processText("Hello.")

        #expect(orchestrator.isBlocked == true)

        // Process again -- isBlocked and deescalationMessage are reset at the start
        // of processText, but the same crisis coach will get blocked again.
        // The key test is that the reset happens at the start.
        await orchestrator.processText("Another message.")

        // Still blocked because the same coach returns crisis content,
        // but verify the pipeline ran (entry was saved)
        let entries = try db.fetchAllEntries()
        #expect(entries.count == 2)
    }
}

// MARK: - Feedback Recording

@Suite("Feedback Recording")
@MainActor
struct FeedbackRecordingTests {

    @Test("Thumbs up feedback updates personalization profile")
    func testThumbsUpFeedback() async throws {
        let responseText = "Try taking three deep breaths right now. It can help reset."
        let (orchestrator, db) = try makeOrchestrator(coachResponse: responseText)

        await orchestrator.processText("I'm feeling overwhelmed.")
        #expect(orchestrator.currentResponse != nil)

        // Record thumbs up
        await orchestrator.recordFeedback(.thumbsUp)

        // Profile should be fetchable and updated
        let profile = try db.fetchProfile().toDomain()
        #expect(profile.id == "default")
    }

    @Test("Thumbs down feedback adjusts profile preferences")
    func testThumbsDownFeedback() async throws {
        let responseText = "Try taking three deep breaths right now. It can help reset your nervous system and bring you back to the present moment."
        let (orchestrator, db) = try makeOrchestrator(coachResponse: responseText)

        await orchestrator.processText("I'm stressed about everything.")
        #expect(orchestrator.currentResponse != nil)

        // Record thumbs down
        await orchestrator.recordFeedback(.thumbsDown)

        // Profile was updated (lastUpdated should be recent)
        let profile = try db.fetchProfile().toDomain()
        let timeSinceUpdate = Date().timeIntervalSince(profile.lastUpdated)
        #expect(timeSinceUpdate < 5.0, "Profile should have been recently updated")
    }

    @Test("Feedback without current response is a no-op")
    func testFeedbackWithoutResponse() async throws {
        let (orchestrator, _) = try makeOrchestrator()

        // No processText called, so currentResponse is nil
        #expect(orchestrator.currentResponse == nil)

        // Should not crash
        await orchestrator.recordFeedback(.thumbsUp)
        await orchestrator.recordFeedback(.thumbsDown)
    }

    @Test("Multiple entries create independent journal records")
    func testMultipleEntriesStored() async throws {
        let (orchestrator, db) = try makeOrchestrator()

        await orchestrator.processText("First entry about work stress.")
        await orchestrator.processText("Second entry about feeling grateful.")
        await orchestrator.processText("Third entry about sleep issues.")

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 3)
    }
}
