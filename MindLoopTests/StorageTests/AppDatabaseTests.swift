//
//  AppDatabaseTests.swift
//  MindLoopTests
//
//  Tests for GRDB-based AppDatabase storage layer.
//  Each test gets its own in-memory database — no shared state, no data races.
//

import Testing
import Foundation
@testable import MindLoop

@Suite("AppDatabase Tests")
struct AppDatabaseTests {

    /// Each test gets a fresh in-memory database
    private func makeDB() throws -> AppDatabase {
        try AppDatabase.makeEmpty()
    }

    // MARK: - Journal Entry CRUD

    @Test("Insert and fetch a journal entry")
    func testInsertAndFetch() throws {
        let db = try makeDB()
        let entry = JournalEntryRecord(from: JournalEntry(
            id: "test-1",
            text: "I felt anxious about work today",
            emotion: EmotionSignal.sampleAnxious,
            tags: ["work", "anxiety"]
        ))

        try db.saveEntry(entry)
        let fetched = try db.fetchAllEntries()

        #expect(fetched.count == 1)
        #expect(fetched[0].id == "test-1")
        #expect(fetched[0].text == "I felt anxious about work today")
        #expect(fetched[0].emotionLabel == "anxious")
    }

    @Test("Entries are ordered newest first")
    func testOrdering() throws {
        let db = try makeDB()
        let now = Date()

        let older = JournalEntryRecord(from: JournalEntry(
            id: "old",
            timestamp: now.addingTimeInterval(-3600),
            text: "Older entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        let newer = JournalEntryRecord(from: JournalEntry(
            id: "new",
            timestamp: now,
            text: "Newer entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))

        try db.saveEntry(older)
        try db.saveEntry(newer)

        let entries = try db.fetchAllEntries()
        #expect(entries.count == 2)
        #expect(entries[0].id == "new")
        #expect(entries[1].id == "old")
    }

    @Test("Fetch entries by date range")
    func testDateRangeQuery() throws {
        let db = try makeDB()
        let now = Date()

        for i in 0..<5 {
            let entry = JournalEntryRecord(from: JournalEntry(
                id: "entry-\(i)",
                timestamp: now.addingTimeInterval(Double(-i * 3600)),
                text: "Entry \(i)",
                emotion: EmotionSignal.sampleNeutral,
                tags: []
            ))
            try db.saveEntry(entry)
        }

        let recent = try db.fetchEntries(
            from: now.addingTimeInterval(-7200),
            to: now
        )
        #expect(recent.count == 3) // entries 0, 1, 2
    }

    @Test("Delete entry cascades to chunks")
    func testCascadeDelete() throws {
        let db = try makeDB()

        let entry = JournalEntryRecord(from: JournalEntry(
            id: "delete-me",
            text: "Will be deleted",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        try db.saveEntry(entry)

        let chunk = SemanticChunkRecord(from: SemanticChunk(
            parentEntryId: "delete-me",
            chunkIndex: 0,
            text: "Will be deleted too",
            startTime: 0,
            endTime: 5,
            dominantEmotion: .neutral,
            emotionConfidence: 0.8,
            valence: 0,
            arousal: 0.3,
            tokenCount: 10
        ))
        try db.saveChunk(chunk)

        try db.deleteEntry(id: "delete-me")

        let entries = try db.fetchAllEntries()
        let chunks = try db.fetchChunks(forEntry: "delete-me")
        #expect(entries.isEmpty)
        #expect(chunks.isEmpty)
    }

    @Test("Tags are preserved through round-trip")
    func testTagsRoundTrip() throws {
        let db = try makeDB()
        let entry = JournalEntryRecord(from: JournalEntry(
            id: "tags-test",
            text: "Testing tags",
            emotion: EmotionSignal.sampleNeutral,
            tags: ["work", "stress", "family"]
        ))

        try db.saveEntry(entry)
        let fetched = try db.fetchAllEntries()
        let domain = fetched[0].toDomain()

        #expect(domain.tags == ["work", "stress", "family"])
    }

    // MARK: - Semantic Chunks

    @Test("Store and retrieve chunks with embeddings")
    func testChunkEmbeddings() throws {
        let db = try makeDB()

        let entry = JournalEntryRecord(from: JournalEntry(
            id: "embed-test",
            text: "Test entry for embeddings",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        try db.saveEntry(entry)

        let embedding: [Float] = Array(repeating: 0.1, count: 384)
        let chunk = SemanticChunkRecord(from: SemanticChunk(
            parentEntryId: "embed-test",
            chunkIndex: 0,
            text: "Chunk text",
            startTime: 0,
            endTime: 5,
            dominantEmotion: .anxious,
            emotionConfidence: 0.9,
            valence: -0.5,
            arousal: 0.7,
            tokenCount: 20
        ), embedding: embedding)

        try db.saveChunk(chunk)
        let fetched = try db.fetchChunks(forEntry: "embed-test")

        #expect(fetched.count == 1)
        let vec = fetched[0].embeddingVector()
        #expect(vec != nil)
        #expect(vec?.count == 384)
    }

    // MARK: - Personalization Profile

    @Test("Default profile is created")
    func testDefaultProfile() throws {
        let db = try makeDB()
        let profile = try db.fetchProfile()

        #expect(profile.id == "default")
        #expect(profile.tonePreference == "warm")
        #expect(profile.responseLength == "medium")
    }

    @Test("Profile updates persist")
    func testProfileUpdate() throws {
        let db = try makeDB()
        var profile = PersonalizationProfileRecord.makeDefault()
        profile.tonePreference = "direct"
        profile.responseLength = "short"

        try db.saveProfile(profile)
        let fetched = try db.fetchProfile()

        #expect(fetched.tonePreference == "direct")
        #expect(fetched.responseLength == "short")
    }

    // MARK: - Thread Safety

    @Test("Concurrent reads don't crash")
    func testConcurrentReads() async throws {
        let db = try makeDB()

        // Insert some data
        for i in 0..<10 {
            let entry = JournalEntryRecord(from: JournalEntry(
                id: "concurrent-\(i)",
                text: "Entry \(i)",
                emotion: EmotionSignal.sampleNeutral,
                tags: []
            ))
            try db.saveEntry(entry)
        }

        // Read concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let entries = try? db.fetchAllEntries()
                    assert(entries?.count == 10)
                }
            }
        }
    }
}
