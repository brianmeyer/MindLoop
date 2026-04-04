//
//  CoachAgentTests.swift
//  MindLoopTests
//
//  Tests for CoachAgent: prompt construction, response parsing,
//  CBT state transitions, and streaming. Uses mock responses
//  (no actual model loading required).
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
            // Yield word by word to simulate streaming
            let words = response.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                let token = index == 0 ? word : " " + word
                continuation.yield(token)
            }
            continuation.finish()
        }
    }
}

/// Creates a standard test input with sensible defaults.
private func makeTestInput(
    entryText: String = "I'm feeling stressed about the presentation tomorrow.",
    emotionLabel: EmotionSignal.Label = .anxious,
    state: CBTState = .thoughts,
    profile: PersonalizationProfile = .default,
    context: RetrievalContext = .empty
) -> CoachAgent.Input {
    let entry = JournalEntry(
        id: "test-entry-1",
        timestamp: Date(),
        text: entryText,
        emotion: EmotionSignal(
            label: emotionLabel,
            confidence: 0.8,
            valence: -0.4,
            arousal: 0.6
        ),
        tags: ["work", "stress"]
    )

    let emotion = EmotionSignal(
        label: emotionLabel,
        confidence: 0.8,
        valence: -0.4,
        arousal: 0.6
    )

    return CoachAgent.Input(
        entry: entry,
        emotion: emotion,
        context: context,
        profile: profile,
        currentState: state
    )
}

/// Creates a RetrievalContext with sample entries for testing.
private func makeTestContext() -> RetrievalContext {
    let chunk = SemanticChunk(
        parentEntryId: "past-entry-1",
        chunkIndex: 0,
        text: "I was worried about the meeting but it went well in the end",
        startTime: 0,
        endTime: 30,
        dominantEmotion: .anxious,
        emotionConfidence: 0.75,
        valence: -0.3,
        arousal: 0.5,
        tokenCount: 15
    )

    let pastEntry = JournalEntry(
        id: "past-entry-1",
        timestamp: Date().addingTimeInterval(-86400),
        text: "I was worried about the meeting but it went well in the end",
        emotion: EmotionSignal(
            label: .anxious,
            confidence: 0.75,
            valence: -0.3,
            arousal: 0.5
        ),
        tags: ["work", "meetings"]
    )

    let scored = RetrievalContext.ScoredEntry(
        entry: pastEntry,
        bestChunk: chunk,
        similarity: 0.82
    )

    return RetrievalContext(
        entries: [scored],
        cbtCard: CBTCard.sampleReframing
    )
}

// MARK: - Prompt Construction Tests

@Suite("Prompt Construction")
struct PromptConstructionTests {

    @Test("Fills ENTRY placeholder with journal text")
    func testEntryPlaceholder() {
        let agent = CoachAgent()
        let input = makeTestInput(entryText: "I had a rough day at work today")
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("I had a rough day at work today"))
        #expect(!prompt.contains("{ENTRY}"))
    }

    @Test("Fills EMOTION placeholder with label and confidence")
    func testEmotionPlaceholder() {
        let agent = CoachAgent()
        let input = makeTestInput(emotionLabel: .anxious)
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("Anxious"))
        #expect(prompt.contains("80%"))
        #expect(!prompt.contains("{EMOTION}"))
    }

    @Test("Fills STATE placeholder with current CBT state")
    func testStatePlaceholder() {
        let agent = CoachAgent()
        let input = makeTestInput(state: .reframe)
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("Reframe"))
        #expect(prompt.contains("another way to look at this"))
        #expect(!prompt.contains("{STATE}"))
    }

    @Test("Fills PERSONALIZATION placeholder with profile instructions")
    func testPersonalizationPlaceholder() {
        let agent = CoachAgent()
        let profile = PersonalizationProfile(
            tonePref: .direct,
            responseLength: .short,
            preferredActions: [.breathing, .reframing]
        )
        let input = makeTestInput(profile: profile)
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("Clear and straightforward"))
        #expect(prompt.contains("Short"))
        #expect(prompt.contains("Breathing Exercises"))
        #expect(!prompt.contains("{PERSONALIZATION}"))
    }

    @Test("Fills CONTEXT placeholder with retrieval context")
    func testContextPlaceholder() {
        let agent = CoachAgent()
        let context = makeTestContext()
        let input = makeTestInput(context: context)
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("Memory 1"))
        #expect(prompt.contains("worried about the meeting"))
        #expect(prompt.contains("Cognitive Reframing"))
        #expect(!prompt.contains("{CONTEXT}"))
    }

    @Test("Empty context shows 'No relevant past memories' message")
    func testEmptyContext() {
        let agent = CoachAgent()
        let input = makeTestInput(context: .empty)
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("No relevant past memories found"))
    }

    @Test("All five placeholders are filled")
    func testAllPlaceholdersFilled() {
        let agent = CoachAgent()
        let input = makeTestInput()
        let prompt = agent.buildPrompt(input: input)

        #expect(!prompt.contains("{ENTRY}"))
        #expect(!prompt.contains("{EMOTION}"))
        #expect(!prompt.contains("{STATE}"))
        #expect(!prompt.contains("{PERSONALIZATION}"))
        #expect(!prompt.contains("{CONTEXT}"))
    }

    @Test("Prompt contains CBT micro-flow guidance")
    func testCBTGuidance() {
        let agent = CoachAgent()
        let input = makeTestInput()
        let prompt = agent.buildPrompt(input: input)

        #expect(prompt.contains("CBT"))
        #expect(prompt.contains("warm"))
        #expect(prompt.contains("non-clinical"))
        #expect(prompt.contains("tiny action"))
    }
}

// MARK: - Response Parsing Tests

@Suite("Response Parsing")
struct ResponseParsingTests {

    @Test("Builds CoachResponse with correct text")
    func testResponseText() {
        let agent = CoachAgent()
        let input = makeTestInput()
        let response = agent.buildCoachResponse(
            text: "I hear you. Let's look at this from another angle.",
            input: input,
            latencyMs: 1500
        )

        #expect(response.text == "I hear you. Let's look at this from another angle.")
    }

    @Test("Response includes correct metadata")
    func testResponseMetadata() {
        let agent = CoachAgent()
        let context = makeTestContext()
        let input = makeTestInput(context: context)
        let response = agent.buildCoachResponse(
            text: "Some response text here.",
            input: input,
            latencyMs: 1200
        )

        #expect(response.metadata.latencyMs == 1200)
        #expect(response.metadata.model == "gemma-4-e2b-it-4bit")
        #expect(response.metadata.retrievalContext.entryCount == 1)
        #expect(response.metadata.retrievalContext.cardId == "card_reframing")
    }

    @Test("Extracts action from response with action verb")
    func testExtractAction() {
        let agent = CoachAgent()
        let text = "That sounds tough. Try taking three deep breaths right now. It can help reset."
        let action = agent.extractAction(from: text)

        #expect(action != nil)
        #expect(action?.lowercased().contains("try") == true || action?.lowercased().contains("taking") == true)
    }

    @Test("Extracts action from 'tiny step' phrasing")
    func testExtractTinyStepAction() {
        let agent = CoachAgent()
        let text = "You're doing well. A tiny step would be to write down one positive thing about your day."
        let action = agent.extractAction(from: text)

        #expect(action != nil)
        #expect(action?.contains("tiny step") == true)
    }

    @Test("Returns nil action when no action found")
    func testNoAction() {
        let agent = CoachAgent()
        let text = "I understand how you feel. That must be really hard."
        let action = agent.extractAction(from: text)

        #expect(action == nil)
    }

    @Test("Estimates token count roughly")
    func testTokenEstimate() {
        let agent = CoachAgent()
        // 10 words, expect roughly 13 tokens (10 * 1.33)
        let text = "This is a test sentence with exactly ten words here"
        let estimate = agent.estimateTokenCount(text)

        #expect(estimate >= 10)
        #expect(estimate <= 20)
    }

    @Test("Detects citations from temporal indicators")
    func testCitationsFromTemporalIndicators() {
        let agent = CoachAgent()
        let context = makeTestContext()
        let text = "Last time you mentioned feeling worried, and things worked out. Let's remember that."
        let citations = agent.extractCitations(from: text, context: context)

        #expect(!citations.isEmpty)
        #expect(citations.contains("past-entry-1"))
    }

    @Test("Returns empty citations for empty context")
    func testNoCitationsForEmptyContext() {
        let agent = CoachAgent()
        let text = "I hear you. Let's work through this together."
        let citations = agent.extractCitations(from: text, context: .empty)

        #expect(citations.isEmpty)
    }
}

// MARK: - CBT State Transition Tests

@Suite("CBT State Transitions")
struct CBTStateTransitionTests {

    let agent = CoachAgent()
    let defaultProfile = PersonalizationProfile.default

    @Test("Default transition: goal -> situation")
    func testGoalToSituation() {
        let next = agent.determineNextState(
            currentState: .goal,
            responseText: "Tell me about the situation.",
            profile: defaultProfile
        )
        #expect(next == .situation)
    }

    @Test("Default transition: situation -> thoughts")
    func testSituationToThoughts() {
        let next = agent.determineNextState(
            currentState: .situation,
            responseText: "What thoughts come to mind?",
            profile: defaultProfile
        )
        #expect(next == .thoughts)
    }

    @Test("Default transition: thoughts -> feelings")
    func testThoughtsToFeelings() {
        let next = agent.determineNextState(
            currentState: .thoughts,
            responseText: "How does that make you feel?",
            profile: defaultProfile
        )
        #expect(next == .feelings)
    }

    @Test("Default transition: feelings -> distortions")
    func testFeelingsToDistortions() {
        let next = agent.determineNextState(
            currentState: .feelings,
            responseText: "Let's examine if there are patterns here.",
            profile: defaultProfile
        )
        #expect(next == .distortions)
    }

    @Test("Default transition: distortions -> reframe")
    func testDistortionsToReframe() {
        let next = agent.determineNextState(
            currentState: .distortions,
            responseText: "Let's try to see this differently.",
            profile: defaultProfile
        )
        #expect(next == .reframe)
    }

    @Test("Default transition: reframe -> action")
    func testReframeToAction() {
        let next = agent.determineNextState(
            currentState: .reframe,
            responseText: "Great reframe! Here's a tiny step you can take.",
            profile: defaultProfile
        )
        #expect(next == .action)
    }

    @Test("Default transition: action -> reflect")
    func testActionToReflect() {
        let next = agent.determineNextState(
            currentState: .action,
            responseText: "Now take a moment to reflect on how that feels.",
            profile: defaultProfile
        )
        #expect(next == .reflect)
    }

    @Test("Default transition: reflect -> goal (cycle)")
    func testReflectToGoal() {
        let next = agent.determineNextState(
            currentState: .reflect,
            responseText: "Great work today. What would you like to focus on next?",
            profile: defaultProfile
        )
        #expect(next == .goal)
    }

    @Test("Stay in reframe when response suggests continued exploration")
    func testLingerInReframe() {
        let next = agent.determineNextState(
            currentState: .reframe,
            responseText: "That's one way to see it. Can you think of another way to view this?",
            profile: defaultProfile
        )
        #expect(next == .reframe)
    }

    @Test("Stay in thoughts when response elicits more thoughts")
    func testLingerInThoughts() {
        let next = agent.determineNextState(
            currentState: .thoughts,
            responseText: "Interesting. Tell me more about what comes to mind.",
            profile: defaultProfile
        )
        #expect(next == .thoughts)
    }

    @Test("Stay in feelings when response elicits more feelings")
    func testLingerInFeelings() {
        let next = agent.determineNextState(
            currentState: .feelings,
            responseText: "I see. What else are you feeling right now?",
            profile: defaultProfile
        )
        #expect(next == .feelings)
    }

    @Test("Full CBT flow cycles through all states")
    func testFullCBTCycle() {
        let states: [CBTState] = [
            .goal, .situation, .thoughts, .feelings,
            .distortions, .reframe, .action, .reflect,
        ]

        for i in 0..<states.count {
            let current = states[i]
            let expectedNext = states[(i + 1) % states.count]
            let next = agent.determineNextState(
                currentState: current,
                responseText: "Simple response.",
                profile: defaultProfile
            )
            #expect(next == expectedNext, "Expected \(current) -> \(expectedNext), got \(next)")
        }
    }
}

// MARK: - Streaming Tests

@Suite("Streaming")
struct StreamingTests {

    @Test("streamResponse yields tokens")
    func testStreamYieldsTokens() async {
        let mockResponse = "I hear you. Let's take a breath and look at this together."
        let agent = CoachAgent(generateFn: mockGenerateFn(response: mockResponse))
        let input = makeTestInput()

        var tokens: [String] = []
        for await token in agent.streamResponse(input: input) {
            tokens.append(token)
        }

        let fullText = tokens.joined()
        #expect(fullText == mockResponse)
        #expect(tokens.count > 1) // Multiple tokens streamed
    }

    @Test("streamResponse returns empty stream when no generateFn")
    func testStreamEmptyWithoutRuntime() async {
        let agent = CoachAgent(generateFn: nil)
        let input = makeTestInput()

        var count = 0
        for await _ in agent.streamResponse(input: input) {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("process returns CoachResponse from mock")
    func testProcessReturnsResponse() async throws {
        let mockResponse = "That sounds challenging. Try writing down three things you did well today."
        let agent = CoachAgent(generateFn: mockGenerateFn(response: mockResponse))
        let input = makeTestInput()

        let response = try await agent.process(input)

        #expect(response.text == mockResponse)
        #expect(response.nextState == .feelings) // thoughts -> feelings by default
        #expect(response.metadata.model == "gemma-4-e2b-it-4bit")
    }

    @Test("process throws when generateFn is nil")
    func testProcessThrowsWithoutRuntime() async {
        let agent = CoachAgent(generateFn: nil)
        let input = makeTestInput()

        await #expect(throws: AgentError.self) {
            try await agent.process(input)
        }
    }
}

// MARK: - Agent Properties Tests

@Suite("Agent Properties")
struct AgentPropertyTests {

    @Test("Name is CoachAgent")
    func testName() {
        let agent = CoachAgent()
        #expect(agent.name == "CoachAgent")
    }

    @Test("Agent conforms to Sendable")
    func testSendable() {
        let agent = CoachAgent()
        // If this compiles, the agent is Sendable
        let _: any Sendable = agent
        #expect(agent.name == "CoachAgent")
    }
}
