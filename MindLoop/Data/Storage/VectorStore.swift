//
//  VectorStore.swift
//  MindLoop
//
//  Vector embedding storage and similarity search
//  Uses SIMD-optimized cosine similarity via Accelerate framework
//  Source: CLAUDE.md - VectorStore service
//

import Foundation
import Accelerate
import SQLite3

/// Manages vector embeddings and similarity search
final class VectorStore {
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = VectorStore()
    
    /// Database manager
    private let db = SQLiteManager.shared

    /// Expected embedding dimension (462 for Qwen3-Embedding-0.6B)
    private let embeddingDimension = 462
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Storage

    /// Stores a chunk embedding with full metadata
    func storeChunkEmbedding(
        chunk: SemanticChunk,
        vector: [Float]
    ) throws {
        guard vector.count == embeddingDimension else {
            throw VectorStoreError.invalidDimension(expected: embeddingDimension, got: vector.count)
        }

        // Serialize vector to bytes
        let data = vectorToData(vector)

        let sql = """
        INSERT OR REPLACE INTO embeddings (
            id, parent_entry_id, chunk_index, text, vector, dimension,
            start_time, end_time,
            emotion_label, emotion_confidence, emotion_valence, emotion_arousal,
            avg_pitch, avg_energy, avg_speaking_rate, token_count, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }

        try db.bind(statement, parameters: [
            chunk.id,
            chunk.parentEntryId,
            chunk.chunkIndex,
            chunk.text,
            data,
            embeddingDimension,
            chunk.startTime,
            chunk.endTime,
            chunk.dominantEmotion.rawValue,
            chunk.emotionConfidence,
            chunk.valence,
            chunk.arousal,
            chunk.avgPitch,
            chunk.avgEnergy,
            chunk.avgSpeakingRate,
            chunk.tokenCount,
            chunk.createdAt.timeIntervalSince1970
        ])

        guard try db.step(statement) == false else {
            throw VectorStoreError.storageFailed(reason: "Expected DONE")
        }
    }

    /// Stores an embedding for a journal entry (legacy, for backwards compatibility)
    @available(*, deprecated, message: "Use storeChunkEmbedding instead")
    func storeEmbedding(
        entryId: String,
        vector: [Float],
        type: EmbeddingType
    ) throws {
        guard vector.count == embeddingDimension else {
            throw VectorStoreError.invalidDimension(expected: embeddingDimension, got: vector.count)
        }

        // For legacy support, create a single chunk
        // This will be migrated to chunk-aware storage
        let data = vectorToData(vector)

        let sql = """
        INSERT OR REPLACE INTO embeddings (
            id, parent_entry_id, chunk_index, text, vector, dimension,
            emotion_label, emotion_confidence, emotion_valence, emotion_arousal,
            token_count
        )
        SELECT
            ? || '_chunk-0',
            ?,
            0,
            text,
            ?,
            ?,
            emotion_label,
            emotion_confidence,
            emotion_valence,
            emotion_arousal,
            CAST((LENGTH(text) - LENGTH(REPLACE(text, ' ', '')) + 1) / 0.75 AS INTEGER)
        FROM journal_entries
        WHERE id = ?;
        """

        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }

        try db.bind(statement, parameters: [
            entryId,
            entryId,
            data,
            embeddingDimension,
            entryId
        ])

        guard try db.step(statement) == false else {
            throw VectorStoreError.storageFailed(reason: "Expected DONE")
        }
    }
    
    /// Retrieves an embedding for a journal entry
    func fetchEmbedding(entryId: String, type: EmbeddingType) throws -> [Float]? {
        let sql = """
        SELECT vector FROM embeddings
        WHERE entry_id = ? AND embedding_type = ?;
        """
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        try db.bind(statement, parameters: [entryId, type.rawValue])
        
        guard try db.step(statement) else {
            return nil // No embedding found
        }
        
        guard let data = db.extractValue(from: statement, at: 0) as? Data else {
            return nil
        }
        
        return dataToVector(data)
    }
    
    /// Deletes an embedding
    func deleteEmbedding(entryId: String, type: EmbeddingType) throws {
        let sql = "DELETE FROM embeddings WHERE entry_id = ? AND embedding_type = ?;"
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        try db.bind(statement, parameters: [entryId, type.rawValue])
        _ = try db.step(statement)
    }
    
    // MARK: - Similarity Search

    /// Finds the top K most similar entries using chunk-aware cosine similarity
    /// Searches chunks, then aggregates by parent entry
    /// - Parameters:
    ///   - queryVector: Query embedding vector
    ///   - k: Number of parent entries to return (default: 5)
    ///   - chunkK: Number of chunks to consider before aggregation (default: 10)
    ///   - recencyBoost: Weight for recency (0.0-1.0). If 0.3, score = 0.7*similarity + 0.3*recency
    /// - Returns: Array of (entryId, score, bestChunkId) tuples sorted by score descending
    func findSimilarChunks(
        to queryVector: [Float],
        k: Int = 5,
        chunkK: Int = 10,
        recencyBoost: Double = 0.3
    ) throws -> [(entryId: String, score: Double, chunkId: String)] {
        guard queryVector.count == embeddingDimension else {
            throw VectorStoreError.invalidDimension(expected: embeddingDimension, got: queryVector.count)
        }

        // Fetch all chunks with their parent entry timestamps
        let sql = """
        SELECT e.id, e.parent_entry_id, e.vector, j.timestamp
        FROM embeddings e
        JOIN journal_entries j ON e.parent_entry_id = j.id;
        """

        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }

        var chunkResults: [(chunkId: String, parentId: String, similarity: Double, timestamp: Double)] = []
        let now = Date().timeIntervalSince1970

        // Normalize query vector once
        let normalizedQuery = normalize(queryVector)

        while try db.step(statement) {
            guard let chunkId = db.extractValue(from: statement, at: 0) as? String,
                  let parentId = db.extractValue(from: statement, at: 1) as? String,
                  let vectorData = db.extractValue(from: statement, at: 2) as? Data,
                  let timestamp = db.extractValue(from: statement, at: 3) as? Double else {
                continue
            }

            let vector = dataToVector(vectorData)
            let normalizedVector = normalize(vector)

            // Compute cosine similarity
            let similarity = cosineSimilarity(normalizedQuery, normalizedVector)

            chunkResults.append((chunkId, parentId, similarity, timestamp))
        }

        // Sort chunks by similarity descending
        chunkResults.sort { $0.similarity > $1.similarity }

        // Take top chunkK chunks
        let topChunks = Array(chunkResults.prefix(chunkK))

        // Group chunks by parent entry and take max similarity
        var entryScores: [String: (score: Double, chunkId: String, timestamp: Double)] = [:]

        for chunk in topChunks {
            let ageInDays = (now - chunk.timestamp) / 86400.0
            let recency = exp(-ageInDays / 30.0) // Decay over 30 days

            // Combined score
            let score = (1.0 - recencyBoost) * chunk.similarity + recencyBoost * recency

            // Keep the best chunk for each parent entry
            if let existing = entryScores[chunk.parentId] {
                if score > existing.score {
                    entryScores[chunk.parentId] = (score, chunk.chunkId, chunk.timestamp)
                }
            } else {
                entryScores[chunk.parentId] = (score, chunk.chunkId, chunk.timestamp)
            }
        }

        // Convert to array and sort by score
        var results = entryScores.map { (entryId: $0.key, score: $0.value.score, chunkId: $0.value.chunkId) }
        results.sort { $0.score > $1.score }

        return Array(results.prefix(k))
    }

    /// Legacy search method (backwards compatibility)
    /// - Note: This method is deprecated. Use findSimilarChunks for chunk-aware search
    @available(*, deprecated, message: "Use findSimilarChunks instead")
    func findSimilar(
        to queryVector: [Float],
        type: EmbeddingType,
        k: Int = 5,
        recencyBoost: Double = 0.3
    ) throws -> [(entryId: String, score: Double)] {
        // Delegate to chunk-aware search and return only entryId and score
        let results = try findSimilarChunks(to: queryVector, k: k, recencyBoost: recencyBoost)
        return results.map { (entryId: $0.entryId, score: $0.score) }
    }
    
    // MARK: - Vector Operations (SIMD-optimized via Accelerate)
    
    /// Computes cosine similarity between two vectors using Accelerate framework
    /// Returns value in range [-1, 1] where 1 = identical, 0 = orthogonal, -1 = opposite
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        assert(a.count == b.count, "Vectors must have same dimension")
        
        var dotProduct: Float = 0.0
        var magnitudeA: Float = 0.0
        var magnitudeB: Float = 0.0
        
        // Use Accelerate for SIMD optimization
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &magnitudeA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &magnitudeB, vDSP_Length(b.count))
        
        let magnitude = sqrt(magnitudeA * magnitudeB)
        
        guard magnitude > 0 else {
            return 0.0
        }
        
        return Double(dotProduct / magnitude)
    }
    
    /// Normalizes a vector to unit length
    private func normalize(_ vector: [Float]) -> [Float] {
        var result = vector
        var magnitude: Float = 0.0
        
        vDSP_svesq(vector, 1, &magnitude, vDSP_Length(vector.count))
        magnitude = sqrt(magnitude)
        
        guard magnitude > 0 else {
            return vector
        }
        
        vDSP_vsdiv(vector, 1, &magnitude, &result, 1, vDSP_Length(vector.count))
        
        return result
    }
    
    // MARK: - Serialization
    
    /// Converts a vector to Data for storage
    private func vectorToData(_ vector: [Float]) -> Data {
        var mutableVector = vector
        return Data(bytes: &mutableVector, count: vector.count * MemoryLayout<Float>.size)
    }
    
    /// Converts Data back to a vector
    private func dataToVector(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var vector = [Float](repeating: 0.0, count: count)
        
        data.withUnsafeBytes { bytes in
            vector.withUnsafeMutableBytes { output in
                output.copyBytes(from: bytes)
            }
        }
        
        return vector
    }
    
    // MARK: - Statistics
    
    /// Returns the number of embeddings stored
    func count(type: EmbeddingType? = nil) throws -> Int {
        let sql: String
        let params: [Any?]
        
        if let type = type {
            sql = "SELECT COUNT(*) FROM embeddings WHERE embedding_type = ?;"
            params = [type.rawValue]
        } else {
            sql = "SELECT COUNT(*) FROM embeddings;"
            params = []
        }
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        if !params.isEmpty {
            try db.bind(statement, parameters: params)
        }
        
        guard try db.step(statement),
              let count = db.extractValue(from: statement, at: 0) as? Int64 else {
            return 0
        }
        
        return Int(count)
    }
}

// MARK: - Types

extension VectorStore {
    /// Embedding type
    enum EmbeddingType: String {
        case qwen3 = "qwen3"       // Qwen3-Embedding-0.6B (462-dim, <200ms)
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

// MARK: - Helper Extension for SQLiteManager

private extension SQLiteManager {
    /// Extracts a value from a statement (made accessible for VectorStore)
    func extractValue(from statement: OpaquePointer, at index: Int32) -> Any? {
        let type = sqlite3_column_type(statement, index)
        
        switch type {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(statement, index))
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(statement, index)
            let length = sqlite3_column_bytes(statement, index)
            return Data(bytes: bytes!, count: Int(length))
        case SQLITE_NULL:
            return nil
        default:
            return nil
        }
    }
}
