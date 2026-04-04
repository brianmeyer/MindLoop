//
//  RetrievalAgent.swift
//  MindLoop
//
//  Fetches relevant past journal context for grounding CoachAgent responses.
//  Pipeline: query embedding → vector search (top-10 chunks) → group by entry →
//  rank by max chunk similarity → top-5 entries + best chunk + 1 CBTCard.
//  Falls back to BM25 lexical search if vector search fails or times out (50ms).
//  Source: CLAUDE.md - RetrievalAgent contract, REC-229
//

import Foundation

// MARK: - RetrievalAgent

/// Retrieves relevant past journal context using vector similarity search
/// with BM25 fallback. Returns top-5 entries with best matching chunks
/// and an optional CBT technique card.
struct RetrievalAgent: AgentProtocol, Sendable {

    // MARK: - AgentProtocol

    typealias Input = String
    typealias Output = RetrievalContext

    var name: String { "RetrievalAgent" }

    // MARK: - Dependencies

    /// Embedding function: takes query text, returns 384-dim vector.
    /// Injected as a closure so tests can substitute a deterministic stub.
    private let generateEmbedding: @Sendable (String) async throws -> [Float]

    private let vectorStore: VectorStore
    private let bm25Service: BM25Service
    private let database: AppDatabase

    /// Vector search timeout in nanoseconds (50ms)
    private let vectorSearchTimeoutNs: UInt64

    // MARK: - Initialization

    /// Production initializer using shared singletons
    init() {
        self.generateEmbedding = { text in
            try await EmbeddingAgent.shared.process(text)
        }
        self.vectorStore = .shared
        self.bm25Service = .shared
        self.database = .shared
        self.vectorSearchTimeoutNs = 50_000_000
    }

    /// Injectable initializer for testing
    init(
        generateEmbedding: @escaping @Sendable (String) async throws -> [Float],
        vectorStore: VectorStore,
        bm25Service: BM25Service,
        database: AppDatabase,
        vectorSearchTimeoutNs: UInt64 = 50_000_000
    ) {
        self.generateEmbedding = generateEmbedding
        self.vectorStore = vectorStore
        self.bm25Service = bm25Service
        self.database = database
        self.vectorSearchTimeoutNs = vectorSearchTimeoutNs
    }

    // MARK: - AgentProtocol Process

    /// Main retrieval pipeline: embed query → vector search → aggregate → return context.
    /// Falls back to BM25 if vector search fails or times out.
    func process(_ input: String) async throws -> RetrievalContext {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput("Query text cannot be empty")
        }

        // Step 1: Generate query embedding
        let queryEmbedding: [Float]
        do {
            queryEmbedding = try await generateEmbedding(input)
        } catch {
            // Embedding failed — fall back to BM25
            return try buildContextFromBM25(query: input)
        }

        // Step 2: Vector search with timeout, fall back to BM25
        let vectorResults: [(entryId: String, score: Double, chunkId: String)]
        do {
            vectorResults = try await withVectorSearchTimeout {
                try self.vectorStore.findSimilarChunks(
                    to: queryEmbedding,
                    k: 5,
                    chunkK: 10
                )
            }
        } catch {
            // Vector search failed or timed out — fall back to BM25
            return try buildContextFromBM25(query: input)
        }

        // If vector search returned nothing, fall back to BM25
        guard !vectorResults.isEmpty else {
            return try buildContextFromBM25(query: input)
        }

        // Step 3-5: Build context from vector results
        return try buildContext(from: vectorResults)
    }

    // MARK: - Quick Search (Real-Time)

    /// Lightweight search for real-time partial transcript matching.
    /// Uses BM25 for speed — no embedding generation overhead.
    /// Returns top-3 recent memories for live context preview.
    func quickSearch(partialTranscript: String) throws -> RetrievalContext {
        let trimmed = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }

        let bm25Results = try bm25Service.search(query: trimmed, k: 3)
        guard !bm25Results.isEmpty else {
            return .empty
        }

        return try buildContextFromBM25Results(bm25Results)
    }

    // MARK: - Private Helpers

    /// Runs vector search with a timeout. Throws on timeout.
    private func withVectorSearchTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: self.vectorSearchTimeoutNs)
                throw AgentError.timeout(agent: "RetrievalAgent", limitMs: 50)
            }

            // Return whichever finishes first
            guard let result = try await group.next() else {
                throw AgentError.processingFailed(
                    agent: "RetrievalAgent",
                    reason: "No result from vector search"
                )
            }
            group.cancelAll()
            return result
        }
    }

    /// Builds RetrievalContext from vector search results.
    /// Fetches parent entries and best chunks, selects a CBTCard.
    private func buildContext(
        from results: [(entryId: String, score: Double, chunkId: String)]
    ) throws -> RetrievalContext {
        var scoredEntries: [RetrievalContext.ScoredEntry] = []

        for result in results.prefix(5) {
            guard let entryRecord = try database.fetchEntry(id: result.entryId) else {
                continue
            }
            let entry = entryRecord.toDomain()

            // Find the best chunk
            let chunks = try database.fetchChunks(forEntry: result.entryId)
            guard let bestChunkRecord = chunks.first(where: { $0.id == result.chunkId }) else {
                continue
            }

            let bestChunk = Self.chunkRecordToDomain(bestChunkRecord)

            scoredEntries.append(RetrievalContext.ScoredEntry(
                entry: entry,
                bestChunk: bestChunk,
                similarity: Float(result.score)
            ))
        }

        let cbtCard = selectCBTCard(for: scoredEntries)

        return RetrievalContext(entries: scoredEntries, cbtCard: cbtCard)
    }

    /// Falls back to BM25 lexical search and builds context.
    private func buildContextFromBM25(query: String) throws -> RetrievalContext {
        let bm25Results = try bm25Service.search(query: query, k: 5)
        guard !bm25Results.isEmpty else {
            return .empty
        }
        return try buildContextFromBM25Results(bm25Results)
    }

    /// Builds context from BM25 result tuples.
    private func buildContextFromBM25Results(
        _ results: [(entryId: String, score: Double)]
    ) throws -> RetrievalContext {
        var scoredEntries: [RetrievalContext.ScoredEntry] = []

        for result in results {
            guard let entryRecord = try database.fetchEntry(id: result.entryId) else {
                continue
            }
            let entry = entryRecord.toDomain()

            // Get chunks for this entry; use first chunk as best
            let chunks = try database.fetchChunks(forEntry: result.entryId)
            let bestChunk: SemanticChunk
            if let firstChunk = chunks.first {
                bestChunk = Self.chunkRecordToDomain(firstChunk)
            } else {
                // No chunks — synthesize one from the entry text
                bestChunk = SemanticChunk(
                    parentEntryId: entry.id,
                    chunkIndex: 0,
                    text: entry.text,
                    startTime: 0,
                    endTime: 0,
                    dominantEmotion: entry.emotion.label,
                    emotionConfidence: Float(entry.emotion.confidence),
                    valence: Float(entry.emotion.valence),
                    arousal: Float(entry.emotion.arousal),
                    tokenCount: entry.text.components(separatedBy: .whitespaces).count
                )
            }

            scoredEntries.append(RetrievalContext.ScoredEntry(
                entry: entry,
                bestChunk: bestChunk,
                similarity: Float(result.score)
            ))
        }

        let cbtCard = selectCBTCard(for: scoredEntries)
        return RetrievalContext(entries: scoredEntries, cbtCard: cbtCard)
    }

    /// Selects a CBTCard based on the dominant emotion in retrieved entries.
    /// Returns nil if no entries are present.
    private func selectCBTCard(
        for entries: [RetrievalContext.ScoredEntry]
    ) -> CBTCard? {
        guard !entries.isEmpty else { return nil }

        // Count emotion labels across retrieved entries
        var emotionCounts: [EmotionSignal.Label: Int] = [:]
        for scored in entries {
            emotionCounts[scored.entry.emotion.label, default: 0] += 1
        }

        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral

        // Select a card that matches the dominant emotion pattern
        switch dominantEmotion {
        case .anxious:
            return .sampleReframing
        case .sad:
            return .sampleBehavioralActivation
        case .positive:
            return .sampleMindfulness
        case .neutral:
            return .sampleThoughtRecord
        }
    }

    /// Converts a SemanticChunkRecord to a SemanticChunk domain model.
    private static func chunkRecordToDomain(_ record: SemanticChunkRecord) -> SemanticChunk {
        SemanticChunk(
            parentEntryId: record.parentEntryId,
            chunkIndex: record.chunkIndex,
            text: record.text,
            startTime: record.startTime,
            endTime: record.endTime,
            dominantEmotion: EmotionSignal.Label(rawValue: record.dominantEmotion) ?? .neutral,
            emotionConfidence: Float(record.emotionConfidence),
            valence: Float(record.valence),
            arousal: Float(record.arousal),
            avgPitch: record.avgPitch > 0 ? Float(record.avgPitch) : nil,
            avgEnergy: record.avgEnergy > 0 ? Float(record.avgEnergy) : nil,
            avgSpeakingRate: record.avgSpeakingRate > 0 ? Float(record.avgSpeakingRate) : nil,
            tokenCount: record.tokenCount
        )
    }
}
