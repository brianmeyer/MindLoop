//
//  CoachAgent.swift
//  MindLoop
//
//  Generates grounded, CBT-structured coaching responses using
//  Gemma 4 E2B-it via ModelRuntime. Adapts tone and pacing based
//  on PersonalizationProfile from LearningLoopAgent.
//  Source: CLAUDE.md - CoachAgent contract
//

import Foundation

// MARK: - CoachAgent

/// Generates grounded, CBT-structured coaching responses.
///
/// The CoachAgent takes a journal entry, emotion signal, retrieval context,
/// and personalization profile, then produces a warm, non-clinical response
/// that follows the CBT micro-flow. Responses are streamed token-by-token
/// for real-time UI updates.
///
/// - Model: Gemma 4 E2B-it (MLX 4-bit) via ``ModelRuntime``
/// - Constraint: ~80-120 tokens (enforced by Orchestrator post-processing)
struct CoachAgent: AgentProtocol, Sendable {

    // MARK: - Types

    /// Input for the CoachAgent combining all required context.
    struct Input: Sendable {
        let entry: JournalEntry
        let emotion: EmotionSignal
        let context: RetrievalContext
        let profile: PersonalizationProfile
        let currentState: CBTState
    }

    typealias Output = CoachResponse

    // MARK: - Properties

    var name: String { "CoachAgent" }

    /// The model runtime used for text generation.
    /// When nil, the agent uses ``buildPrompt`` only (useful for testing prompt construction).
    private let generateFn: (@Sendable (String, Int, Float) -> AsyncStream<String>)?

    // MARK: - Initialization

    /// Creates a CoachAgent with a custom generation function.
    ///
    /// - Parameter generateFn: A function that takes (prompt, maxTokens, temperature)
    ///   and returns an ``AsyncStream<String>`` of tokens. Pass nil for prompt-only testing.
    init(generateFn: (@Sendable (String, Int, Float) -> AsyncStream<String>)? = nil) {
        self.generateFn = generateFn
    }

    // MARK: - AgentProtocol

    /// Process input and produce a CoachResponse (non-streaming, for tests).
    func process(_ input: Input) async throws -> CoachResponse {
        let prompt = buildPrompt(input: input)

        guard let generate = generateFn else {
            throw AgentError.resourceUnavailable("ModelRuntime not available")
        }

        let startTime = Date()
        var fullText = ""

        for await token in generate(prompt, 120, 0.7) {
            fullText += token
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw AgentError.processingFailed(
                agent: name,
                reason: "Model returned empty response"
            )
        }

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        return buildCoachResponse(
            text: trimmed,
            input: input,
            latencyMs: latencyMs
        )
    }

    // MARK: - Streaming

    /// Stream response tokens for real-time UI updates.
    ///
    /// - Parameter input: The combined input context.
    /// - Returns: An ``AsyncStream<String>`` yielding tokens as they are generated.
    func streamResponse(input: Input) -> AsyncStream<String> {
        let prompt = buildPrompt(input: input)

        guard let generate = generateFn else {
            return AsyncStream { $0.finish() }
        }

        return generate(prompt, 120, 0.7)
    }

    // MARK: - Prompt Construction

    /// Build the full prompt with all placeholders filled.
    ///
    /// Visible internally for testing prompt construction.
    func buildPrompt(input: Input) -> String {
        let systemPrompt = Self.systemPromptTemplate
            .replacingOccurrences(of: "{ENTRY}", with: input.entry.text)
            .replacingOccurrences(of: "{EMOTION}", with: formatEmotion(input.emotion))
            .replacingOccurrences(of: "{CONTEXT}", with: formatContext(input.context))
            .replacingOccurrences(of: "{STATE}", with: formatState(input.currentState))
            .replacingOccurrences(of: "{PERSONALIZATION}", with: input.profile.promptInstructions)

        return systemPrompt
    }

    // MARK: - System Prompt Template

    /// The system prompt template with CBT micro-flow guidance.
    ///
    /// Placeholders: {ENTRY}, {EMOTION}, {CONTEXT}, {STATE}, {PERSONALIZATION}
    static let systemPromptTemplate: String = """
        You are a warm, supportive CBT coach in a journaling app. You guide users \
        through reflections using the CBT micro-flow: goal, situation, thoughts/feelings, \
        distortions, reframe, tiny action, reflect.

        RULES:
        - Be warm, concise, and non-clinical. No diagnoses or medical claims.
        - Respond in ~80-120 tokens.
        - Cite retrieved memories when relevant (e.g., "Last Tuesday you mentioned...").
        - Suggest one concrete tiny action per turn.
        - Follow the current CBT state guidance below.
        - Adapt your tone and pacing to the user's preferences.

        CURRENT CBT STATE: {STATE}

        USER'S JOURNAL ENTRY:
        {ENTRY}

        EMOTION SIGNAL:
        {EMOTION}

        RETRIEVED CONTEXT (past memories and CBT technique):
        {CONTEXT}

        PERSONALIZATION:
        {PERSONALIZATION}

        Respond as the coach. Stay in character. Be brief and actionable.
        """

    // MARK: - Response Building

    /// Parse generated text into a structured CoachResponse.
    func buildCoachResponse(
        text: String,
        input: Input,
        latencyMs: Int
    ) -> CoachResponse {
        let nextState = determineNextState(
            currentState: input.currentState,
            responseText: text,
            profile: input.profile
        )

        let suggestedAction = extractAction(from: text)
        let citedEntries = extractCitations(from: text, context: input.context)

        let tokenEstimate = estimateTokenCount(text)

        return CoachResponse(
            text: text,
            citedEntries: citedEntries,
            suggestedAction: suggestedAction,
            nextState: nextState,
            metadata: CoachResponse.ResponseMetadata(
                tokenCount: tokenEstimate,
                latencyMs: latencyMs,
                model: "gemma-4-e2b-it-4bit",
                loraAdapter: nil,
                retrievalContext: CoachResponse.ResponseMetadata.RetrievalContext(
                    entryCount: input.context.entries.count,
                    cardId: input.context.cbtCard?.id
                )
            )
        )
    }

    // MARK: - CBT State Transitions

    /// Determine the next CBT state based on current state, response, and profile.
    ///
    /// The default transition follows the CBT micro-flow sequence.
    /// PersonalizationProfile may cause the agent to linger in certain states
    /// (e.g., spending more time in reframe if the user struggles there).
    func determineNextState(
        currentState: CBTState,
        responseText: String,
        profile: PersonalizationProfile
    ) -> CBTState {
        let defaultNext = currentState.nextState

        // If the user has preferred reframing and we're in distortions,
        // the default flow already moves to reframe -- no override needed.

        // If response contains indicators that the user needs more time
        // in the current state, stay put.
        let lowerText = responseText.lowercased()

        // Stay in reframe state if the response suggests continued exploration
        if currentState == .reframe {
            let continueIndicators = [
                "let's explore", "another way", "what else",
                "can you think of", "consider also",
            ]
            if continueIndicators.contains(where: { lowerText.contains($0) }) {
                return .reframe
            }
        }

        // Stay in thoughts/feelings if response is still eliciting them
        if currentState == .thoughts || currentState == .feelings {
            let elicitIndicators = [
                "tell me more", "what else", "anything else",
                "go on", "keep going",
            ]
            if elicitIndicators.contains(where: { lowerText.contains($0) }) {
                return currentState
            }
        }

        return defaultNext
    }

    // MARK: - Helpers

    /// Format emotion signal for prompt injection.
    private func formatEmotion(_ emotion: EmotionSignal) -> String {
        let label = emotion.label.displayName
        let confidence = emotion.confidencePercentage
        let valence = String(format: "%.2f", emotion.valence)
        let arousal = String(format: "%.2f", emotion.arousal)
        return "\(label) (confidence: \(confidence)%, valence: \(valence), arousal: \(arousal))"
    }

    /// Format retrieval context for prompt injection.
    private func formatContext(_ context: RetrievalContext) -> String {
        if context.isEmpty {
            return "No relevant past memories found."
        }
        return context.promptRepresentation
    }

    /// Format current CBT state for prompt injection.
    private func formatState(_ state: CBTState) -> String {
        "\(state.displayName) - \(state.promptGuide)"
    }

    /// Extract a suggested action from the response text.
    ///
    /// Looks for common action-indicating phrases.
    func extractAction(from text: String) -> String? {
        let lower = text.lowercased()

        // Look for action-indicating phrases
        let actionPrefixes = [
            "try ", "take ", "spend ", "write ", "list ",
            "breathe ", "notice ", "set ", "start ",
        ]

        // Split into sentences and find one that starts with an action verb
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            let lowerSentence = sentence.lowercased()
            if actionPrefixes.contains(where: { lowerSentence.hasPrefix($0) }) {
                return sentence
            }
        }

        // Fallback: look for "tiny step" or "one thing" patterns
        if lower.contains("tiny step") || lower.contains("one thing") || lower.contains("small step") {
            // Return the sentence containing that phrase
            for sentence in sentences {
                let lowerSentence = sentence.lowercased()
                if lowerSentence.contains("tiny step") || lowerSentence.contains("one thing") || lowerSentence.contains("small step") {
                    return sentence
                }
            }
        }

        return nil
    }

    /// Extract cited entry IDs by checking if context entries are referenced.
    func extractCitations(from text: String, context: RetrievalContext) -> [String] {
        guard !context.isEmpty else { return [] }

        var cited: [String] = []
        let lower = text.lowercased()

        for scored in context.entries {
            // Check if the response references content from this entry
            let entryWords = scored.bestChunk.text.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 4 }

            // If several significant words from the chunk appear in the response, consider it cited
            let matchCount = entryWords.filter { lower.contains($0) }.count
            if matchCount >= 3 {
                cited.append(scored.entry.id)
            }
        }

        // Also detect temporal references like "last Tuesday", "previously"
        let temporalIndicators = ["last ", "previously", "you mentioned", "earlier", "before"]
        if temporalIndicators.contains(where: { lower.contains($0) }) && !context.entries.isEmpty {
            // Add the first entry as a citation if not already included
            let firstId = context.entries[0].entry.id
            if !cited.contains(firstId) {
                cited.append(firstId)
            }
        }

        return cited
    }

    /// Rough token count estimate (~0.75 tokens per word).
    func estimateTokenCount(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return Int(Double(words) * 1.33)
    }
}
