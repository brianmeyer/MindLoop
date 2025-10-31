//
//  SQLiteManagerTests.swift
//  MindLoopTests
//
//  Unit tests for SQLiteManager
//

import Testing
import Foundation
@testable import MindLoop

@Suite("SQLiteManager Tests")
struct SQLiteManagerTests {
    
    // MARK: - Setup
    
    init() async throws {
        // Use in-memory database for tests
        try SQLiteManager.shared.openDatabase()
    }
    
    // MARK: - Database Lifecycle
    
    @Test("Database opens successfully")
    func testDatabaseOpen() throws {
        // Database should already be open from init
        // Try opening again (should be idempotent)
        try SQLiteManager.shared.openDatabase()
    }
    
    @Test("Schema version tracking works")
    func testSchemaVersion() throws {
        let version = try SQLiteManager.shared.queryScalar(
            "SELECT MAX(version) FROM schema_version;"
        ) as? Int64
        
        #expect(version == 1) // Current schema version
    }
    
    // MARK: - Journal Entry CRUD
    
    @Test("Insert and fetch journal entry")
    func testInsertAndFetchEntry() throws {
        let entry = JournalEntry(
            id: "test-entry-1",
            timestamp: Date(),
            text: "Test entry for CRUD operations",
            emotion: EmotionSignal.sampleNeutral,
            embeddings: nil,
            tags: ["test", "crud"]
        )
        
        // Insert
        try SQLiteManager.shared.insertJournalEntry(entry)
        
        // Fetch
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        
        #expect(entries.count >= 1)
        #expect(entries.contains(where: { $0.id == entry.id }))
        
        // Verify fetched entry matches
        let fetched = entries.first(where: { $0.id == entry.id })!
        #expect(fetched.text == entry.text)
        #expect(fetched.emotion.label == entry.emotion.label)
        #expect(fetched.tags == entry.tags)
    }
    
    @Test("Multiple entries are ordered by timestamp")
    func testMultipleEntriesOrdering() throws {
        let now = Date()
        
        let entry1 = JournalEntry(
            id: "test-order-1",
            timestamp: now.addingTimeInterval(-3600), // 1 hour ago
            text: "Older entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        
        let entry2 = JournalEntry(
            id: "test-order-2",
            timestamp: now,
            text: "Newer entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        
        try SQLiteManager.shared.insertJournalEntry(entry1)
        try SQLiteManager.shared.insertJournalEntry(entry2)
        
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        
        // Should be ordered newest first
        let testEntries = entries.filter { $0.id.hasPrefix("test-order") }
        #expect(testEntries.count == 2)
        #expect(testEntries[0].id == "test-order-2") // Newer first
        #expect(testEntries[1].id == "test-order-1")
    }
    
    @Test("Tags are stored and retrieved correctly")
    func testTagsStorage() throws {
        let entry = JournalEntry(
            id: "test-tags-1",
            timestamp: Date(),
            text: "Entry with multiple tags",
            emotion: EmotionSignal.sampleNeutral,
            tags: ["work", "stress", "deadline", "presentation"]
        )
        
        try SQLiteManager.shared.insertJournalEntry(entry)
        
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        let fetched = entries.first(where: { $0.id == entry.id })!
        
        #expect(fetched.tags.count == 4)
        #expect(fetched.tags.contains("work"))
        #expect(fetched.tags.contains("stress"))
        #expect(fetched.tags.contains("deadline"))
        #expect(fetched.tags.contains("presentation"))
    }
    
    @Test("Empty tags array is handled correctly")
    func testEmptyTags() throws {
        let entry = JournalEntry(
            id: "test-empty-tags",
            timestamp: Date(),
            text: "Entry with no tags",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        
        try SQLiteManager.shared.insertJournalEntry(entry)
        
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        let fetched = entries.first(where: { $0.id == entry.id })!
        
        #expect(fetched.tags.isEmpty)
    }
    
    // MARK: - Transactions
    
    @Test("Transaction commits on success")
    func testTransactionCommit() throws {
        let result = try SQLiteManager.shared.transaction {
            let entry = JournalEntry(
                id: "test-txn-commit",
                timestamp: Date(),
                text: "Transaction test",
                emotion: EmotionSignal.sampleNeutral,
                tags: []
            )
            
            try SQLiteManager.shared.insertJournalEntry(entry)
            return "success"
        }
        
        #expect(result == "success")
        
        // Verify entry was committed
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        #expect(entries.contains(where: { $0.id == "test-txn-commit" }))
    }
    
    @Test("Transaction rolls back on error")
    func testTransactionRollback() throws {
        let countBefore = try SQLiteManager.shared.fetchAllJournalEntries().count
        
        do {
            try SQLiteManager.shared.transaction {
                let entry = JournalEntry(
                    id: "test-txn-rollback",
                    timestamp: Date(),
                    text: "Should not be committed",
                    emotion: EmotionSignal.sampleNeutral,
                    tags: []
                )
                
                try SQLiteManager.shared.insertJournalEntry(entry)
                
                // Force an error
                throw TestError.intentional
            }
        } catch is TestError {
            // Expected error
        }
        
        let countAfter = try SQLiteManager.shared.fetchAllJournalEntries().count
        
        // Count should be unchanged (transaction rolled back)
        #expect(countAfter == countBefore)
        
        // Entry should not exist
        let entries = try SQLiteManager.shared.fetchAllJournalEntries()
        #expect(!entries.contains(where: { $0.id == "test-txn-rollback" }))
    }
    
    // MARK: - Error Cases
    
    enum TestError: Error {
        case intentional
    }
}
