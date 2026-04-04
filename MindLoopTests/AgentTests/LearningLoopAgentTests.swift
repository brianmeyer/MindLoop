//
//  LearningLoopAgentTests.swift
//  MindLoopTests
//
//  Tests for LearningLoopAgent: feedback processing, profile updates,
//  and preference tracking with per-test in-memory database.
//

import Testing
import Foundation
@testable import MindLoop

struct LearningLoopAgentTests {

    // MARK: - Helpers

    /// Creates an in-memory AppDatabase and LearningLoopAgent for each test.
    private func makeAgent() throws -> LearningLoopAgent {
        let db = try AppDatabase.makeEmpty()
        return LearningLoopAgent(database: db)
    }

    /// Creates a sample CoachResponse with configurable token count and action.
    private func makeResponse(
        tokenCount: Int = 95,
        suggestedAction: String? = "Take 3 deep breaths.",
        nextState: CBTState = .reframe
    ) -> CoachResponse {
        CoachResponse(
            id: UUID().uuidString,
            text: String(repeating: "word ", count: max(1, tokenCount / 2)),
            timestamp: Date(),
            citedEntries: [],
            suggestedAction: suggestedAction,
            nextState: nextState,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: tokenCount,
                latencyMs: 1200,
                model: "gemma-4-e2b-it-4bit",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: 2,
                    cardId: nil
                )
            )
        )
    }

    // MARK: - AgentProtocol Conformance

    @Test func agentHasCorrectName() throws {
        let agent = try makeAgent()
        #expect(agent.name == "LearningLoopAgent")
    }

    @Test func processReturnsUpdatedProfile() async throws {
        let agent = try makeAgent()
        let response = makeResponse()

        let profile = try await agent.process((response: response, feedback: .thumbsUp))

        #expect(profile.id == "default")
    }

    // MARK: - Thumbs Up Feedback

    @Test func thumbsUpReinforcesActionPreference() async throws {
        let agent = try makeAgent()
        let response = makeResponse(suggestedAction: "Try a mindfulness meditation for 5 minutes.")

        let profile = try await agent.process((response: response, feedback: .thumbsUp))

        #expect(profile.preferredActions.contains(.mindfulness))
    }

    @Test func thumbsUpWithBreathingAction() async throws {
        let agent = try makeAgent()
        let response = makeResponse(suggestedAction: "Take 3 deep breaths and notice how your body feels.")

        let profile = try await agent.process((response: response, feedback: .thumbsUp))

        #expect(profile.preferredActions.contains(.breathing))
    }

    @Test func thumbsUpDoesNotDuplicateExistingAction() async throws {
        let agent = try makeAgent()
        // Default profile already has .breathing
        let response = makeResponse(suggestedAction: "Practice breathing exercises.")

        let profile = try await agent.process((response: response, feedback: .thumbsUp))

        let breathingCount = profile.preferredActions.filter { $0 == .breathing }.count
        #expect(breathingCount == 1)
    }

    @Test func thumbsUpWithNoActionDoesNotCrash() async throws {
        let agent = try makeAgent()
        let response = makeResponse(suggestedAction: nil)

        let profile = try await agent.process((response: response, feedback: .thumbsUp))

        #expect(profile.id == "default")
    }

    // MARK: - Thumbs Down Feedback

    @Test func thumbsDownOnLongResponseShortensLength() async throws {
        let agent = try makeAgent()
        // Default is .medium; tokenCount > 100 should shorten
        let response = makeResponse(tokenCount: 130)

        let profile = try await agent.process((response: response, feedback: .thumbsDown))

        #expect(profile.responseLength == .short)
    }

    @Test func thumbsDownOnShortResponseLengthensLength() async throws {
        let agent = try makeAgent()
        // tokenCount < 60 should lengthen
        let response = makeResponse(tokenCount: 50)

        let profile = try await agent.process((response: response, feedback: .thumbsDown))

        #expect(profile.responseLength == .long)
    }

    @Test func thumbsDownRemovesSuggestedAction() async throws {
        let agent = try makeAgent()
        // Default profile has .breathing; suggest breathing, then thumbs down
        let response = makeResponse(
            tokenCount: 80,
            suggestedAction: "Take 3 deep breaths."
        )

        let profile = try await agent.process((response: response, feedback: .thumbsDown))

        #expect(!profile.preferredActions.contains(.breathing))
    }

    @Test func thumbsDownOnMediumTokenCountNoLengthChange() async throws {
        let agent = try makeAgent()
        // tokenCount between 60 and 100 should not change length
        let response = makeResponse(tokenCount: 80)

        let profile = try await agent.process((response: response, feedback: .thumbsDown))

        #expect(profile.responseLength == .medium)
    }

    // MARK: - Edit Feedback

    @Test func editWithShorterTextShortensLength() async throws {
        let agent = try makeAgent()
        let response = makeResponse(tokenCount: 95)
        // Original has ~47 words; edit with many fewer words
        let shortEdit = "Be direct. Short answer."

        let profile = try await agent.process((response: response, feedback: .edit(shortEdit)))

        #expect(profile.responseLength == .short)
    }

    @Test func editWithDirectToneShiftsToDirect() async throws {
        let agent = try makeAgent()
        let response = makeResponse(tokenCount: 95)
        // Very short sentences -> direct tone
        let directEdit = "Stop. Think. Act. Now."

        let profile = try await agent.process((response: response, feedback: .edit(directEdit)))

        #expect(profile.tonePref == .direct)
    }

    // MARK: - Profile Persistence

    @Test func profilePersistsAcrossProcessCalls() async throws {
        let agent = try makeAgent()

        // First: thumbs down on long response -> shorten to short
        let response1 = makeResponse(tokenCount: 130)
        _ = try await agent.process((response: response1, feedback: .thumbsDown))

        // Second: thumbs up with mindfulness -> profile should still be short + have mindfulness
        let response2 = makeResponse(suggestedAction: "Practice being present and mindful.")
        let profile = try await agent.process((response: response2, feedback: .thumbsUp))

        #expect(profile.responseLength == .short)
        #expect(profile.preferredActions.contains(.mindfulness))
    }

    @Test func profileSummaryReturnsString() throws {
        let agent = try makeAgent()
        let summary = try agent.profileSummary()

        #expect(summary.contains("Tone:"))
        #expect(summary.contains("Response length:"))
    }

    @Test func currentProfileReturnsDefault() throws {
        let agent = try makeAgent()
        let profile = try agent.currentProfile()

        #expect(profile.id == "default")
        #expect(profile.tonePref == .warm)
        #expect(profile.responseLength == .medium)
    }

    // MARK: - Action Inference

    @Test func inferActionFromBreathingText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Take 3 deep breaths") == .breathing)
    }

    @Test func inferActionFromJournalingText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Write down your thoughts") == .journaling)
    }

    @Test func inferActionFromReframingText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Try reframing that thought") == .reframing)
    }

    @Test func inferActionFromMindfulnessText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Practice a mindfulness exercise") == .mindfulness)
    }

    @Test func inferActionFromBehavioralActivationText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Take a small step toward your goal") == .behavioralActivation)
    }

    @Test func inferActionFromEvidenceTestingText() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Look for evidence that supports or contradicts") == .evidenceTesting)
    }

    @Test func inferActionReturnsNilForUnknown() throws {
        let agent = try makeAgent()
        #expect(agent.inferAction(from: "Have a nice day") == nil)
    }

    // MARK: - Record Conversion

    @Test func profileRecordRoundTrips() {
        let profile = PersonalizationProfile(
            id: "test",
            lastUpdated: Date(),
            tonePref: .direct,
            responseLength: .short,
            emotionTriggers: ["work_stress", "sleep"],
            avoidTopics: ["family"],
            preferredActions: [.reframing, .mindfulness]
        )

        let record = PersonalizationProfileRecord.from(profile)
        let roundTripped = record.toDomain()

        #expect(roundTripped.id == profile.id)
        #expect(roundTripped.tonePref == profile.tonePref)
        #expect(roundTripped.responseLength == profile.responseLength)
        #expect(roundTripped.emotionTriggers == profile.emotionTriggers)
        #expect(roundTripped.avoidTopics == profile.avoidTopics)
        #expect(roundTripped.preferredActions == profile.preferredActions)
    }

    // MARK: - Sendable Conformance

    @Test func agentIsSendable() throws {
        let agent = try makeAgent()
        // Verify agent can be sent across concurrency boundaries
        let _: any Sendable = agent
        #expect(agent.name == "LearningLoopAgent")
    }
}
