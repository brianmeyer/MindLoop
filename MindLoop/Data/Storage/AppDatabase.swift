//
//  AppDatabase.swift
//  MindLoop
//
//  GRDB-based storage layer replacing raw SQLiteManager.
//  Thread-safe via DatabaseQueue serialization.
//  Source: CLAUDE.md Storage layer + REC-260
//

import Foundation
import GRDB

// MARK: - AppDatabase

/// Thread-safe database manager using GRDB.
/// All access is serialized through `DatabaseQueue` — no data races.
final class AppDatabase: Sendable {

    /// The GRDB database queue (serializes all reads/writes)
    let dbQueue: DatabaseQueue

    /// Shared singleton for production use
    static let shared = makeShared()

    // MARK: - Initialization

    /// Creates a database at the given path.
    /// Use `:memory:` for test databases.
    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
    }

    /// Opens a production database in the app's Documents directory
    private static func makeShared() -> AppDatabase {
        do {
            let url = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("mindloop.db")

            var config = Configuration()
            config.foreignKeysEnabled = true
            config.prepareDatabase { db in
                db.trace { print("SQL: \($0)") }
            }

            let dbQueue = try DatabaseQueue(path: url.path, configuration: config)
            return try AppDatabase(dbQueue)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    /// Creates an in-memory database for testing
    static func makeEmpty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: {
            var config = Configuration()
            config.foreignKeysEnabled = true
            return config
        }())
        return try AppDatabase(dbQueue)
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // v1: Core tables
        migrator.registerMigration("v1_initial") { db in
            // Journal entries
            try db.create(table: "journalEntry") { t in
                t.primaryKey("id", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("text", .text).notNull()
                t.column("emotionLabel", .text).notNull()
                t.column("emotionConfidence", .double).notNull()
                t.column("emotionValence", .double).notNull()
                t.column("emotionArousal", .double).notNull()
                t.column("emotionProsodyFeatures", .text).notNull().defaults(to: "{}")
                t.column("tags", .text).notNull().defaults(to: "[]")
            }

            try db.create(index: "idx_journalEntry_timestamp", on: "journalEntry", columns: ["timestamp"])

            // Semantic chunks with embeddings
            try db.create(table: "semanticChunk") { t in
                t.primaryKey("id", .text).notNull()
                t.column("parentEntryId", .text).notNull()
                    .references("journalEntry", onDelete: .cascade)
                t.column("chunkIndex", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("startTime", .double).notNull().defaults(to: 0)
                t.column("endTime", .double).notNull().defaults(to: 0)
                t.column("dominantEmotion", .text).notNull()
                t.column("emotionConfidence", .double).notNull()
                t.column("valence", .double).notNull()
                t.column("arousal", .double).notNull()
                t.column("avgPitch", .double).notNull().defaults(to: 0)
                t.column("avgEnergy", .double).notNull().defaults(to: 0)
                t.column("avgSpeakingRate", .double).notNull().defaults(to: 0)
                t.column("tokenCount", .integer).notNull()
                t.column("embedding", .blob)
            }

            try db.create(index: "idx_semanticChunk_parent", on: "semanticChunk", columns: ["parentEntryId"])
            try db.create(index: "idx_semanticChunk_emotion", on: "semanticChunk", columns: ["dominantEmotion"])

            // Personalization profile
            try db.create(table: "personalizationProfile") { t in
                t.primaryKey("id", .text).notNull()
                t.column("tonePreference", .text).notNull().defaults(to: "warm")
                t.column("responseLength", .text).notNull().defaults(to: "medium")
                t.column("emotionTriggers", .text).notNull().defaults(to: "[]")
                t.column("avoidTopics", .text).notNull().defaults(to: "[]")
                t.column("preferredActions", .text).notNull().defaults(to: "[]")
                t.column("lastUpdated", .datetime).notNull()
            }

            // Schema version tracking
            try db.create(table: "schemaVersion") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("version", .integer).notNull()
                t.column("appliedAt", .datetime).notNull()
            }

            try db.execute(sql: """
                INSERT INTO schemaVersion (version, appliedAt) VALUES (1, datetime('now'))
            """)
        }

        // v2: Emotion graph tables
        migrator.registerMigration("v2_emotion_graph") { db in
            try db.create(table: "emotionNode") { t in
                t.primaryKey("id", .text).notNull()
                t.column("label", .text).notNull()
                t.column("category", .text).notNull()
                t.column("frequency", .integer).notNull().defaults(to: 1)
                t.column("lastSeen", .datetime).notNull()
            }

            try db.create(table: "emotionEdge") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("fromId", .text).notNull()
                    .references("emotionNode", onDelete: .cascade)
                t.column("toId", .text).notNull()
                    .references("emotionNode", onDelete: .cascade)
                t.column("weight", .double).notNull().defaults(to: 1.0)
                t.column("edgeType", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(index: "idx_emotionEdge_from", on: "emotionEdge", columns: ["fromId"])
            try db.create(index: "idx_emotionEdge_to", on: "emotionEdge", columns: ["toId"])
        }

        return migrator
    }
}

// MARK: - Journal Entry Operations

extension AppDatabase {
    /// Insert a journal entry
    func saveEntry(_ entry: JournalEntryRecord) throws {
        try dbQueue.write { db in
            try entry.save(db)
        }
    }

    /// Fetch all entries, newest first
    func fetchAllEntries() throws -> [JournalEntryRecord] {
        try dbQueue.read { db in
            try JournalEntryRecord
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    /// Fetch entries within a date range
    func fetchEntries(from start: Date, to end: Date) throws -> [JournalEntryRecord] {
        try dbQueue.read { db in
            try JournalEntryRecord
                .filter(Column("timestamp") >= start && Column("timestamp") <= end)
                .order(Column("timestamp").desc)
                .fetchAll(db)
        }
    }

    /// Fetch a single entry by ID
    func fetchEntry(id: String) throws -> JournalEntryRecord? {
        try dbQueue.read { db in
            try JournalEntryRecord.fetchOne(db, key: id)
        }
    }

    /// Delete an entry and its chunks (cascading)
    func deleteEntry(id: String) throws {
        try dbQueue.write { db in
            _ = try JournalEntryRecord.deleteOne(db, key: id)
        }
    }
}

// MARK: - Semantic Chunk Operations

extension AppDatabase {
    /// Save a chunk with its embedding
    func saveChunk(_ chunk: SemanticChunkRecord) throws {
        try dbQueue.write { db in
            try chunk.save(db)
        }
    }

    /// Save multiple chunks in a transaction
    func saveChunks(_ chunks: [SemanticChunkRecord]) throws {
        try dbQueue.write { db in
            for chunk in chunks {
                try chunk.save(db)
            }
        }
    }

    /// Fetch chunks for a given entry
    func fetchChunks(forEntry entryId: String) throws -> [SemanticChunkRecord] {
        try dbQueue.read { db in
            try SemanticChunkRecord
                .filter(Column("parentEntryId") == entryId)
                .order(Column("chunkIndex"))
                .fetchAll(db)
        }
    }

    /// Vector similarity search — brute force cosine similarity via SQL
    /// This will be replaced by sqlite-vec virtual table queries in a follow-up
    func findSimilarChunks(to query: [Float], k: Int = 10) throws -> [SemanticChunkRecord] {
        try dbQueue.read { db in
            // For now, fetch all chunks with embeddings and compute in Swift
            // sqlite-vec integration will replace this with a single SQL query
            let chunks = try SemanticChunkRecord
                .filter(Column("embedding") != nil)
                .fetchAll(db)

            // Compute cosine similarity in Swift
            let scored = chunks.compactMap { chunk -> (SemanticChunkRecord, Float)? in
                guard let embedding = chunk.embedding else { return nil }
                let vec = embeddingFromBlob(embedding)
                guard vec.count == query.count else { return nil }
                let sim = cosineSimilarity(query, vec)
                return (chunk, sim)
            }

            return scored
                .sorted { $0.1 > $1.1 }
                .prefix(k)
                .map(\.0)
        }
    }
}

// MARK: - Personalization Profile Operations

extension AppDatabase {
    /// Get or create the default profile
    func fetchProfile() throws -> PersonalizationProfileRecord {
        try dbQueue.read { db in
            if let profile = try PersonalizationProfileRecord.fetchOne(db, key: "default") {
                return profile
            }
            return PersonalizationProfileRecord.makeDefault()
        }
    }

    /// Save profile updates
    func saveProfile(_ profile: PersonalizationProfileRecord) throws {
        try dbQueue.write { db in
            try profile.save(db)
        }
    }
}

// MARK: - Helpers

private func embeddingFromBlob(_ data: Data) -> [Float] {
    data.withUnsafeBytes { buffer in
        Array(buffer.bindMemory(to: Float.self))
    }
}

private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    let denom = sqrt(normA) * sqrt(normB)
    return denom > 0 ? dot / denom : 0
}
