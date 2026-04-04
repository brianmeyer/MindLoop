//
//  VectorStoreTests.swift
//  MindLoopTests
//
//  Tests for GRDB-based VectorStore with injectable database.
//

import Testing
import Foundation
@testable import MindLoop

@Suite("VectorStore Tests")
struct VectorStoreTests {

    private func makeStore() throws -> (VectorStore, AppDatabase) {
        let db = try AppDatabase.makeEmpty()
        let store = VectorStore(database: db)
        return (store, db)
    }

    // MARK: - Storage

    @Test("Store chunk embedding round-trips correctly")
    func testStoreAndRetrieve() throws {
        let (store, db) = try makeStore()

        let entry = JournalEntryRecord(from: JournalEntry(
            id: "vec-test-1",
            text: "Test entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        try db.saveEntry(entry)

        let chunk = SemanticChunk(
            parentEntryId: "vec-test-1",
            chunkIndex: 0,
            text: "Test chunk",
            startTime: 0,
            endTime: 5,
            dominantEmotion: .neutral,
            emotionConfidence: 0.8,
            valence: 0,
            arousal: 0.3,
            tokenCount: 10
        )

        let vector = [Float](repeating: 0.1, count: 384)
        try store.storeChunkEmbedding(chunk: chunk, vector: vector)

        let chunks = try db.fetchChunks(forEntry: "vec-test-1")
        #expect(chunks.count == 1)
        #expect(chunks[0].embeddingVector()?.count == 384)
    }

    @Test("Rejects wrong dimension")
    func testDimensionValidation() throws {
        let (store, db) = try makeStore()

        let entry = JournalEntryRecord(from: JournalEntry(
            id: "dim-test",
            text: "Test",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        try db.saveEntry(entry)

        let chunk = SemanticChunk(
            parentEntryId: "dim-test",
            chunkIndex: 0,
            text: "Test",
            startTime: 0,
            endTime: 1,
            dominantEmotion: .neutral,
            emotionConfidence: 0.5,
            valence: 0,
            arousal: 0,
            tokenCount: 5
        )

        let wrongDim = [Float](repeating: 0.1, count: 462)
        #expect(throws: VectorStore.VectorStoreError.self) {
            try store.storeChunkEmbedding(chunk: chunk, vector: wrongDim)
        }
    }

    @Test("Similarity search finds matching entries")
    func testSimilaritySearch() throws {
        let (store, db) = try makeStore()

        for i in 0..<3 {
            let entry = JournalEntryRecord(from: JournalEntry(
                id: "search-\(i)",
                text: "Entry \(i)",
                emotion: EmotionSignal.sampleNeutral,
                tags: []
            ))
            try db.saveEntry(entry)

            var vector = [Float](repeating: 0, count: 384)
            vector[i] = 1.0

            let chunk = SemanticChunk(
                parentEntryId: "search-\(i)",
                chunkIndex: 0,
                text: "Chunk \(i)",
                startTime: 0,
                endTime: 5,
                dominantEmotion: .neutral,
                emotionConfidence: 0.8,
                valence: 0,
                arousal: 0.3,
                tokenCount: 10
            )
            try store.storeChunkEmbedding(chunk: chunk, vector: vector)
        }

        var query = [Float](repeating: 0, count: 384)
        query[0] = 1.0

        let results = try store.findSimilarChunks(to: query, k: 3, recencyBoost: 0)
        #expect(!results.isEmpty)
        #expect(results[0].entryId == "search-0")
    }

    @Test("Count returns correct number of embeddings")
    func testCount() throws {
        let (store, db) = try makeStore()

        let entry = JournalEntryRecord(from: JournalEntry(
            id: "count-test",
            text: "Test",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        ))
        try db.saveEntry(entry)

        #expect(try store.count() == 0)

        let chunk = SemanticChunk(
            parentEntryId: "count-test",
            chunkIndex: 0,
            text: "Chunk",
            startTime: 0,
            endTime: 1,
            dominantEmotion: .neutral,
            emotionConfidence: 0.5,
            valence: 0,
            arousal: 0,
            tokenCount: 5
        )
        try store.storeChunkEmbedding(chunk: chunk, vector: [Float](repeating: 0.1, count: 384))

        #expect(try store.count() == 1)
    }
}
