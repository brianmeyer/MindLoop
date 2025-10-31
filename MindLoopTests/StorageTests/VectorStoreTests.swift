//
//  VectorStoreTests.swift
//  MindLoopTests
//
//  Unit tests for VectorStore
//

import Testing
import Foundation
@testable import MindLoop

@Suite("VectorStore Tests")
struct VectorStoreTests {
    
    // MARK: - Setup
    
    init() async throws {
        try SQLiteManager.shared.openDatabase()
    }
    
    // MARK: - Storage
    
    @Test("Store and retrieve embedding")
    func testStoreAndRetrieve() throws {
        let entryId = "vector-test-1"
        let vector = generateRandomVector()
        
        // Store
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector,
            type: .qwen3
        )

        // Retrieve
        let retrieved = try VectorStore.shared.fetchEmbedding(
            entryId: entryId,
            type: .qwen3
        )

        #expect(retrieved != nil)
        #expect(retrieved!.count == 462)
        
        // Verify values match
        for (i, value) in vector.enumerated() {
            #expect(abs(retrieved![i] - value) < 0.0001) // Float precision
        }
    }
    
    @Test("Store replaces existing embedding")
    func testStoreReplaces() throws {
        let entryId = "vector-test-replace"
        let vector1 = generateRandomVector()
        let vector2 = generateRandomVector()
        
        // Store first vector
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector1,
            type: .qwen3
        )

        // Store second vector (should replace)
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector2,
            type: .qwen3
        )

        // Retrieve
        let retrieved = try VectorStore.shared.fetchEmbedding(
            entryId: entryId,
            type: .qwen3
        )
        
        #expect(retrieved != nil)
        
        // Should match second vector, not first
        for (i, value) in vector2.enumerated() {
            #expect(abs(retrieved![i] - value) < 0.0001)
        }
    }
    
    @Test("Single embedding type stored correctly")
    func testDifferentTypes() throws {
        let entryId = "vector-test-types"
        let vector1 = generateRandomVector()
        let vector2 = generateRandomVector()

        // Store first embedding
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector1,
            type: .qwen3
        )

        // Store again (should replace since same entry + type)
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector2,
            type: .qwen3
        )

        // Retrieve
        let retrieved = try VectorStore.shared.fetchEmbedding(
            entryId: entryId,
            type: .qwen3
        )

        #expect(retrieved != nil)
        #expect(retrieved!.count == 462)

        // Should match second vector (replacement behavior)
        for i in 0..<462 {
            #expect(abs(retrieved![i] - vector2[i]) < 0.0001)
        }
    }
    
    @Test("Delete embedding works")
    func testDelete() throws {
        let entryId = "vector-test-delete"
        let vector = generateRandomVector()
        
        // Store
        try VectorStore.shared.storeEmbedding(
            entryId: entryId,
            vector: vector,
            type: .qwen3
        )

        // Verify stored
        var retrieved = try VectorStore.shared.fetchEmbedding(
            entryId: entryId,
            type: .qwen3
        )
        #expect(retrieved != nil)

        // Delete
        try VectorStore.shared.deleteEmbedding(
            entryId: entryId,
            type: .qwen3
        )

        // Verify deleted
        retrieved = try VectorStore.shared.fetchEmbedding(
            entryId: entryId,
            type: .qwen3
        )
        #expect(retrieved == nil)
    }
    
    @Test("Invalid dimension throws error")
    func testInvalidDimension() throws {
        let entryId = "vector-test-invalid"
        let invalidVector = [Float](repeating: 0.1, count: 128) // Wrong dimension
        
        #expect(throws: (any Error).self) {
            try VectorStore.shared.storeEmbedding(
                entryId: entryId,
                vector: invalidVector,
                type: .qwen3
            )
        }
    }
    
    // MARK: - Similarity Search
    
    @Test("Similarity search finds similar vectors")
    func testSimilaritySearch() throws {
        // Create a base vector
        let baseVector = generateRandomVector()
        
        // Create similar vectors (small perturbations)
        let similar1 = perturbVector(baseVector, amount: 0.1)
        let similar2 = perturbVector(baseVector, amount: 0.15)
        
        // Create dissimilar vector
        let dissimilar = generateRandomVector()
        
        // Store embeddings
        let entry1 = createEntryWithVector(id: "sim-1", vector: similar1)
        let entry2 = createEntryWithVector(id: "sim-2", vector: similar2)
        let entry3 = createEntryWithVector(id: "sim-3", vector: dissimilar)
        
        // Search
        let results = try VectorStore.shared.findSimilar(
            to: baseVector,
            type: .qwen3,
            k: 3,
            recencyBoost: 0.0 // No recency for pure similarity test
        )
        
        #expect(results.count == 3)
        
        // Similar vectors should rank higher
        #expect(results[0].entryId == "sim-1" || results[0].entryId == "sim-2")
        #expect(results[1].entryId == "sim-1" || results[1].entryId == "sim-2")
        #expect(results[2].entryId == "sim-3")
    }
    
    @Test("Similarity search respects k parameter")
    func testSimilaritySearchK() throws {
        let baseVector = generateRandomVector()
        
        // Store 10 entries
        for i in 0..<10 {
            let vector = generateRandomVector()
            _ = createEntryWithVector(id: "k-test-\(i)", vector: vector)
        }
        
        // Search for k=5
        let results = try VectorStore.shared.findSimilar(
            to: baseVector,
            type: .qwen3,
            k: 5
        )
        
        #expect(results.count == 5)
    }
    
    @Test("Recency boost affects rankings")
    func testRecencyBoost() throws {
        let baseVector = generateRandomVector()
        
        // Create old entry with perfect similarity
        let oldEntry = JournalEntry(
            id: "recency-old",
            timestamp: Date().addingTimeInterval(-30 * 86400), // 30 days ago
            text: "Old entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        try SQLiteManager.shared.insertJournalEntry(oldEntry)
        try VectorStore.shared.storeEmbedding(
            entryId: oldEntry.id,
            vector: baseVector, // Identical = max similarity
            type: .qwen3
        )
        
        // Create recent entry with slightly lower similarity
        let recentEntry = JournalEntry(
            id: "recency-recent",
            timestamp: Date().addingTimeInterval(-1 * 86400), // 1 day ago
            text: "Recent entry",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        try SQLiteManager.shared.insertJournalEntry(recentEntry)
        try VectorStore.shared.storeEmbedding(
            entryId: recentEntry.id,
            vector: perturbVector(baseVector, amount: 0.05),
            type: .qwen3
        )

        // Search with high recency boost
        let results = try VectorStore.shared.findSimilar(
            to: baseVector,
            type: .qwen3,
            k: 2,
            recencyBoost: 0.8 // Heavy recency weighting
        )
        
        #expect(results.count == 2)
        // Recent entry should rank first due to recency boost
        #expect(results[0].entryId == "recency-recent")
    }
    
    // MARK: - Statistics
    
    @Test("Count returns correct number of embeddings")
    func testCount() throws {
        let initialCount = try VectorStore.shared.count(type: .qwen3)

        // Add 5 embeddings
        for i in 0..<5 {
            let vector = generateRandomVector()
            _ = createEntryWithVector(id: "count-test-\(i)", vector: vector)
        }

        let finalCount = try VectorStore.shared.count(type: .qwen3)
        
        #expect(finalCount == initialCount + 5)
    }
    
    // MARK: - Helpers
    
    /// Generates a random 462-dimensional vector
    private func generateRandomVector() -> [Float] {
        (0..<462).map { _ in Float.random(in: -1.0...1.0) }
    }
    
    /// Perturbs a vector by adding random noise
    private func perturbVector(_ vector: [Float], amount: Float) -> [Float] {
        vector.map { value in
            let noise = Float.random(in: -amount...amount)
            return value + noise
        }
    }
    
    /// Creates a journal entry and stores its embedding
    private func createEntryWithVector(id: String, vector: [Float]) -> JournalEntry {
        let entry = JournalEntry(
            id: id,
            timestamp: Date(),
            text: "Test entry for vector \(id)",
            emotion: EmotionSignal.sampleNeutral,
            tags: []
        )
        
        try! SQLiteManager.shared.insertJournalEntry(entry)
        try! VectorStore.shared.storeEmbedding(
            entryId: entry.id,
            vector: vector,
            type: .qwen3
        )
        
        return entry
    }
}
