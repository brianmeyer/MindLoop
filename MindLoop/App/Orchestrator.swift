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

            // 7. Generate coach response
            pipelineState = .responding
            let coachInput = CoachAgent.Input(
                entry: entry,
                emotion: emotion,
                context: context,
                profile: profile,
                currentState: cbtState
            )
            let response = try await coachAgent.process(coachInput)

            // 8. Safety gate
            let gateResult = safetyAgent.gate(response.text)

            if gateResult.isBlocked {
                pipelineState = .blocked
                isBlocked = true
                deescalationMessage = SafetyAgent.deescalationResponse
                currentResponse = nil
            } else {
                currentResponse = response
                streamingText = response.text
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
            Self.logger.error("Pipeline failed: \(errorCode, privacy: .public) — \(error.localizedDescription, privacy: .private)")
            errorMessage = "Something went wrong. [\(errorCode)]"
        }

        if pipelineState != .blocked {
            pipelineState = .idle
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
