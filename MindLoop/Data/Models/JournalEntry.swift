//
//  JournalEntry.swift
//  MindLoop
//
//  Represents a single journal entry with emotion and embeddings
//  Source: CLAUDE.md Data Models section
//

import Foundation

/// A journal entry with text, emotion analysis, and vector embeddings
struct JournalEntry: Codable, Identifiable, Equatable, Sendable {
    // MARK: - Properties

    /// Unique identifier for the entry
    let id: String

    /// Timestamp when the entry was created
    let timestamp: Date

    /// Raw journal text (transcribed or typed)
    let text: String

    /// Emotion signal from hybrid analysis (prosody + text sentiment)
    let emotion: EmotionSignal

    /// Extracted topics/keywords for filtering and trends
    let tags: [String]

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        text: String,
        emotion: EmotionSignal,
        tags: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.emotion = emotion
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// Date formatted as "MMM d, yyyy" for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }

    /// Time formatted as "h:mm a" for display
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Preview text (first 100 characters)
    var preview: String {
        if text.count <= 100 {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: 100)
        return String(text[..<index]) + "..."
    }

    /// Word count
    var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

}

// MARK: - Sample Data

extension JournalEntry {
    /// Sample entry for previews and testing
    static let sample = JournalEntry(
        id: "sample-1",
        timestamp: Date(),
        text: "I'm feeling stressed about the presentation tomorrow. I keep thinking about all the things that could go wrong.",
        emotion: EmotionSignal(
            label: .anxious,
            confidence: 0.78,
            valence: -0.4,
            arousal: 0.6,
            prosodyFeatures: [:]
        ),

        tags: ["work", "stress", "presentation"]
    )

    /// Sample positive entry
    static let samplePositive = JournalEntry(
        id: "sample-2",
        timestamp: Date().addingTimeInterval(-86400),
        text: "Had a great conversation with a friend today. Feeling grateful for the support.",
        emotion: EmotionSignal(
            label: .positive,
            confidence: 0.85,
            valence: 0.7,
            arousal: 0.3,
            prosodyFeatures: [:]
        ),

        tags: ["gratitude", "friendship", "connection"]
    )

    /// Sample neutral entry
    static let sampleNeutral = JournalEntry(
        id: "sample-3",
        timestamp: Date().addingTimeInterval(-172800),
        text: "Today was uneventful. Worked on some routine tasks.",
        emotion: EmotionSignal(
            label: .neutral,
            confidence: 0.92,
            valence: 0.0,
            arousal: 0.1,
            prosodyFeatures: [:]
        ),

        tags: ["work", "routine"]
    )
}
