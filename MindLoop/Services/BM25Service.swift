//
//  BM25Service.swift
//  MindLoop
//
//  BM25 lexical search fallback using SQLite FTS5
//  Source: CLAUDE.md - BM25 fallback service
//

import Foundation
import SQLite3

/// BM25 lexical search service (fallback when embeddings unavailable)
final class BM25Service {
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = BM25Service()
    
    /// Database manager
    private let db = SQLiteManager.shared
    
    // BM25 parameters
    private let k1: Double = 1.5  // Term frequency saturation
    private let b: Double = 0.75   // Length normalization
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Search
    
    /// Searches journal entries using BM25 algorithm via FTS5
    /// - Parameters:
    ///   - query: Search query string
    ///   - k: Number of results to return
    ///   - recencyBoost: Weight for recency (0.0-1.0)
    /// - Returns: Array of (entryId, score) tuples sorted by score descending
    func search(
        query: String,
        k: Int = 5,
        recencyBoost: Double = 0.3
    ) throws -> [(entryId: String, score: Double)] {
        // Sanitize query for FTS5
        let sanitizedQuery = sanitizeQuery(query)
        
        guard !sanitizedQuery.isEmpty else {
            return []
        }
        
        // Use FTS5 BM25 ranking with custom parameters
        let sql = """
        SELECT 
            fts.id,
            bm25(journal_entries_fts, \(k1), \(b)) as bm25_score,
            j.timestamp
        FROM journal_entries_fts fts
        JOIN journal_entries j ON fts.id = j.id
        WHERE journal_entries_fts MATCH ?
        ORDER BY bm25_score
        LIMIT ?;
        """
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        try db.bind(statement, parameters: [sanitizedQuery, k * 2]) // Fetch 2x for recency filtering
        
        var results: [(entryId: String, score: Double)] = []
        let now = Date().timeIntervalSince1970
        
        while try db.step(statement) {
            guard let entryId = db.extractValue(from: statement, at: 0) as? String,
                  let bm25Score = db.extractValue(from: statement, at: 1) as? Double,
                  let timestamp = db.extractValue(from: statement, at: 2) as? Double else {
                continue
            }
            
            // BM25 scores are negative (lower = better match), normalize to positive
            let normalizedBM25 = 1.0 / (1.0 + abs(bm25Score))
            
            // Compute recency score (0-1, higher for recent entries)
            let ageInDays = (now - timestamp) / 86400.0
            let recency = exp(-ageInDays / 30.0) // Decay over 30 days
            
            // Combined score
            let score = (1.0 - recencyBoost) * normalizedBM25 + recencyBoost * recency
            
            results.append((entryId, score))
        }
        
        // Sort by combined score and take top K
        results.sort { $0.score > $1.score }
        return Array(results.prefix(k))
    }
    
    /// Searches by tags only
    func searchByTags(
        tags: [String],
        k: Int = 5
    ) throws -> [(entryId: String, score: Double)] {
        guard !tags.isEmpty else {
            return []
        }
        
        // Build SQL for tag matching
        let tagConditions = tags.map { _ in "tags LIKE ?" }.joined(separator: " OR ")
        let sql = """
        SELECT id, timestamp
        FROM journal_entries
        WHERE \(tagConditions)
        ORDER BY timestamp DESC
        LIMIT ?;
        """
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        var params: [Any?] = tags.map { "%\($0)%" }
        params.append(k)
        
        try db.bind(statement, parameters: params)
        
        var results: [(entryId: String, score: Double)] = []
        let now = Date().timeIntervalSince1970
        
        while try db.step(statement) {
            guard let entryId = db.extractValue(from: statement, at: 0) as? String,
                  let timestamp = db.extractValue(from: statement, at: 1) as? Double else {
                continue
            }
            
            // Score based on recency only (tag matching is binary)
            let ageInDays = (now - timestamp) / 86400.0
            let score = exp(-ageInDays / 30.0)
            
            results.append((entryId, score))
        }
        
        return results
    }
    
    /// Searches by emotion label
    func searchByEmotion(
        label: EmotionSignal.Label,
        k: Int = 5
    ) throws -> [(entryId: String, score: Double)] {
        let sql = """
        SELECT id, timestamp, emotion_confidence
        FROM journal_entries
        WHERE emotion_label = ?
        ORDER BY timestamp DESC
        LIMIT ?;
        """
        
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        
        try db.bind(statement, parameters: [label.rawValue, k])
        
        var results: [(entryId: String, score: Double)] = []
        let now = Date().timeIntervalSince1970
        
        while try db.step(statement) {
            guard let entryId = db.extractValue(from: statement, at: 0) as? String,
                  let timestamp = db.extractValue(from: statement, at: 1) as? Double,
                  let confidence = db.extractValue(from: statement, at: 2) as? Double else {
                continue
            }
            
            // Score based on recency and confidence
            let ageInDays = (now - timestamp) / 86400.0
            let recency = exp(-ageInDays / 30.0)
            let score = 0.7 * confidence + 0.3 * recency
            
            results.append((entryId, score))
        }
        
        return results
    }
    
    // MARK: - Query Sanitization
    
    /// Sanitizes query for FTS5 (removes special characters, handles phrases)
    private func sanitizeQuery(_ query: String) -> String {
        // Remove special FTS5 characters except quotes and spaces
        let cleaned = query.replacingOccurrences(of: "[^a-zA-Z0-9\\s\"']", with: "", options: .regularExpression)
        
        // Trim whitespace
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split into words
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard !words.isEmpty else {
            return ""
        }
        
        // Join with OR for broad matching (FTS5 syntax)
        return words.joined(separator: " OR ")
    }
}

// MARK: - Helper Extension

private extension SQLiteManager {
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
