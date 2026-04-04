//
//  BM25Service.swift
//  MindLoop
//
//  BM25 lexical search fallback using GRDB + SQLite FTS5
//

import Foundation
import GRDB

/// BM25 lexical search service (fallback when vector search is unavailable or times out)
final class BM25Service: Sendable {

    private let database: AppDatabase

    /// Shared singleton for production
    static let shared = BM25Service(database: .shared)

    /// Injectable initializer for testing
    init(database: AppDatabase) {
        self.database = database
    }

    // BM25 parameters
    private let k1: Double = 1.5
    private let b: Double = 0.75

    // MARK: - Search

    /// Searches journal entries using BM25 via FTS5
    func search(
        query: String,
        k: Int = 5,
        recencyBoost: Double = 0.3
    ) throws -> [(entryId: String, score: Double)] {
        let sanitized = sanitizeQuery(query)
        guard !sanitized.isEmpty else { return [] }

        let now = Date().timeIntervalSince1970

        return try database.dbQueue.read { db in
            // Check if FTS table exists (it may not in test DBs without the trigger setup)
            let ftsExists = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='journalEntry_fts'
            """) ?? 0

            guard ftsExists > 0 else { return [] }

            let rows = try Row.fetchAll(db, sql: """
                SELECT fts.id,
                       bm25(journalEntry_fts, \(k1), \(b)) AS bm25_score,
                       j.timestamp
                FROM journalEntry_fts fts
                JOIN journalEntry j ON fts.id = j.id
                WHERE journalEntry_fts MATCH ?
                ORDER BY bm25_score
                LIMIT ?
            """, arguments: [sanitized, k * 2])

            var results: [(entryId: String, score: Double)] = []

            for row in rows {
                let entryId: String = row["id"]
                let bm25Score: Double = row["bm25_score"]
                let timestamp: Double = row["timestamp"]

                let normalizedBM25 = 1.0 / (1.0 + abs(bm25Score))
                let ageInDays = (now - timestamp) / 86400.0
                let recency = exp(-ageInDays / 30.0)
                let score = (1.0 - recencyBoost) * normalizedBM25 + recencyBoost * recency

                results.append((entryId, score))
            }

            results.sort { $0.score > $1.score }
            return Array(results.prefix(k))
        }
    }

    /// Searches by emotion label
    func searchByEmotion(
        label: EmotionSignal.Label,
        k: Int = 5
    ) throws -> [(entryId: String, score: Double)] {
        let now = Date().timeIntervalSince1970

        return try database.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, timestamp, emotionConfidence
                FROM journalEntry
                WHERE emotionLabel = ?
                ORDER BY timestamp DESC
                LIMIT ?
            """, arguments: [label.rawValue, k])

            return rows.map { row in
                let entryId: String = row["id"]
                let timestamp: Double = row["timestamp"]
                let confidence: Double = row["emotionConfidence"]

                let ageInDays = (now - timestamp) / 86400.0
                let recency = exp(-ageInDays / 30.0)
                let score = 0.7 * confidence + 0.3 * recency

                return (entryId, score)
            }
        }
    }

    // MARK: - Query Sanitization

    private func sanitizeQuery(_ query: String) -> String {
        let cleaned = query.replacingOccurrences(
            of: "[^a-zA-Z0-9\\s\"']", with: "", options: .regularExpression
        )
        let words = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return "" }
        return words.joined(separator: " OR ")
    }
}
