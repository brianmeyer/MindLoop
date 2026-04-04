//
//  AgentProtocol.swift
//  MindLoop
//
//  Base protocol and shared types for all MindLoop agents.
//  All agents are stateless — state lives in the Orchestrator.
//  Source: CLAUDE.md Agent Contracts section
//

import Foundation

// MARK: - AgentProtocol

/// Base protocol that every MindLoop agent adopts.
///
/// Agents are stateless, single-purpose processing units coordinated by the
/// Orchestrator. Each concrete agent defines its own `Input` and `Output`
/// associated types so the protocol remains generic while individual agents
/// have strongly-typed contracts.
protocol AgentProtocol: Sendable {
    /// The input this agent accepts (e.g., raw text, candidate response, embedding query).
    associatedtype Input: Sendable
    /// The output this agent produces (e.g., JournalEntry, SafetyGateResult, [Float]).
    associatedtype Output: Sendable

    /// Human-readable name used for logging and debugging.
    var name: String { get }

    /// Process input and produce output asynchronously.
    ///
    /// All agent work is async so it can run off the main thread.
    /// Agents must never block the main actor.
    func process(_ input: Input) async throws -> Output
}

// MARK: - CBTState

/// CBT micro-flow state machine used by the Orchestrator to guide conversations.
///
/// Flow: goal -> situation -> thoughts -> feelings -> distortions -> reframe -> action -> reflect
enum CBTState: String, Codable, CaseIterable, Sendable, Hashable {
    case goal
    case situation
    case thoughts
    case feelings
    case distortions
    case reframe
    case action
    case reflect

    /// Human-readable display name for the UI.
    var displayName: String {
        switch self {
        case .goal:        return "Goal Setting"
        case .situation:   return "Situation"
        case .thoughts:    return "Thoughts"
        case .feelings:    return "Feelings"
        case .distortions: return "Distortions"
        case .reframe:     return "Reframe"
        case .action:      return "Action"
        case .reflect:     return "Reflect"
        }
    }

    /// Prompt guide shown to the user for each state.
    var promptGuide: String {
        switch self {
        case .goal:        return "What would you like to work on today?"
        case .situation:   return "Tell me more about the situation..."
        case .thoughts:    return "What thoughts came up?"
        case .feelings:    return "How did that make you feel?"
        case .distortions: return "Let's examine if there are other ways to see this..."
        case .reframe:     return "What's another way to look at this?"
        case .action:      return "What's one tiny step you could take?"
        case .reflect:     return "How does that feel now?"
        }
    }

    /// The default next state in the CBT micro-flow.
    ///
    /// After `.reflect`, the flow cycles back to `.goal` for a new session turn.
    /// The Orchestrator may override this based on CoachAgent hints or
    /// LearningLoopAgent personalization (e.g., lingering in `.reframe`).
    var nextState: CBTState {
        switch self {
        case .goal:        return .situation
        case .situation:   return .thoughts
        case .thoughts:    return .feelings
        case .feelings:    return .distortions
        case .distortions: return .reframe
        case .reframe:     return .action
        case .action:      return .reflect
        case .reflect:     return .goal
        }
    }

    /// Zero-based position in the flow (0 = goal, 7 = reflect).
    var stepIndex: Int {
        switch self {
        case .goal:        return 0
        case .situation:   return 1
        case .thoughts:    return 2
        case .feelings:    return 3
        case .distortions: return 4
        case .reframe:     return 5
        case .action:      return 6
        case .reflect:     return 7
        }
    }

    /// Total number of steps in the CBT micro-flow.
    static let totalSteps = 8

    /// Progress through the flow as a fraction (0.0 ... 1.0).
    var progress: Double {
        Double(stepIndex) / Double(Self.totalSteps - 1)
    }
}

// MARK: - SafetyGateResult

/// Result of the SafetyAgent's gate check on a candidate response.
enum SafetyGateResult: Sendable, Equatable {
    /// The response is safe to show to the user.
    case allow
    /// The response was blocked. `reason` describes why (e.g., "suicide_keyword").
    case block(reason: String)

    /// Whether the response was allowed.
    var isAllowed: Bool {
        if case .allow = self { return true }
        return false
    }

    /// Whether the response was blocked.
    var isBlocked: Bool {
        !isAllowed
    }

    /// The block reason, or nil if allowed.
    var blockReason: String? {
        if case .block(let reason) = self { return reason }
        return nil
    }
}

// MARK: - RetrievalContext

/// Context retrieved from past journal entries for grounding the CoachAgent response.
///
/// Contains the top-k relevant entries (aggregated from chunk-level search),
/// each paired with its best matching chunk for UI highlighting, plus an
/// optional CBT technique card.
struct RetrievalContext: Sendable, Equatable {
    /// A single retrieved memory with its best matching chunk and similarity score.
    struct ScoredEntry: Sendable, Equatable {
        /// The parent journal entry.
        let entry: JournalEntry
        /// The most relevant chunk within this entry (for highlighting / audio jump).
        let bestChunk: SemanticChunk
        /// Cosine similarity score (0.0 ... 1.0) of the best chunk to the query.
        let similarity: Float
    }

    /// Top retrieved entries, sorted by descending similarity.
    /// Typically 5 entries (aggregated from top-10 chunk search).
    let entries: [ScoredEntry]

    /// An optional CBT technique card selected to complement the current state.
    let cbtCard: CBTCard?

    /// Creates an empty retrieval context (no memories, no card).
    static let empty = RetrievalContext(entries: [], cbtCard: nil)

    /// Number of retrieved entries.
    var count: Int { entries.count }

    /// Whether any context was retrieved.
    var isEmpty: Bool { entries.isEmpty && cbtCard == nil }

    /// IDs of all retrieved parent entries (for citation in CoachResponse).
    var citedEntryIds: [String] {
        entries.map(\.entry.id)
    }

    /// Formatted context string for injection into the coach prompt's {CONTEXT} placeholder.
    var promptRepresentation: String {
        var parts: [String] = []

        for (index, scored) in entries.enumerated() {
            let label = scored.entry.emotion.label.displayName
            let date = scored.entry.formattedDate
            parts.append(
                "Memory \(index + 1) [\(date), \(label)]: \(scored.bestChunk.text)"
            )
        }

        if let card = cbtCard {
            parts.append("CBT Technique: \(card.title) — \(card.technique)")
        }

        return parts.joined(separator: "\n\n")
    }
}

// MARK: - AgentError

/// Errors that agents may throw during processing.
enum AgentError: Error, Sendable, Equatable {
    /// The input provided to the agent was invalid or empty.
    case invalidInput(String)

    /// The underlying model failed to produce a result within the timeout.
    case timeout(agent: String, limitMs: Int)

    /// The model or service returned an unusable result.
    case processingFailed(agent: String, reason: String)

    /// The agent's required resource (model, keyword file, etc.) could not be loaded.
    case resourceUnavailable(String)

    /// A safety check blocked the operation (wraps the gate result reason).
    case safetyBlocked(reason: String)
}

extension AgentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .timeout(let agent, let limitMs):
            return "\(agent) timed out after \(limitMs)ms"
        case .processingFailed(let agent, let reason):
            return "\(agent) processing failed: \(reason)"
        case .resourceUnavailable(let resource):
            return "Resource unavailable: \(resource)"
        case .safetyBlocked(let reason):
            return "Blocked by safety gate: \(reason)"
        }
    }
}
