//
//  Orchestrator.swift
//  MindLoop
//
//  Central coordinator: CBT state machine + agent pipeline.
//  Routes user input through the agent chain and manages conversation flow.
//

import Foundation
import Observation
import os

// MARK: - Pipeline State

/// UI-facing state of the processing pipeline
enum PipelineState: String, Sendable {
    case idle
    case recording
    case analyzing
    case thinking
    case responding
    case blocked
}

// MARK: - Orchestrator

/// Coordinates the agent pipeline and CBT state machine.
@MainActor
@Observable
final class Orchestrator {

    // MARK: - Published State

    private(set) var cbtState: CBTState = .goal
    private(set) var pipelineState: PipelineState = .idle
    private(set) var currentResponse: CoachResponse?
    private(set) var isBlocked: Bool = false
    private(set) var deescalationMessage: String?
    private(set) var streamingText: String = ""
    private(set) var currentEmotion: EmotionSignal?
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.lycan.MindLoop",
        category: "Orchestrator"
    )

    private let emotionAgent: EmotionAgent
    private let journalAgent: JournalAgent
    private let safetyAgent: SafetyAgent
    private let retrievalAgent: RetrievalAgent
    private let coachAgent: CoachAgent
    private let learningLoopAgent: LearningLoopAgent
    private let database: AppDatabase

    // MARK: - Initialization

    init(
        emotionAgent: EmotionAgent = EmotionAgent(),
        journalAgent: JournalAgent = JournalAgent(),
        safetyAgent: SafetyAgent = SafetyAgent(),
        retrievalAgent: RetrievalAgent = RetrievalAgent(),
        coachAgent: CoachAgent = CoachAgent(generateFn: { prompt, maxTokens, temperature in
            AsyncStream { continuation in
                Task { @MainActor in
                    let stream = ModelRuntime.shared.generate(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature
                    )
                    for await token in stream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                }
            }
        }),
        learningLoopAgent: LearningLoopAgent = LearningLoopAgent(),
        database: AppDatabase = .shared
    ) {
        self.emotionAgent = emotionAgent
        self.journalAgent = journalAgent
        self.safetyAgent = safetyAgent
        self.retrievalAgent = retrievalAgent
        self.coachAgent = coachAgent
        self.learningLoopAgent = learningLoopAgent
        self.database = database
    }

    // MARK: - Main Pipeline

    /// Process text input through the full agent pipeline.
    /// Convenience overload that runs the pipeline without prosody features
    /// (e.g., when the user types the entry by hand instead of speaking).
    func processText(_ text: String) async {
        await processText(text, prosodyFeatures: [:])
    }

    /// Process text input with optional prosody features from voice recording.
    ///
    /// - Parameters:
    ///   - text: The journal entry text (transcript or typed).
    ///   - prosodyFeatures: Pitch/jitter/shimmer/speaking-rate/pause-duration
    ///     extracted via `NativeEmotionService`. Pass `[:]` for text-only input.
    ///     When present, `EmotionAgent` blends prosody with text sentiment per
    ///     the CLAUDE.md hybrid-emotion contract (0.6 text + 0.4 prosody). (REC-288)
    func processText(_ text: String, prosodyFeatures: [String: Double]) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isBlocked = false
        deescalationMessage = nil
        errorMessage = nil
        streamingText = ""

        do {
            // 1. Emotion analysis (text + prosody hybrid per CLAUDE.md)
            pipelineState = .analyzing
            let emotion = emotionAgent.analyze(text: trimmed, prosodyFeatures: prosodyFeatures)
            currentEmotion = emotion

            // 2. Normalize into JournalEntry
            let entry = journalAgent.normalize(text: trimmed, emotion: emotion)

            // 3. Save to database
            try database.saveEntry(JournalEntryRecord(from: entry))

            // 4. Background embedding — actor isolation handles concurrency
            await EmbeddingAgent.shared.enqueueBackground(entry: entry) { _ in }

            // 5. Retrieve context
            pipelineState = .thinking
            let context: RetrievalContext
            do {
                context = try await retrievalAgent.process(trimmed)
            } catch {
                context = .empty
            }

            // 6. Get personalization profile
            let profile = try database.fetchProfile().toDomain()

            // 7. Stream coach response tokens into streamingText with
            // timeout + retry per CLAUDE.md. UI reveals via typewriter.
            // (REC-316 token-by-token streaming; REC-306 timeout).
            pipelineState = .responding
            let coachInput = CoachAgent.Input(
                entry: entry,
                emotion: emotion,
                context: context,
                profile: profile,
                currentState: cbtState
            )
            let response: CoachResponse = try await streamCoachWithTimeout(input: coachInput)

            // 8. Safety gate (post-stream). If blocked, retract the
            // streamed text so the user no longer sees the unsafe
            // content and present de-escalation instead.
            let gateResult = safetyAgent.gate(response.text)

            if gateResult.isBlocked {
                streamingText = ""
                pipelineState = .blocked
                isBlocked = true
                deescalationMessage = SafetyAgent.deescalationResponse
                currentResponse = nil
            } else {
                currentResponse = response
                cbtState = response.nextState
                pipelineState = .idle
            }

        } catch {
            pipelineState = .idle
            // Log full error privately per CLAUDE.md.
            // Surface the error TYPE (not localized description) to the UI so
            // failures are diagnosable on-device without exposing user text.
            // Error type names (e.g. "processingFailed", "notLoaded") are
            // safe — they describe the class of failure, not user content.
            let errorCode = "\(String(describing: type(of: error))).\(String(describing: error).prefix(40))"
            // If the failure was an empty coach response, pull the inner
            // generation error from ModelRuntime so we can see WHY the LLM
            // produced nothing (load state, MLX throw, zero chunks, etc.).
            let genError = ModelRuntime.shared.lastGenerationError
            Self.logger.error("Pipeline failed: \(errorCode, privacy: .public) — \(error.localizedDescription, privacy: .private) — gen: \(genError ?? "nil", privacy: .public)")
            if let genError {
                errorMessage = "Something went wrong. [\(errorCode)] gen: \(genError)"
            } else {
                errorMessage = "Something went wrong. [\(errorCode)]"
            }
        }

        if pipelineState != .blocked {
            pipelineState = .idle
        }
    }

    // MARK: - Coach Streaming (REC-316) + Timeout (REC-306)

    /// Stream CoachAgent tokens into `streamingText` with a 60s overall
    /// timeout and 1x retry at 2s backoff, per CLAUDE.md failure/timeout
    /// policy. Returns the finalized `CoachResponse` built from the
    /// accumulated stream text.
    ///
    /// On iPhone, Gemma 4 E2B first-token latency is ~10–20s (3.3GB
    /// prompt processing) plus ~10s for 120 tokens at ~12 tok/s — so
    /// 60s covers typical ~30s generations with headroom for cold runs.
    private func streamCoachWithTimeout(input: CoachAgent.Input) async throws -> CoachResponse {
        streamingText = ""

        if let result = await withTimeout(seconds: 60.0, operation: {
            await self.accumulateStream(input: input)
        }), !result.text.isEmpty {
            return coachAgent.buildCoachResponse(
                text: result.text,
                input: input,
                latencyMs: result.latencyMs
            )
        }

        Self.logger.warning("Coach stream timed out or empty — retrying after 2s backoff")
        streamingText = ""
        try await Task.sleep(for: .seconds(2.0))

        if let retry = await withTimeout(seconds: 60.0, operation: {
            await self.accumulateStream(input: input)
        }), !retry.text.isEmpty {
            return coachAgent.buildCoachResponse(
                text: retry.text,
                input: input,
                latencyMs: retry.latencyMs
            )
        }

        Self.logger.error("Coach stream timed out or empty on retry")
        throw AgentError.processingFailed(
            agent: "CoachAgent",
            reason: "Model returned empty response"
        )
    }

    /// Consume the CoachAgent token stream, appending each token to
    /// `streamingText` for live typewriter reveal. Returns the trimmed
    /// full text plus the measured generation latency.
    private func accumulateStream(
        input: CoachAgent.Input
    ) async -> (text: String, latencyMs: Int) {
        let start = Date()
        var full = ""
        for await token in coachAgent.streamResponse(input: input) {
            full += token
            streamingText = full
        }
        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reflect the trimmed text back to the UI so downstream state
        // matches what buildCoachResponse will see.
        streamingText = trimmed
        return (trimmed, latencyMs)
    }

    /// Run an async operation with a timeout. Returns nil if the timeout
    /// fires before the operation completes.
    private func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async rethrows -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                return nil
            }
            // First result wins — either the operation or the timeout
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Feedback

    /// Record user feedback on the current response
    func recordFeedback(_ feedback: Feedback) async {
        guard let response = currentResponse else { return }
        do {
            _ = try await learningLoopAgent.process((response: response, feedback: feedback))
        } catch {
            Self.logger.error("Feedback failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pipeline Preparation

    /// Synchronously set the pipeline to `.analyzing` so CoachScreen
    /// shows the thinking indicator immediately, before the async
    /// `processText` work begins via `.task`.  (REC-283)
    func preparePipeline() {
        isBlocked = false
        deescalationMessage = nil
        errorMessage = nil
        streamingText = ""
        pipelineState = .analyzing
    }

    // MARK: - State Management

    func resetConversation() {
        cbtState = .goal
        pipelineState = .idle
        currentResponse = nil
        isBlocked = false
        deescalationMessage = nil
        streamingText = ""
        currentEmotion = nil
        errorMessage = nil
    }

    func setCBTState(_ state: CBTState) {
        cbtState = state
    }
}

// PersonalizationProfileRecord.toDomain() defined in LearningLoopAgent.swift
