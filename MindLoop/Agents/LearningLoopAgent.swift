//
//  LearningLoopAgent.swift
//  MindLoop
//
//  Per-user adaptation agent: tracks feedback, updates PersonalizationProfile.
//  NEVER overrides SafetyAgent decisions.
//  Source: CLAUDE.md - LearningLoopAgent contract (REC-231)
//

import Foundation

// MARK: - Feedback

/// User feedback on a coach response: thumbs up/down with optional edit text.
enum Feedback: Sendable, Equatable {
    /// User approved the response
    case thumbsUp
    /// User disapproved the response
    case thumbsDown
    /// User edited the response text (implies disapproval of original)
    case edit(String)
}

// MARK: - LearningLoopAgent

/// Tracks explicit feedback and emotional patterns to maintain a PersonalizationProfile.
///
/// Responsibilities (from CLAUDE.md):
/// 1. Track explicit feedback (thumbs up/down) and edits
/// 2. Track emotional patterns (time-based, topic-based triggers)
/// 3. Maintain PersonalizationProfile in database
/// 4. Provide CoachAgent a profile summary every turn
/// 5. NEVER override SafetyAgent decisions
struct LearningLoopAgent: AgentProtocol, Sendable {

    // MARK: - AgentProtocol

    typealias Input = (response: CoachResponse, feedback: Feedback)
    typealias Output = PersonalizationProfile

    var name: String { "LearningLoopAgent" }

    // MARK: - Dependencies

    private let database: AppDatabase

    // MARK: - Initialization

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Process

    /// Process feedback and return an updated PersonalizationProfile.
    func process(_ input: Input) async throws -> PersonalizationProfile {
        let record = try database.fetchProfile()
        var profile = record.toDomain()

        applyFeedback(input.feedback, response: input.response, to: &profile)

        let existingRecord = try? database.fetchProfile()
        var updatedRecord = PersonalizationProfileRecord.from(profile)
        updatedRecord.userName = existingRecord?.userName ?? ""
        try database.saveProfile(updatedRecord)

        return profile
    }

    // MARK: - Profile Summary

    /// Fetches the current profile for CoachAgent consumption.
    func currentProfile() throws -> PersonalizationProfile {
        let record = try database.fetchProfile()
        return record.toDomain()
    }

    /// Returns prompt instructions string for injection into the coach prompt.
    func profileSummary() throws -> String {
        let profile = try currentProfile()
        return profile.promptInstructions
    }

    // MARK: - Feedback Application

    /// Apply user feedback to the profile, mutating it in place.
    private func applyFeedback(
        _ feedback: Feedback,
        response: CoachResponse,
        to profile: inout PersonalizationProfile
    ) {
        profile.lastUpdated = Date()

        switch feedback {
        case .thumbsUp:
            applyPositiveFeedback(response: response, to: &profile)

        case .thumbsDown:
            applyNegativeFeedback(response: response, to: &profile)

        case .edit(let editedText):
            applyEditFeedback(editedText: editedText, response: response, to: &profile)
        }
    }

    /// Thumbs up: reinforce current preferences.
    private func applyPositiveFeedback(
        response: CoachResponse,
        to profile: inout PersonalizationProfile
    ) {
        // Reinforce the suggested action type if present
        if let action = response.suggestedAction,
           let preferredAction = inferAction(from: action) {
            if !profile.preferredActions.contains(preferredAction) {
                profile.preferredActions.append(preferredAction)
            }
        }
    }

    /// Thumbs down: adjust length and tone away from current response.
    private func applyNegativeFeedback(
        response: CoachResponse,
        to profile: inout PersonalizationProfile
    ) {
        // If response was long, user may prefer shorter
        let tokenCount = response.metadata.tokenCount
        if tokenCount > 100 {
            adjustLengthShorter(&profile)
        } else if tokenCount < 60 {
            adjustLengthLonger(&profile)
        }

        // Remove the suggested action from preferred if user rejected it
        if let action = response.suggestedAction,
           let preferredAction = inferAction(from: action) {
            profile.preferredActions.removeAll { $0 == preferredAction }
        }
    }

    /// Edit feedback: user rewrote the response, infer preferences from the edit.
    private func applyEditFeedback(
        editedText: String,
        response: CoachResponse,
        to profile: inout PersonalizationProfile
    ) {
        let originalWordCount = response.wordCount
        let editedWordCount = editedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        // If user shortened the response significantly, prefer shorter
        if editedWordCount < originalWordCount - 10 {
            adjustLengthShorter(&profile)
        }
        // If user lengthened the response significantly, prefer longer
        else if editedWordCount > originalWordCount + 10 {
            adjustLengthLonger(&profile)
        }

        // Detect tone signal from edit: if edit is more direct (shorter sentences),
        // shift tone toward direct
        let avgSentenceLength = averageSentenceLength(editedText)
        if avgSentenceLength < 8 {
            profile.tonePref = .direct
        }
    }

    // MARK: - Length Adjustment

    private func adjustLengthShorter(_ profile: inout PersonalizationProfile) {
        switch profile.responseLength {
        case .long:   profile.responseLength = .medium
        case .medium: profile.responseLength = .short
        case .short:  break
        }
    }

    private func adjustLengthLonger(_ profile: inout PersonalizationProfile) {
        switch profile.responseLength {
        case .short:  profile.responseLength = .medium
        case .medium: profile.responseLength = .long
        case .long:   break
        }
    }

    // MARK: - Helpers

    /// Infer a PreferredAction from the action suggestion text.
    func inferAction(from text: String) -> PersonalizationProfile.PreferredAction? {
        let lower = text.lowercased()
        if lower.contains("breath") { return .breathing }
        if lower.contains("journal") || lower.contains("write") || lower.contains("list") { return .journaling }
        if lower.contains("refram") || lower.contains("another way") { return .reframing }
        if lower.contains("activat") || lower.contains("step") || lower.contains("walk") { return .behavioralActivation }
        if lower.contains("mindful") || lower.contains("meditat") || lower.contains("present") { return .mindfulness }
        if lower.contains("evidence") || lower.contains("proof") { return .evidenceTesting }
        if lower.contains("thought record") || lower.contains("record your thought") { return .thoughtRecords }
        return nil
    }

    /// Average sentence length in words.
    private func averageSentenceLength(_ text: String) -> Int {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return 0 }
        let totalWords = sentences.reduce(0) { sum, sentence in
            sum + sentence.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count
        }
        return totalWords / sentences.count
    }
}

// MARK: - PersonalizationProfileRecord Conversion

extension PersonalizationProfileRecord {
    /// Convert record to domain model.
    func toDomain() -> PersonalizationProfile {
        let tone = PersonalizationProfile.Tone(rawValue: tonePreference) ?? .warm
        let length = PersonalizationProfile.ResponseLength(rawValue: responseLength) ?? .medium
        let triggers = Self.decodeJSON([String].self, from: emotionTriggers) ?? []
        let avoid = Self.decodeJSON([String].self, from: avoidTopics) ?? []
        let actions = (Self.decodeJSON([String].self, from: preferredActions) ?? [])
            .compactMap { PersonalizationProfile.PreferredAction(rawValue: $0) }

        return PersonalizationProfile(
            id: id,
            lastUpdated: lastUpdated,
            tonePref: tone,
            responseLength: length,
            emotionTriggers: triggers,
            avoidTopics: avoid,
            preferredActions: actions,
            moodValue: moodValue
        )
    }

    /// Convert domain model back to record.
    static func from(_ profile: PersonalizationProfile) -> PersonalizationProfileRecord {
        PersonalizationProfileRecord(
            id: profile.id,
            tonePreference: profile.tonePref.rawValue,
            responseLength: profile.responseLength.rawValue,
            emotionTriggers: encodeJSON(profile.emotionTriggers),
            avoidTopics: encodeJSON(profile.avoidTopics),
            preferredActions: encodeJSON(profile.preferredActions.map(\.rawValue)),
            lastUpdated: profile.lastUpdated,
            userName: "",
            moodValue: profile.moodValue
        )
    }

    // MARK: - JSON Helpers

    private static func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }
}
