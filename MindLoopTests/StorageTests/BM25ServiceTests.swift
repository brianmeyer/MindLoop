//
//  BM25ServiceTests.swift
//  MindLoopTests
//
//  Tests for GRDB-based BM25Service with injectable database.
//

import Testing
import Foundation
@testable import MindLoop

@Suite("BM25Service Tests")
struct BM25ServiceTests {

    private func makeService() throws -> (BM25Service, AppDatabase) {
        let db = try AppDatabase.makeEmpty()
        let service = BM25Service(database: db)
        return (service, db)
    }

    // MARK: - Emotion Search

    @Test("Search by emotion finds matching entries")
    func testSearchByEmotion() throws {
        let (service, db) = try makeService()

        try db.saveEntry(JournalEntryRecord(from: JournalEntry(
            id: "emotion-1",
            text: "Feeling anxious",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["anxiety"]
        )))
        try db.saveEntry(JournalEntryRecord(from: JournalEntry(
            id: "emotion-2",
            text: "Feeling great",
            emotion: EmotionSignal.samplePositive,
            tags: ["mood"]
        )))

        let results = try service.searchByEmotion(label: .anxious, k: 5)

        #expect(results.count == 1)
        #expect(results[0].entryId == "emotion-1")
    }

    @Test("Empty query returns empty results")
    func testEmptyQuery() throws {
        let (service, _) = try makeService()
        let results = try service.search(query: "", k: 5)
        #expect(results.isEmpty)
    }

    @Test("Special characters are sanitized")
    func testSanitization() throws {
        let (service, _) = try makeService()
        // Should not crash on special chars
        let results = try service.search(query: "!@#$%^&*()", k: 5)
        #expect(results.isEmpty)
    }
}
