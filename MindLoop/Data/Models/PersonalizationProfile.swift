//
//  PersonalizationProfile.swift
//  MindLoop
//
//  Represents user preferences and patterns for personalization
//  Source: CLAUDE.md - LearningLoopAgent PersonalizationProfile schema
//

import Foundation

/// User personalization profile for adaptive coaching
struct PersonalizationProfile: Codable, Equatable {
    // MARK: - Properties

    /// Unique identifier (typically user ID or "default")
    let id: String

    /// Last updated timestamp
    var lastUpdated: Date

    /// Preferred coaching tone
    var tonePref: Tone

    /// Preferred response length
    var responseLength: ResponseLength

    /// Recurring emotional triggers (e.g., "work_stress", "sleep_rumination")
    var emotionTriggers: [String]

    /// Topics to avoid in coaching
    var avoidTopics: [String]

    /// User's preferred CBT techniques/actions
    var preferredActions: [PreferredAction]

    // MARK: - Nested Types

    /// Coaching tone preference
    enum Tone: String, Codable, CaseIterable {
        case warm
        case direct
        case cheerful
        case neutral

        var displayName: String {
            rawValue.capitalized
        }

        var description: String {
            switch self {
            case .warm: return "Gentle and empathetic"
            case .direct: return "Clear and straightforward"
            case .cheerful: return "Upbeat and encouraging"
            case .neutral: return "Balanced and objective"
            }
        }
    }

    /// Response length preference
    enum ResponseLength: String, Codable, CaseIterable {
        case short
        case medium
        case long

        var displayName: String {
            rawValue.capitalized
        }

        var tokenRange: ClosedRange<Int> {
            switch self {
            case .short: return 50...80
            case .medium: return 80...120
            case .long: return 120...150
            }
        }
    }

    /// Preferred CBT action types
    enum PreferredAction: String, Codable, CaseIterable {
        case breathing
        case journaling
        case reframing
        case behavioralActivation = "behavioral_activation"
        case mindfulness
        case evidenceTesting = "evidence_testing"
        case thoughtRecords = "thought_records"

        var displayName: String {
            switch self {
            case .breathing: return "Breathing Exercises"
            case .journaling: return "Journaling"
            case .reframing: return "Cognitive Reframing"
            case .behavioralActivation: return "Behavioral Activation"
            case .mindfulness: return "Mindfulness"
            case .evidenceTesting: return "Evidence Testing"
            case .thoughtRecords: return "Thought Records"
            }
        }
    }

    // MARK: - Initialization

    init(
        id: String = "default",
        lastUpdated: Date = Date(),
        tonePref: Tone = .warm,
        responseLength: ResponseLength = .medium,
        emotionTriggers: [String] = [],
        avoidTopics: [String] = [],
        preferredActions: [PreferredAction] = [.reframing, .breathing]
    ) {
        self.id = id
        self.lastUpdated = lastUpdated
        self.tonePref = tonePref
        self.responseLength = responseLength
        self.emotionTriggers = emotionTriggers
        self.avoidTopics = avoidTopics
        self.preferredActions = preferredActions
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case lastUpdated = "last_updated"
        case tonePref = "tone_pref"
        case responseLength = "response_length"
        case emotionTriggers = "emotion_triggers"
        case avoidTopics = "avoid_topics"
        case preferredActions = "preferred_actions"
    }

    // MARK: - Methods

    /// Update profile based on user feedback
    mutating func applyFeedback(
        feedbackType: FeedbackType,
        context: FeedbackContext
    ) {
        lastUpdated = Date()

        switch feedbackType {
        case .tooLong:
            // Shift to shorter responses
            if responseLength == .long {
                responseLength = .medium
            } else if responseLength == .medium {
                responseLength = .short
            }

        case .tooShort:
            // Shift to longer responses
            if responseLength == .short {
                responseLength = .medium
            } else if responseLength == .medium {
                responseLength = .long
            }

        case .toneMismatch:
            // User can explicitly set tone via settings
            break

        case .actionUnhelpful:
            // Remove action from preferred list if present
            if let action = context.action {
                preferredActions.removeAll { $0 == action }
            }

        case .actionHelpful:
            // Add action to preferred list if not present
            if let action = context.action,
               !preferredActions.contains(action) {
                preferredActions.append(action)
            }
        }
    }

    /// Feedback types from user interactions
    enum FeedbackType {
        case tooLong
        case tooShort
        case toneMismatch
        case actionUnhelpful
        case actionHelpful
    }

    /// Context for feedback
    struct FeedbackContext {
        let action: PreferredAction?
        let responseId: String
    }

    /// Track new emotion trigger
    mutating func addEmotionTrigger(_ trigger: String) {
        if !emotionTriggers.contains(trigger) {
            emotionTriggers.append(trigger)
            lastUpdated = Date()
        }
    }

    /// Remove emotion trigger
    mutating func removeEmotionTrigger(_ trigger: String) {
        emotionTriggers.removeAll { $0 == trigger }
        lastUpdated = Date()
    }

    /// Check if an action is preferred
    func isPreferred(action: PreferredAction) -> Bool {
        preferredActions.contains(action)
    }

    /// Get prompt instructions for CoachAgent based on this profile
    var promptInstructions: String {
        var instructions: [String] = []

        // Tone instruction
        instructions.append("Tone: \(tonePref.description)")

        // Length instruction
        instructions.append("Response length: \(responseLength.displayName) (~\(responseLength.tokenRange.lowerBound)-\(responseLength.tokenRange.upperBound) tokens)")

        // Preferred actions
        if !preferredActions.isEmpty {
            let actions = preferredActions.map { $0.displayName }.joined(separator: ", ")
            instructions.append("Preferred techniques: \(actions)")
        }

        // Emotion triggers
        if !emotionTriggers.isEmpty {
            let triggers = emotionTriggers.joined(separator: ", ")
            instructions.append("Known triggers: \(triggers)")
        }

        // Avoid topics
        if !avoidTopics.isEmpty {
            let topics = avoidTopics.joined(separator: ", ")
            instructions.append("Avoid topics: \(topics)")
        }

        return instructions.joined(separator: "\n")
    }
}

// MARK: - Sample Data

extension PersonalizationProfile {
    /// Default profile for new users
    static let `default` = PersonalizationProfile(
        id: "default",
        lastUpdated: Date(),
        tonePref: .warm,
        responseLength: .medium,
        emotionTriggers: [],
        avoidTopics: [],
        preferredActions: [.reframing, .breathing]
    )

    /// Sample profile with customization
    static let sampleCustomized = PersonalizationProfile(
        id: "user-123",
        lastUpdated: Date(),
        tonePref: .direct,
        responseLength: .short,
        emotionTriggers: ["work_stress", "sleep_rumination", "social_anxiety"],
        avoidTopics: ["family", "health"],
        preferredActions: [.reframing, .behavioralActivation, .mindfulness]
    )

    /// Sample profile for cheerful tone
    static let sampleCheerful = PersonalizationProfile(
        id: "user-456",
        lastUpdated: Date(),
        tonePref: .cheerful,
        responseLength: .medium,
        emotionTriggers: ["perfectionism", "comparison"],
        avoidTopics: [],
        preferredActions: [.reframing, .breathing, .journaling]
    )
}
