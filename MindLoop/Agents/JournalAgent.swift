//
//  JournalAgent.swift
//  MindLoop
//
//  Normalizes raw text input + EmotionSignal into a structured JournalEntry.
//  Source: CLAUDE.md - JournalAgent contract
//

import Foundation

/// Normalizes raw user input into a structured `JournalEntry` with extracted tags.
///
/// Responsibilities:
/// - Trim and clean raw text (whitespace, collapsed newlines, punctuation artifacts)
/// - Extract keyword-based tags from text content
/// - Derive mood tags from the emotion signal
/// - Produce a complete `JournalEntry` with generated ID and timestamp
struct JournalAgent: AgentProtocol {

    // MARK: - AgentProtocol

    typealias Input = (text: String, emotion: EmotionSignal)
    typealias Output = JournalEntry

    var name: String { "JournalAgent" }

    /// Satisfy `AgentProtocol.process(_:)` by delegating to the convenience method.
    func process(_ input: Input) async throws -> JournalEntry {
        normalize(text: input.text, emotion: input.emotion)
    }

    // MARK: - Tag Dictionaries

    /// Work-related keywords mapped to the "work" tag.
    private static let workKeywords: Set<String> = [
        "work", "job", "boss", "meeting", "deadline", "project", "coworker", "office"
    ]

    /// Relationship-related keywords mapped to the "relationship" tag.
    private static let relationshipKeywords: Set<String> = [
        "partner", "friend", "family", "mom", "dad", "relationship", "marriage"
    ]

    /// Health-related keywords mapped to the "health" tag.
    private static let healthKeywords: Set<String> = [
        "sleep", "exercise", "tired", "energy", "headache", "pain", "eating"
    ]

    // MARK: - Public API

    /// Normalize raw text and emotion into a structured journal entry.
    ///
    /// - Parameters:
    ///   - text: Raw user text or transcript.
    ///   - emotion: Hybrid emotion signal from text sentiment + prosody analysis.
    /// - Returns: A fully populated `JournalEntry`.
    func normalize(text: String, emotion: EmotionSignal) -> JournalEntry {
        let cleanedText = normalizeText(text)
        let tags = extractTags(from: cleanedText, emotion: emotion)

        return JournalEntry(
            text: cleanedText,
            emotion: emotion,
            tags: tags
        )
    }

    // MARK: - Text Normalization

    /// Clean raw text by trimming whitespace, collapsing newlines, and
    /// removing leading/trailing punctuation artifacts.
    func normalizeText(_ text: String) -> String {
        var result = text

        // 1. Trim leading/trailing whitespace and newlines
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Collapse multiple consecutive newlines into a single newline
        result = collapseNewlines(result)

        // 3. Remove leading/trailing punctuation artifacts
        //    (e.g., stray commas, periods, ellipses from STT)
        result = removePunctuationArtifacts(result)

        return result
    }

    // MARK: - Tag Extraction

    /// Extract tags from text content and emotion signal.
    ///
    /// Uses keyword matching for topic tags and derives mood tags from
    /// the emotion label. Returns a unique, sorted array of lowercase tags.
    func extractTags(from text: String, emotion: EmotionSignal) -> [String] {
        var tags = Set<String>()

        let lowercasedText = text.lowercased()
        // Split into words for whole-word matching
        let words = extractWords(from: lowercasedText)

        // Topic-based tags
        if !words.isDisjoint(with: Self.workKeywords) {
            tags.insert("work")
        }
        if !words.isDisjoint(with: Self.relationshipKeywords) {
            tags.insert("relationship")
        }
        if !words.isDisjoint(with: Self.healthKeywords) {
            tags.insert("health")
        }

        // Mood-derived tags from emotion label
        if let moodTag = moodTag(for: emotion.label) {
            tags.insert(moodTag)
        }

        return tags.sorted()
    }

    // MARK: - Private Helpers

    /// Collapse runs of two or more newlines into a single newline.
    private func collapseNewlines(_ text: String) -> String {
        // Replace sequences of 2+ newlines (with optional whitespace between) with a single newline
        var result = text
        // Use a simple loop to avoid regex dependency overhead
        while let range = result.range(of: "\n\\s*\n", options: .regularExpression) {
            result.replaceSubrange(range, with: "\n")
        }
        return result
    }

    /// Remove leading and trailing punctuation artifacts commonly produced by STT.
    /// Keeps meaningful punctuation at the end (period, question mark, exclamation).
    private func removePunctuationArtifacts(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let artifactCharacters = CharacterSet(charactersIn: ".,;:!?…\u{2026}-–—")
            .union(.whitespaces)

        // Strip leading artifacts
        var result = text
        while let first = result.unicodeScalars.first,
              artifactCharacters.contains(first) {
            result = String(result.dropFirst())
        }

        // Strip trailing artifacts (except a single sentence-ending punctuation)
        while result.count > 1,
              let last = result.unicodeScalars.last,
              artifactCharacters.contains(last) {
            // Keep a single trailing period, question mark, or exclamation mark
            let sentenceEnders: CharacterSet = CharacterSet(charactersIn: ".!?")
            if sentenceEnders.contains(last) {
                // Check if the character before it is also the same punctuation — if so, strip
                let scalars = result.unicodeScalars
                let lastIndex = scalars.index(before: scalars.endIndex)
                let beforeLastIndex = scalars.index(before: lastIndex)
                let beforeLast = scalars[beforeLastIndex]
                if beforeLast == last {
                    result = String(result.dropLast())
                } else {
                    break
                }
            } else {
                result = String(result.dropLast())
            }
        }

        return result
    }

    /// Extract individual words from text, stripping punctuation attached to words.
    private func extractWords(from text: String) -> Set<String> {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        let words = components
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        return Set(words)
    }

    /// Map an emotion label to a mood tag string.
    private func moodTag(for label: EmotionSignal.Label) -> String? {
        switch label {
        case .anxious:
            return "anxiety"
        case .sad:
            return "sadness"
        case .positive:
            return "positivity"
        case .neutral:
            return nil
        }
    }
}
