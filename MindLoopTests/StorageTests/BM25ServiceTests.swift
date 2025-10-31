//
//  BM25ServiceTests.swift
//  MindLoopTests
//
//  Unit tests for BM25Service
//

import Testing
import Foundation
@testable import MindLoop

@Suite("BM25Service Tests")
struct BM25ServiceTests {

    // MARK: - Setup

    init() async throws {
        try SQLiteManager.shared.openDatabase()
    }

    // MARK: - Full-Text Search

    @Test("Search finds matching entries")
    func testBasicSearch() throws {
        // Create entries with specific keywords
        let entry1 = JournalEntry(
            id: "bm25-search-1",
            timestamp: Date(),
            text: "Feeling anxious about the upcoming presentation at work",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["work", "anxiety"]
        )

        let entry2 = JournalEntry(
            id: "bm25-search-2",
            timestamp: Date(),
            text: "Had a wonderful day with friends, feeling grateful",
            emotion: EmotionSignal.samplePositive,
            tags: ["social", "gratitude"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)

        // Search for "anxious"
        let results = try BM25Service.shared.search(
            query: "anxious",
            k: 5,
            recencyBoost: 0.0 // Pure BM25 scoring
        )

        #expect(results.count >= 1)
        #expect(results.contains(where: { $0.entryId == "bm25-search-1" }))
    }

    @Test("Search handles multiple keywords")
    func testMultipleKeywords() throws {
        let entry1 = JournalEntry(
            id: "bm25-multi-1",
            timestamp: Date(),
            text: "Work deadline causing stress and anxiety",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["work", "stress"]
        )

        let entry2 = JournalEntry(
            id: "bm25-multi-2",
            timestamp: Date(),
            text: "Relaxing weekend, no work thoughts",
            emotion: EmotionSignal.samplePositive,
            tags: ["relaxation"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)

        // Search for "work stress"
        let results = try BM25Service.shared.search(
            query: "work stress",
            k: 5,
            recencyBoost: 0.0
        )

        #expect(results.count >= 1)
        // Entry 1 should rank higher (contains both keywords)
        if let topResult = results.first {
            #expect(topResult.entryId == "bm25-multi-1")
        }
    }

    @Test("Search returns empty for no matches")
    func testNoMatches() throws {
        let entry = JournalEntry(
            id: "bm25-nomatch",
            timestamp: Date(),
            text: "Regular journal entry about daily activities",
            emotion: EmotionSignal.sampleNeutral,
            tags: ["routine"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry)

        // Search for something that doesn't exist
        let results = try BM25Service.shared.search(
            query: "xyzabc123unlikely",
            k: 5
        )

        #expect(results.isEmpty)
    }

    @Test("Search respects k parameter")
    func testSearchK() throws {
        // Create 10 entries with common keyword
        for i in 0..<10 {
            let entry = JournalEntry(
                id: "bm25-k-test-\(i)",
                timestamp: Date().addingTimeInterval(Double(i) * 3600),
                text: "Entry \(i) about feeling stressed",
                emotion: EmotionSignal.sampleAnxious,
                tags: ["stress"]
            )
            try SQLiteManager.shared.insertJournalEntry(entry)
        }

        // Search with k=3
        let results = try BM25Service.shared.search(
            query: "stressed",
            k: 3,
            recencyBoost: 0.0
        )

        #expect(results.count == 3)
    }

    @Test("Recency boost affects rankings")
    func testRecencyBoost() throws {
        // Old entry with perfect keyword match
        let oldEntry = JournalEntry(
            id: "bm25-recency-old",
            timestamp: Date().addingTimeInterval(-30 * 86400), // 30 days ago
            text: "Feeling anxious anxious anxious", // Multiple keyword matches
            emotion: EmotionSignal.sampleAnxious,
            tags: ["anxiety"]
        )

        // Recent entry with single keyword match
        let recentEntry = JournalEntry(
            id: "bm25-recency-recent",
            timestamp: Date().addingTimeInterval(-1 * 86400), // 1 day ago
            text: "Feeling anxious today",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["anxiety"]
        )

        try SQLiteManager.shared.insertJournalEntry(oldEntry)
        try SQLiteManager.shared.insertJournalEntry(recentEntry)

        // Search with high recency boost
        let results = try BM25Service.shared.search(
            query: "anxious",
            k: 2,
            recencyBoost: 0.8 // Heavy recency weighting
        )

        #expect(results.count == 2)
        // Recent entry should rank first due to recency boost
        #expect(results[0].entryId == "bm25-recency-recent")
    }

    @Test("Empty query returns empty results")
    func testEmptyQuery() throws {
        let results = try BM25Service.shared.search(
            query: "",
            k: 5
        )

        #expect(results.isEmpty)
    }

    @Test("Query sanitization handles special characters")
    func testQuerySanitization() throws {
        let entry = JournalEntry(
            id: "bm25-sanitize",
            timestamp: Date(),
            text: "Feeling great today!",
            emotion: EmotionSignal.samplePositive,
            tags: ["mood"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry)

        // Search with special characters (should be sanitized)
        let results = try BM25Service.shared.search(
            query: "great!@#$%",
            k: 5
        )

        // Should still find the entry (sanitization removes special chars)
        #expect(results.count >= 1)
    }

    // MARK: - Tag Search

    @Test("Search by tags finds matching entries")
    func testSearchByTags() throws {
        let entry1 = JournalEntry(
            id: "bm25-tag-1",
            timestamp: Date(),
            text: "Work-related stress",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["work", "stress"]
        )

        let entry2 = JournalEntry(
            id: "bm25-tag-2",
            timestamp: Date(),
            text: "Family gathering",
            emotion: EmotionSignal.samplePositive,
            tags: ["family", "social"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)

        // Search for work tag
        let results = try BM25Service.shared.searchByTags(
            tags: ["work"],
            k: 5
        )

        #expect(results.count >= 1)
        #expect(results.contains(where: { $0.entryId == "bm25-tag-1" }))
    }

    @Test("Search by multiple tags")
    func testSearchByMultipleTags() throws {
        let entry1 = JournalEntry(
            id: "bm25-multitag-1",
            timestamp: Date(),
            text: "Work stress",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["work", "stress"]
        )

        let entry2 = JournalEntry(
            id: "bm25-multitag-2",
            timestamp: Date(),
            text: "Exercise session",
            emotion: EmotionSignal.samplePositive,
            tags: ["health", "exercise"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)

        // Search for work OR health
        let results = try BM25Service.shared.searchByTags(
            tags: ["work", "health"],
            k: 5
        )

        #expect(results.count >= 2)
    }

    @Test("Empty tags array returns empty results")
    func testEmptyTags() throws {
        let results = try BM25Service.shared.searchByTags(
            tags: [],
            k: 5
        )

        #expect(results.isEmpty)
    }

    // MARK: - Emotion Search

    @Test("Search by emotion finds matching entries")
    func testSearchByEmotion() throws {
        let entry1 = JournalEntry(
            id: "bm25-emotion-1",
            timestamp: Date(),
            text: "Feeling anxious",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["anxiety"]
        )

        let entry2 = JournalEntry(
            id: "bm25-emotion-2",
            timestamp: Date(),
            text: "Feeling great",
            emotion: EmotionSignal.samplePositive,
            tags: ["mood"]
        )

        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)

        // Search for anxious emotion
        let results = try BM25Service.shared.searchByEmotion(
            label: .anxious,
            k: 5
        )

        #expect(results.count >= 1)
        #expect(results.contains(where: { $0.entryId == "bm25-emotion-1" }))
    }

    @Test("Emotion search scores by confidence and recency")
    func testEmotionSearchScoring() throws {
        // High confidence, old entry
        let oldEntry = JournalEntry(
            id: "bm25-emotion-old",
            timestamp: Date().addingTimeInterval(-30 * 86400),
            text: "Very anxious",
            emotion: EmotionSignal(label: .anxious, confidence: 0.95, valence: -0.8, arousal: 0.9),
            tags: ["anxiety"]
        )

        // Lower confidence, recent entry
        let recentEntry = JournalEntry(
            id: "bm25-emotion-recent",
            timestamp: Date().addingTimeInterval(-1 * 86400),
            text: "Slightly anxious",
            emotion: EmotionSignal(label: .anxious, confidence: 0.60, valence: -0.3, arousal: 0.4),
            tags: ["anxiety"]
        )

        try SQLiteManager.shared.insertJournalEntry(oldEntry)
        try SQLiteManager.shared.insertJournalEntry(recentEntry)

        let results = try BM25Service.shared.searchByEmotion(
            label: .anxious,
            k: 2
        )

        #expect(results.count == 2)
        // Both confidence and recency contribute to score
        // Results should be ordered by combined score
        #expect(results[0].score >= results[1].score)
    }
}
