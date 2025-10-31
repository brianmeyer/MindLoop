//
//  SQLiteManager.swift
//  MindLoop
//
//  Core SQLite database manager with CRUD operations
//  Source: CLAUDE.md - Storage layer
//

import Foundation
import SQLite3

/// Manages SQLite database connection and operations
final class SQLiteManager {
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = SQLiteManager()
    
    /// SQLite database pointer
    private var db: OpaquePointer?
    
    /// Database file URL
    private let databaseURL: URL
    
    /// Current schema version
    private let currentSchemaVersion = 1
    
    // MARK: - Initialization
    
    private init() {
        // Use app's Documents directory for database
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        databaseURL = paths[0].appendingPathComponent("mindloop.db")
        
        print("📁 Database location: \(databaseURL.path)")
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Lifecycle
    
    /// Opens database connection and runs migrations
    func openDatabase() throws {
        guard db == nil else {
            print("⚠️ Database already open")
            return
        }
        
        // Open database (creates if doesn't exist)
        let result = sqlite3_open(databaseURL.path, &db)
        guard result == SQLITE_OK else {
            throw DatabaseError.openFailed(code: result, message: String(cString: sqlite3_errmsg(db)))
        }
        
        print("✅ Database opened successfully")
        
        // Enable foreign keys
        try execute("PRAGMA foreign_keys = ON;")
        
        // Run migrations
        try runMigrations()
    }
    
    /// Closes database connection
    func closeDatabase() {
        guard db != nil else { return }
        
        sqlite3_close(db)
        db = nil
        print("🔒 Database closed")
    }
    
    // MARK: - Migrations
    
    /// Runs pending database migrations
    private func runMigrations() throws {
        let appliedVersion = try getSchemaVersion()
        
        guard appliedVersion < currentSchemaVersion else {
            print("✅ Schema up to date (version \(appliedVersion))")
            return
        }
        
        print("🔄 Running migrations from version \(appliedVersion) to \(currentSchemaVersion)")
        
        // Run migration 001 if needed
        if appliedVersion < 1 {
            try runMigration001()
        }
        
        print("✅ Migrations complete")
    }
    
    /// Gets current schema version from database
    private func getSchemaVersion() throws -> Int {
        // Check if schema_version table exists
        let tableExists = try queryScalar(
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='schema_version';"
        ) as? Int64 ?? 0
        
        guard tableExists > 0 else {
            return 0 // No schema yet
        }
        
        // Get latest version
        let version = try queryScalar("SELECT MAX(version) FROM schema_version;") as? Int64 ?? 0
        return Int(version)
    }
    
    /// Runs migration 001 (initial schema)
    private func runMigration001() throws {
        guard let migrationURL = Bundle.main.url(forResource: "001_initial_schema", withExtension: "sql", subdirectory: "Data/Storage/Migrations") else {
            throw DatabaseError.migrationFailed(version: 1, reason: "Migration file not found")
        }
        
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)
        try execute(sql)
        
        print("✅ Migration 001 applied")
    }
    
    // MARK: - Core Operations
    
    /// Executes a SQL statement (no return value)
    @discardableResult
    func execute(_ sql: String) throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw DatabaseError.executeFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        
        return Int(sqlite3_changes(db))
    }
    
    /// Executes a query and returns a single scalar value
    func queryScalar(_ sql: String) throws -> Any? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        
        return extractValue(from: statement!, at: 0)
    }
    
    /// Executes a query and returns all rows
    func query(_ sql: String) throws -> [[String: Any]] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        
        var rows: [[String: Any]] = []
        let columnCount = sqlite3_column_count(statement)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                row[columnName] = extractValue(from: statement!, at: i)
            }
            
            rows.append(row)
        }
        
        return rows
    }
    
    /// Extracts a value from a statement at the given column index
    private func extractValue(from statement: OpaquePointer, at index: Int32) -> Any? {
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
    
    // MARK: - Transaction Support
    
    /// Executes a block within a transaction
    func transaction<T>(_ block: () throws -> T) throws -> T {
        try execute("BEGIN TRANSACTION;")
        
        do {
            let result = try block()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }
    
    // MARK: - Prepared Statements
    
    /// Prepares a statement for efficient repeated execution
    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        
        return statement!
    }
    
    /// Binds parameters to a prepared statement
    func bind(_ statement: OpaquePointer, parameters: [Any?]) throws {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        
        for (index, value) in parameters.enumerated() {
            let sqlIndex = Int32(index + 1)
            
            switch value {
            case let intValue as Int:
                sqlite3_bind_int64(statement, sqlIndex, Int64(intValue))
            case let int64Value as Int64:
                sqlite3_bind_int64(statement, sqlIndex, int64Value)
            case let doubleValue as Double:
                sqlite3_bind_double(statement, sqlIndex, doubleValue)
            case let stringValue as String:
                sqlite3_bind_text(statement, sqlIndex, stringValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let dataValue as Data:
                dataValue.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, sqlIndex, bytes.baseAddress, Int32(dataValue.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case .none:
                sqlite3_bind_null(statement, sqlIndex)
            default:
                throw DatabaseError.bindFailed(reason: "Unsupported parameter type: \(type(of: value))")
            }
        }
    }
    
    /// Steps through a prepared statement
    func step(_ statement: OpaquePointer) throws -> Bool {
        let result = sqlite3_step(statement)
        
        switch result {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw DatabaseError.stepFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }
    
    /// Finalizes a prepared statement
    func finalize(_ statement: OpaquePointer) {
        sqlite3_finalize(statement)
    }
}

// MARK: - Errors

extension SQLiteManager {
    enum DatabaseError: Error, CustomStringConvertible {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case executeFailed(sql: String, message: String)
        case bindFailed(reason: String)
        case stepFailed(message: String)
        case migrationFailed(version: Int, reason: String)
        
        var description: String {
            switch self {
            case .openFailed(let code, let message):
                return "Failed to open database (code \(code)): \(message)"
            case .prepareFailed(let sql, let message):
                return "Failed to prepare statement '\(sql)': \(message)"
            case .executeFailed(let sql, let message):
                return "Failed to execute '\(sql)': \(message)"
            case .bindFailed(let reason):
                return "Failed to bind parameter: \(reason)"
            case .stepFailed(let message):
                return "Failed to step through statement: \(message)"
            case .migrationFailed(let version, let reason):
                return "Migration \(version) failed: \(reason)"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SQLiteManager {
    /// Inserts a journal entry
    func insertJournalEntry(_ entry: JournalEntry) throws {
        let sql = """
        INSERT INTO journal_entries (id, timestamp, text, emotion_label, emotion_confidence, emotion_valence, emotion_arousal, tags)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        let statement = try prepare(sql)
        defer { finalize(statement) }
        
        try bind(statement, parameters: [
            entry.id,
            entry.timestamp.timeIntervalSince1970,
            entry.text,
            entry.emotion.label.rawValue,
            entry.emotion.confidence,
            entry.emotion.valence,
            entry.emotion.arousal,
            entry.tags.joined(separator: ",")
        ])
        
        guard try step(statement) == false else {
            throw DatabaseError.executeFailed(sql: sql, message: "Expected DONE")
        }
    }
    
    /// Fetches all journal entries
    func fetchAllJournalEntries() throws -> [JournalEntry] {
        let sql = """
        SELECT id, timestamp, text, emotion_label, emotion_confidence, emotion_valence, emotion_arousal, tags
        FROM journal_entries
        ORDER BY timestamp DESC;
        """
        
        let rows = try query(sql)
        return try rows.map { row in
            try parseJournalEntry(from: row)
        }
    }
    
    /// Parses a JournalEntry from a database row
    private func parseJournalEntry(from row: [String: Any]) throws -> JournalEntry {
        guard let id = row["id"] as? String,
              let timestamp = row["timestamp"] as? Double,
              let text = row["text"] as? String,
              let emotionLabelRaw = row["emotion_label"] as? String,
              let emotionLabel = EmotionSignal.Label(rawValue: emotionLabelRaw),
              let confidence = row["emotion_confidence"] as? Double,
              let valence = row["emotion_valence"] as? Double,
              let arousal = row["emotion_arousal"] as? Double else {
            throw DatabaseError.executeFailed(sql: "parse", message: "Invalid row data")
        }
        
        let tagsString = row["tags"] as? String ?? ""
        let tags = tagsString.isEmpty ? [] : tagsString.split(separator: ",").map(String.init)
        
        let emotion = EmotionSignal(
            label: emotionLabel,
            confidence: confidence,
            valence: valence,
            arousal: arousal,
            prosodyFeatures: [:]
        )
        
        return JournalEntry(
            id: id,
            timestamp: Date(timeIntervalSince1970: timestamp),
            text: text,
            emotion: emotion,
            embeddings: nil,
            tags: tags
        )
    }
}
