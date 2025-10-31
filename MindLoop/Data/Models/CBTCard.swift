//
//  CBTCard.swift
//  MindLoop
//
//  Represents a reusable CBT technique card from the static library
//  Source: CLAUDE.md - Resources/CBTCards/cards.json
//

import Foundation

/// A reusable CBT technique card with examples
struct CBTCard: Codable, Identifiable, Equatable {
    // MARK: - Properties

    /// Unique identifier for the card
    let id: String

    /// Short title for the technique (e.g., "Cognitive Reframing")
    let title: String

    /// Detailed description of the technique
    let technique: String

    /// Concrete example demonstrating the technique
    let example: String

    /// Category of cognitive distortion this addresses
    let distortionType: DistortionType?

    /// Difficulty level for applying this technique
    let difficulty: Difficulty

    // MARK: - Nested Types

    /// Common cognitive distortions
    enum DistortionType: String, Codable, CaseIterable {
        case allOrNothing = "all_or_nothing"
        case overgeneralization
        case mentalFilter = "mental_filter"
        case discountingPositives = "discounting_positives"
        case jumpingToConclusions = "jumping_to_conclusions"
        case catastrophizing
        case emotionalReasoning = "emotional_reasoning"
        case shouldStatements = "should_statements"
        case labeling
        case personalization

        var displayName: String {
            switch self {
            case .allOrNothing: return "All-or-Nothing Thinking"
            case .overgeneralization: return "Overgeneralization"
            case .mentalFilter: return "Mental Filter"
            case .discountingPositives: return "Discounting the Positive"
            case .jumpingToConclusions: return "Jumping to Conclusions"
            case .catastrophizing: return "Catastrophizing"
            case .emotionalReasoning: return "Emotional Reasoning"
            case .shouldStatements: return "Should Statements"
            case .labeling: return "Labeling"
            case .personalization: return "Personalization"
            }
        }
    }

    /// Difficulty level for the technique
    enum Difficulty: String, Codable {
        case beginner
        case intermediate
        case advanced

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Initialization

    init(
        id: String,
        title: String,
        technique: String,
        example: String,
        distortionType: DistortionType? = nil,
        difficulty: Difficulty = .beginner
    ) {
        self.id = id
        self.title = title
        self.technique = technique
        self.example = example
        self.distortionType = distortionType
        self.difficulty = difficulty
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case technique
        case example
        case distortionType = "distortion_type"
        case difficulty
    }

    // MARK: - Computed Properties

    /// Preview of technique (first 120 characters)
    var techniquePreview: String {
        if technique.count <= 120 {
            return technique
        }
        let index = technique.index(technique.startIndex, offsetBy: 120)
        return String(technique[..<index]) + "..."
    }
}

// MARK: - Sample Data

extension CBTCard {
    /// Sample card for cognitive reframing
    static let sampleReframing = CBTCard(
        id: "card_reframing",
        title: "Cognitive Reframing",
        technique: "Challenge negative thoughts by looking for alternative, more balanced perspectives. Ask yourself: What evidence supports or contradicts this thought? What would I tell a friend in this situation?",
        example: "Thought: 'I'll fail this presentation.' Reframe: 'I'm well-prepared. Even if it's not perfect, I can learn from it.'",
        distortionType: .catastrophizing,
        difficulty: .beginner
    )

    /// Sample card for thought records
    static let sampleThoughtRecord = CBTCard(
        id: "card_thought_record",
        title: "Thought Record",
        technique: "Document the situation, your automatic thoughts, emotions, and evidence for/against the thought. Then generate a more balanced thought based on the evidence.",
        example: "Situation: Boss didn't reply to my email. Thought: 'They're angry with me.' Evidence against: They might be busy, I've had good feedback recently. Balanced: 'There are many reasons they haven't replied yet.'",
        distortionType: .jumpingToConclusions,
        difficulty: .intermediate
    )

    /// Sample card for behavioral activation
    static let sampleBehavioralActivation = CBTCard(
        id: "card_behavioral_activation",
        title: "Behavioral Activation",
        technique: "When feeling low, engage in a small, manageable activity that brings pleasure or accomplishment. Start with tiny steps—even 5 minutes counts.",
        example: "Instead of staying in bed, take a 5-minute walk outside. Notice how your mood shifts slightly after the activity.",
        distortionType: nil,
        difficulty: .beginner
    )

    /// Sample card for mindfulness
    static let sampleMindfulness = CBTCard(
        id: "card_mindfulness",
        title: "Mindful Breathing",
        technique: "Focus on your breath for 60 seconds. Notice the sensation of air entering and leaving your body. When your mind wanders, gently return attention to the breath without judgment.",
        example: "Set a timer for 1 minute. Breathe naturally and count each exhale up to 10, then start over. This creates distance from anxious thoughts.",
        distortionType: nil,
        difficulty: .beginner
    )

    /// Sample card for evidence testing
    static let sampleEvidenceTesting = CBTCard(
        id: "card_evidence_testing",
        title: "Evidence Testing",
        technique: "Treat your negative thought like a hypothesis. What evidence supports it? What evidence contradicts it? Weigh the evidence objectively.",
        example: "Thought: 'Nobody likes me.' Evidence for: One person didn't say hi today. Evidence against: Friend invited me to lunch, colleague complimented my work, family checks in regularly. Conclusion: This thought is not supported by evidence.",
        distortionType: .allOrNothing,
        difficulty: .intermediate
    )

    /// Sample card for values clarification
    static let sampleValuesClarification = CBTCard(
        id: "card_values",
        title: "Values Clarification",
        technique: "Identify what truly matters to you (relationships, growth, creativity, etc.). Use your values to guide decisions rather than anxiety or short-term emotions.",
        example: "If 'connection' is a value, accept that social invitation even if anxiety says to decline. Act in alignment with values, not just feelings.",
        distortionType: nil,
        difficulty: .advanced
    )

    /// All sample cards
    static let allSamples: [CBTCard] = [
        sampleReframing,
        sampleThoughtRecord,
        sampleBehavioralActivation,
        sampleMindfulness,
        sampleEvidenceTesting,
        sampleValuesClarification
    ]
}
