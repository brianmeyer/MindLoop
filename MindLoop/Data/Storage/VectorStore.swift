//
//  VectorStore.swift
//  MindLoop
//
//  Vector embedding storage and similarity search using GRDB.
//  Uses Accelerate-optimized cosine similarity for now.
//  Will migrate to sqlite-vec virtual tables in a follow-up.
//

import Foundation
import Accelerate
import GRDB

/// Manages vector embeddings and similarity search
final class VectorStore: Sendable {

    /// Expected embedding dimension (384 for gte-small)
    static let embeddingDimension = 384

    /// The database to use
    private let database: AppDatabase

    /// Shared singleton for production
    static let shared = VectorStore(database: .shared)

    /// Injectable initializer for testing
    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Storage

    /// Stores a chunk embedding with full metadata
    func storeChunkEmbedding(chunk: SemanticChunk, vector: [Float]) throws {
        guard vector.count == Self.embeddingDimension else {
            throw VectorStoreError.invalidDimension(
                expected: Self.embeddingDimension, got: vector.count
            )
        }

        let record = SemanticChunkRecord(from: chunk, embedding: vector)
        try database.saveChunk(record)
    }

    // MARK: - Similarity Search

    /// Finds the top K most similar entries using chunk-aware cosine similarity.
    /// Searches chunks, then aggregates by parent entry.
    func findSimilarChunks(
        to queryVector: [Float],
        k: Int = 5,
        chunkK: Int = 10,
        recencyBoost: Double = 0.3
    ) throws -> [(entryId: String, score: Double, chunkId: String)] {
        guard queryVector.count == Self.embeddingDimension else {
            throw VectorStoreError.invalidDimension(
                expected: Self.embeddingDimension, got: queryVector.count
            )
        }

        let normalizedQuery = Self.normalize(queryVector)
        let now = Date().timeIntervalSince1970

        return try database.dbQueue.read { db in
            // Fetch all chunks that have embeddings, joined with entry timestamps
            let rows = try Row.fetchAll(db, sql: """
                SELECT sc.id, sc.parentEntryId, sc.embedding, je.timestamp
                FROM semanticChunk sc
                JOIN journalEntry je ON sc.parentEntryId = je.id
                WHERE sc.embedding IS NOT NULL
            """)

            // Compute similarity for each chunk
            var chunkResults: [(chunkId: String, parentId: String, similarity: Double, timestamp: Double)] = []

            for row in rows {
                let chunkId: String = row["id"]
                let parentId: String = row["parentEntryId"]
                let timestamp: Double = row["timestamp"]

                guard let embeddingData: Data = row["embedding"] else { continue }
                let vector = Self.dataToVector(embeddingData)
                guard vector.count == Self.embeddingDimension else { continue }

                let normalizedVector = Self.normalize(vector)
                let similarity = Self.cosineSimilarity(normalizedQuery, normalizedVector)
                chunkResults.append((chunkId, parentId, similarity, timestamp))
            }

            // Sort by similarity, take top chunkK
            chunkResults.sort { $0.similarity > $1.similarity }
            let topChunks = chunkResults.prefix(chunkK)

            // Group by parent entry, keep best score per entry
            var entryScores: [String: (score: Double, chunkId: String)] = [:]

            for chunk in topChunks {
                let ageInDays = (now - chunk.timestamp) / 86400.0
                let recency = exp(-ageInDays / 30.0)
                let score = (1.0 - recencyBoost) * chunk.similarity + recencyBoost * recency

                if let existing = entryScores[chunk.parentId] {
                    if score > existing.score {
                        entryScores[chunk.parentId] = (score, chunk.chunkId)
                    }
                } else {
                    entryScores[chunk.parentId] = (score, chunk.chunkId)
                }
            }

            return entryScores
                .map { (entryId: $0.key, score: $0.value.score, chunkId: $0.value.chunkId) }
                .sorted { $0.score > $1.score }
                .prefix(k)
                .map { $0 }
        }
    }

    /// Returns the number of stored embeddings
    func count() throws -> Int {
        try database.dbQueue.read { db in
            try SemanticChunkRecord
                .filter(Column("embedding") != nil)
                .fetchCount(db)
        }
    }

    // MARK: - Vector Operations (Accelerate-optimized)

    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &magnitudeA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &magnitudeB, vDSP_Length(b.count))

        let magnitude = sqrt(magnitudeA * magnitudeB)
        guard magnitude > 0 else { return 0 }
        return Double(dotProduct / magnitude)
    }

    private static func normalize(_ vector: [Float]) -> [Float] {
        var result = vector
        var magnitude: Float = 0
        vDSP_svesq(vector, 1, &magnitude, vDSP_Length(vector.count))
        magnitude = sqrt(magnitude)
        guard magnitude > 0 else { return vector }
        vDSP_vsdiv(vector, 1, &magnitude, &result, 1, vDSP_Length(vector.count))
        return result
    }

    // MARK: - Serialization

    private static func dataToVector(_ data: Data) -> [Float] {
        data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}

// MARK: - Errors

extension VectorStore {
    enum VectorStoreError: Error, CustomStringConvertible {
        case invalidDimension(expected: Int, got: Int)
        case storageFailed(reason: String)
        case searchFailed(reason: String)

        var description: String {
            switch self {
            case .invalidDimension(let expected, let got):
                return "Invalid embedding dimension: expected \(expected), got \(got)"
            case .storageFailed(let reason):
                return "Failed to store embedding: \(reason)"
            case .searchFailed(let reason):
                return "Failed to search embeddings: \(reason)"
            }
        }
    }
}
