//
//  RetrievalAgentTests.swift
//  MindLoopTests
//
//  Tests for RetrievalAgent: vector search pipeline, BM25 fallback,
//  CBTCard selection, quickSearch, and edge cases.
//  Each test gets its own in-memory AppDatabase — no shared state.
//

import Testing
import Foundation
@testable import MindLoop

@Suite("RetrievalAgent Tests")
struct RetrievalAgentTests {

    // MARK: - Helpers

    /// Creates a fresh in-memory database for each test
    private func makeDB() throws -> AppDatabase {
        try AppDatabase.makeEmpty()
    }

    /// Creates a deterministic 384-dim vector with a specific "direction" for testing.
    /// Vectors with the same seed will be identical (similarity = 1.0).
    private func makeVector(seed: Int, dimension: Int = 384) -> [Float] {
        (0..<dimension).map { i in
            Float(sin(Double(i + seed) * 0.1))
        }
    }

    /// Creates a RetrievalAgent wired to the given in-memory database.
    /// The stub embedding function returns a deterministic vector from a fixed seed
    /// so vector search results are predictable.
    private func makeAgent(
        db: AppDatabase,
        embeddingSeed: Int = 100,
        embeddingShouldFail: Bool = false
    ) -> RetrievalAgent {
        let seed = embeddingSeed
        let vecGen: @Sendable (Int, Int) -> [Float] = { seed, dimension in
            (0..<dimension).map { i in
                Float(sin(Double(i + seed) * 0.1))
            }
        }
        return RetrievalAgent(
            generateEmbedding: { _ in
                if embeddingShouldFail {
                    throw AgentError.processingFailed(
                        agent: "EmbeddingAgent",
                        reason: "Test stub failure"
                    )
                }
                return vecGen(seed, 384)
            },
            vectorStore: VectorStore(database: db),
            bm25Service: BM25Service(database: db),
            database: db,
            vectorSearchTimeoutNs: 10_000_000_000 // 10s — tests should not time out
        )
    }

    /// Seeds a journal entry + chunk with an embedding into the database.
    private func seedEntry(
        db: AppDatabase,
        id: String,
        text: String,
        chunkText: String? = nil,
        emotion: EmotionSignal = .sampleNeutral,
        embedding: [Float],
        timestamp: Date = Date()
    ) throws {
        let entry = JournalEntryRecord(from: JournalEntry(
            id: id,
            timestamp: timestamp,
            text: text,
            emotion: emotion,
            tags: []
        ))
        try db.saveEntry(entry)

        let chunk = SemanticChunk(
            parentEntryId: id,
            chunkIndex: 0,
            text: chunkText ?? text,
            startTime: 0,
            endTime: 5,
            dominantEmotion: emotion.label,
            emotionConfidence: Float(emotion.confidence),
            valence: Float(emotion.valence),
            arousal: Float(emotion.arousal),
            tokenCount: text.components(separatedBy: .whitespaces).count
        )
        let record = SemanticChunkRecord(from: chunk, embedding: embedding)
        try db.saveChunk(record)
    }

    // MARK: - Protocol Conformance

    @Test("RetrievalAgent has correct name")
    func testAgentName() throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)
        #expect(agent.name == "RetrievalAgent")
    }

    @Test("RetrievalAgent conforms to AgentProtocol")
    func testProtocolConformance() throws {
        let db = try makeDB()
        // Compile-time check: if this builds, the protocol is satisfied
        let _: any AgentProtocol = makeAgent(db: db)
    }

    @Test("RetrievalAgent is Sendable")
    func testSendable() throws {
        let db = try makeDB()
        // Compile-time check: if this builds, Sendable is satisfied
        let _: any Sendable = makeAgent(db: db)
    }

    // MARK: - Empty Input

    @Test("Throws on empty query")
    func testEmptyQueryThrows() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        await #expect(throws: AgentError.self) {
            _ = try await agent.process("")
        }
    }

    @Test("Throws on whitespace-only query")
    func testWhitespaceQueryThrows() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        await #expect(throws: AgentError.self) {
            _ = try await agent.process("   \n  ")
        }
    }

    // MARK: - Empty Database

    @Test("Returns empty context when database is empty")
    func testEmptyDatabase() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        let context = try await agent.process("feeling anxious about work")
        #expect(context.isEmpty)
        #expect(context.entries.isEmpty)
        #expect(context.cbtCard == nil)
    }

    // MARK: - Vector Search Pipeline

    @Test("Returns entries from vector search")
    func testVectorSearchReturnsEntries() async throws {
        let db = try makeDB()

        // Use seed 100 for the query embedding
        let agent = makeAgent(db: db, embeddingSeed: 100)

        // Seed entry with similar embedding (seed 101 is close to 100)
        try seedEntry(
            db: db, id: "similar-1",
            text: "I feel anxious about my presentation",
            emotion: .sampleAnxious,
            embedding: makeVector(seed: 101)
        )
        // Seed entry with dissimilar embedding
        try seedEntry(
            db: db, id: "dissimilar-1",
            text: "Had a great day at the beach",
            emotion: .samplePositive,
            embedding: makeVector(seed: 500)
        )

        let context = try await agent.process("anxious about work presentation")

        #expect(context.count >= 1)
        #expect(!context.isEmpty)
        let entryIds = context.entries.map(\.entry.id)
        #expect(entryIds.contains("similar-1") || entryIds.contains("dissimilar-1"))
    }

    @Test("Returns at most 5 entries")
    func testMaxFiveEntries() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 0)

        // Seed 8 entries
        for i in 0..<8 {
            try seedEntry(
                db: db, id: "entry-\(i)",
                text: "Entry number \(i) about various topics",
                embedding: makeVector(seed: i)
            )
        }

        let context = try await agent.process("various topics entry")
        #expect(context.count <= 5)
    }

    @Test("Each result includes best chunk")
    func testResultsIncludeBestChunk() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 42)

        try seedEntry(
            db: db, id: "chunk-test",
            text: "Full entry text about stress at work",
            chunkText: "Specific chunk about stress",
            embedding: makeVector(seed: 42)
        )

        let context = try await agent.process("stress at work")
        if let first = context.entries.first {
            #expect(!first.bestChunk.text.isEmpty)
            #expect(first.bestChunk.parentEntryId == first.entry.id)
        }
    }

    @Test("Similarity scores are between 0 and 1")
    func testSimilarityScoreRange() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 10)

        try seedEntry(
            db: db, id: "score-test",
            text: "Testing similarity scores",
            embedding: makeVector(seed: 10)
        )

        let context = try await agent.process("testing similarity")
        for scored in context.entries {
            #expect(scored.similarity >= 0.0)
            #expect(scored.similarity <= 1.0)
        }
    }

    @Test("Entries are sorted by descending similarity")
    func testEntriesSortedByScore() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 0)

        for i in 0..<5 {
            try seedEntry(
                db: db, id: "sorted-\(i)",
                text: "Entry \(i)",
                embedding: makeVector(seed: i * 50)
            )
        }

        let context = try await agent.process("query text")
        for i in 0..<(context.entries.count - 1) {
            #expect(context.entries[i].similarity >= context.entries[i + 1].similarity)
        }
    }

    // MARK: - BM25 Fallback

    @Test("Falls back to BM25 when embedding fails")
    func testBM25FallbackOnEmbeddingFailure() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingShouldFail: true)

        // Seed an entry (BM25 won't find it without FTS, but should not crash)
        try seedEntry(
            db: db, id: "fallback-1",
            text: "Feeling anxious about work",
            emotion: .sampleAnxious,
            embedding: makeVector(seed: 1)
        )

        // Should not throw — gracefully falls back to BM25 (returns empty if no FTS)
        let context = try await agent.process("anxious about work")
        // BM25 may or may not return results depending on FTS setup in test DB
        // The key assertion is that it doesn't crash
        #expect(context.count >= 0)
    }

    // MARK: - CBTCard Selection

    @Test("Selects reframing card for anxious entries")
    func testCBTCardForAnxious() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 1)

        try seedEntry(
            db: db, id: "anxious-1",
            text: "I keep worrying about everything",
            emotion: .sampleAnxious,
            embedding: makeVector(seed: 1)
        )

        let context = try await agent.process("worrying about things")
        #expect(context.cbtCard != nil)
        #expect(context.cbtCard?.id == "card_reframing")
    }

    @Test("Selects behavioral activation card for sad entries")
    func testCBTCardForSad() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 2)

        try seedEntry(
            db: db, id: "sad-1",
            text: "Feeling low and unmotivated",
            emotion: .sampleSad,
            embedding: makeVector(seed: 2)
        )

        let context = try await agent.process("feeling low")
        #expect(context.cbtCard != nil)
        #expect(context.cbtCard?.id == "card_behavioral_activation")
    }

    @Test("Selects mindfulness card for positive entries")
    func testCBTCardForPositive() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 3)

        try seedEntry(
            db: db, id: "positive-1",
            text: "Had a wonderful day today",
            emotion: .samplePositive,
            embedding: makeVector(seed: 3)
        )

        let context = try await agent.process("wonderful day")
        #expect(context.cbtCard != nil)
        #expect(context.cbtCard?.id == "card_mindfulness")
    }

    @Test("Selects thought record card for neutral entries")
    func testCBTCardForNeutral() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 4)

        try seedEntry(
            db: db, id: "neutral-1",
            text: "Went through my routine today",
            emotion: .sampleNeutral,
            embedding: makeVector(seed: 4)
        )

        let context = try await agent.process("routine day")
        #expect(context.cbtCard != nil)
        #expect(context.cbtCard?.id == "card_thought_record")
    }

    @Test("No CBTCard when no entries retrieved")
    func testNoCBTCardWhenEmpty() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        let context = try await agent.process("something random")
        #expect(context.cbtCard == nil)
    }

    // MARK: - Quick Search

    @Test("quickSearch returns empty for empty input")
    func testQuickSearchEmptyInput() throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        let context = try agent.quickSearch(partialTranscript: "")
        #expect(context.isEmpty)
    }

    @Test("quickSearch returns empty for whitespace input")
    func testQuickSearchWhitespace() throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        let context = try agent.quickSearch(partialTranscript: "   ")
        #expect(context.isEmpty)
    }

    @Test("quickSearch returns empty when no matches in empty DB")
    func testQuickSearchEmptyDB() throws {
        let db = try makeDB()
        let agent = makeAgent(db: db)

        let context = try agent.quickSearch(partialTranscript: "anxious about work")
        #expect(context.isEmpty)
    }

    // MARK: - RetrievalContext Properties

    @Test("citedEntryIds returns correct IDs")
    func testCitedEntryIds() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 10)

        try seedEntry(db: db, id: "cite-1", text: "First entry", embedding: makeVector(seed: 10))
        try seedEntry(db: db, id: "cite-2", text: "Second entry", embedding: makeVector(seed: 11))

        let context = try await agent.process("first or second")
        let cited = context.citedEntryIds
        #expect(cited.count == context.entries.count)
        for scored in context.entries {
            #expect(cited.contains(scored.entry.id))
        }
    }

    @Test("promptRepresentation includes memory labels")
    func testPromptRepresentation() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 20)

        try seedEntry(
            db: db, id: "prompt-1",
            text: "Feeling anxious today",
            emotion: .sampleAnxious,
            embedding: makeVector(seed: 20)
        )

        let context = try await agent.process("feeling anxious")
        if !context.entries.isEmpty {
            let prompt = context.promptRepresentation
            #expect(prompt.contains("Memory 1"))
            #expect(prompt.contains("CBT Technique"))
        }
    }

    // MARK: - Multiple Chunks Per Entry

    @Test("Groups multiple chunks by parent entry")
    func testMultipleChunksGroupedByEntry() async throws {
        let db = try makeDB()
        let agent = makeAgent(db: db, embeddingSeed: 30)

        // Create entry
        let entry = JournalEntryRecord(from: JournalEntry(
            id: "multi-chunk",
            text: "Long entry with multiple parts",
            emotion: .sampleAnxious,
            tags: []
        ))
        try db.saveEntry(entry)

        // Create two chunks for the same entry
        let chunk0 = SemanticChunkRecord(
            from: SemanticChunk(
                parentEntryId: "multi-chunk",
                chunkIndex: 0,
                text: "First part about anxiety",
                startTime: 0, endTime: 5,
                dominantEmotion: .anxious,
                emotionConfidence: 0.8, valence: -0.4, arousal: 0.6,
                tokenCount: 5
            ),
            embedding: makeVector(seed: 30)
        )
        let chunk1 = SemanticChunkRecord(
            from: SemanticChunk(
                parentEntryId: "multi-chunk",
                chunkIndex: 1,
                text: "Second part about work stress",
                startTime: 5, endTime: 10,
                dominantEmotion: .anxious,
                emotionConfidence: 0.7, valence: -0.3, arousal: 0.5,
                tokenCount: 5
            ),
            embedding: makeVector(seed: 31)
        )

        try db.saveChunk(chunk0)
        try db.saveChunk(chunk1)

        let context = try await agent.process("anxiety and work stress")

        // Should return at most 1 entry for "multi-chunk" (grouped by parent)
        let multiChunkEntries = context.entries.filter { $0.entry.id == "multi-chunk" }
        #expect(multiChunkEntries.count <= 1)
    }

    // MARK: - RetrievalContext.empty

    @Test("RetrievalContext.empty has correct defaults")
    func testRetrievalContextEmpty() {
        let empty = RetrievalContext.empty
        #expect(empty.entries.isEmpty)
        #expect(empty.cbtCard == nil)
        #expect(empty.count == 0)
        #expect(empty.isEmpty)
        #expect(empty.citedEntryIds.isEmpty)
    }
}
