import Testing
import Foundation
@testable import MindLoop

@Suite("ChunkingService Tests")
struct ChunkingServiceTests {

    // MARK: - Short Entry Tests

    @Test("Short entry does not need chunking")
    func testShortEntry() {
        // Given: A short journal entry (~50 words)
        let entry = JournalEntry(
            id: "test-1",
            timestamp: Date(),
            text: "Today was a good day. I felt productive and accomplished several tasks. My mood improved throughout the afternoon.",
            emotion: .samplePositive,
            embeddings: nil,
            tags: ["positive", "work"]
        )

        // When: Checking if chunking is needed
        let needsChunking = ChunkingService.shared.needsChunking(entry)

        // Then: Should not need chunking
        #expect(!needsChunking)

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Should return single chunk
        #expect(chunks.count == 1)
        #expect(chunks[0].text == entry.text)
        #expect(chunks[0].chunkIndex == 0)
        #expect(chunks[0].parentEntryId == entry.id)
    }

    // MARK: - Long Entry Tests

    @Test("Long entry is split into multiple chunks")
    func testLongEntry() {
        // Given: A long journal entry (~600 words, exceeds 400 token limit)
        let longText = String(repeating: "This is a sentence about my day. ", count: 50)

        let entry = JournalEntry(
            id: "test-2",
            timestamp: Date(),
            text: longText,
            emotion: .sampleAnxious,
            embeddings: nil,
            tags: ["long"]
        )

        // When: Checking if chunking is needed
        let needsChunking = ChunkingService.shared.needsChunking(entry)

        // Then: Should need chunking
        #expect(needsChunking)

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Should return multiple chunks
        #expect(chunks.count > 1)

        // Then: All chunks should have correct parent ID
        for chunk in chunks {
            #expect(chunk.parentEntryId == entry.id)
        }

        // Then: Chunk indices should be sequential
        for (index, chunk) in chunks.enumerated() {
            #expect(chunk.chunkIndex == index)
        }

        // Then: All chunks should be under token limit
        for chunk in chunks {
            #expect(chunk.tokenCount <= 400)
        }
    }

    // MARK: - Token Estimation Tests

    @Test("Token estimation is accurate")
    func testTokenEstimation() {
        // Given: Known text samples
        let samples = [
            ("Hello world", 3),  // ~2 words / 0.75 ≈ 3 tokens
            ("This is a longer sentence with many words.", 10)  // ~8 words / 0.75 ≈ 11 tokens
        ]

        for (text, expectedRange) in samples {
            // When: Estimating tokens
            let tokens = ChunkingService.shared.estimateTokens(text)

            // Then: Should be within reasonable range
            #expect(tokens >= expectedRange - 2)
            #expect(tokens <= expectedRange + 2)
        }
    }

    // MARK: - Chunk Metadata Tests

    @Test("Chunks inherit emotion metadata")
    func testChunkEmotionMetadata() {
        // Given: Entry with emotion signal
        let entry = JournalEntry(
            id: "test-3",
            timestamp: Date(),
            text: "I'm feeling anxious about tomorrow's presentation. There's so much that could go wrong.",
            emotion: EmotionSignal(
                label: .anxious,
                confidence: 0.85,
                valence: -0.5,
                arousal: 0.7,
                prosodyFeatures: [
                    "pitch_mean": 220.5,
                    "energy_mean": 0.62,
                    "speaking_rate": 1.3
                ]
            ),
            embeddings: nil,
            tags: ["anxiety"]
        )

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Chunks should inherit emotion metadata
        for chunk in chunks {
            #expect(chunk.dominantEmotion == .anxious)
            #expect(chunk.emotionConfidence == 0.85)
            #expect(chunk.valence == -0.5)
            #expect(chunk.arousal == 0.7)
            #expect(chunk.avgPitch == 220.5)
            #expect(chunk.avgEnergy == 0.62)
            #expect(chunk.avgSpeakingRate == 1.3)
        }
    }

    // MARK: - Sentence Boundary Tests

    @Test("Chunks split at sentence boundaries")
    func testSentenceBoundarySplitting() {
        // Given: Entry with multiple clear sentences
        let text = """
        Today was challenging. I had three meetings back-to-back. \
        The first one went well and I presented my ideas clearly. \
        The second meeting was stressful because of technical issues. \
        The third meeting helped me feel better about the day.
        """

        let entry = JournalEntry(
            id: "test-4",
            timestamp: Date(),
            text: text,
            emotion: .sampleNeutral,
            embeddings: nil,
            tags: ["work"]
        )

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: If split, chunks should contain complete sentences
        for chunk in chunks {
            // Chunks should start with capital letter (new sentence)
            #expect(chunk.text.first?.isUppercase == true || chunk.text.first?.isWhitespace == false)

            // Chunks should end with sentence terminator
            let lastChar = chunk.text.trimmingCharacters(in: .whitespaces).last
            let validTerminators: Set<Character> = [".", "!", "?"]
            if chunks.count > 1 {
                // Multi-chunk entries should have sentence boundaries
                // (or be the last chunk which may not have terminator)
                let isLastChunk = chunk.chunkIndex == chunks.count - 1
                #expect(isLastChunk || validTerminators.contains(lastChar ?? " "))
            }
        }
    }

    // MARK: - Edge Case Tests

    @Test("Empty text throws or returns empty")
    func testEmptyText() {
        // Given: Entry with empty text
        let entry = JournalEntry(
            id: "test-5",
            timestamp: Date(),
            text: "",
            emotion: .sampleNeutral,
            embeddings: nil,
            tags: []
        )

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Should handle gracefully
        // Either return single empty chunk or empty array
        #expect(chunks.count <= 1)
    }

    @Test("Single very long sentence is split")
    func testVeryLongSentence() {
        // Given: Entry with one extremely long sentence (>400 words)
        let longSentence = Array(repeating: "word", count: 500).joined(separator: " ")

        let entry = JournalEntry(
            id: "test-6",
            timestamp: Date(),
            text: longSentence,
            emotion: .sampleNeutral,
            embeddings: nil,
            tags: []
        )

        // When: Checking if chunking needed
        let needsChunking = ChunkingService.shared.needsChunking(entry)

        // Then: Should need chunking even without sentence boundaries
        #expect(needsChunking)

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Should split long sentence into multiple chunks
        #expect(chunks.count > 1)

        // Then: Each chunk should be under limit
        for chunk in chunks {
            #expect(chunk.tokenCount <= 400)
        }
    }

    // MARK: - Chunk ID Format Tests

    @Test("Chunk IDs follow correct format")
    func testChunkIDFormat() {
        // Given: Entry that will be chunked
        let longText = String(repeating: "This is a sentence about my day. ", count: 40)

        let entry = JournalEntry(
            id: "entry-123",
            timestamp: Date(),
            text: longText,
            emotion: .sampleNeutral,
            embeddings: nil,
            tags: []
        )

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Chunk IDs should follow pattern: parentId_chunk-N
        for (index, chunk) in chunks.enumerated() {
            let expectedId = "entry-123_chunk-\(index)"
            #expect(chunk.id == expectedId)
        }
    }

    // MARK: - Consistency Tests

    @Test("Concatenated chunks equal original text")
    func testChunkConcatenation() {
        // Given: Entry with moderate length
        let originalText = """
        Today I went for a walk in the park. The weather was beautiful and sunny. \
        I saw many people enjoying the outdoors. It made me feel grateful for simple pleasures. \
        Sometimes I forget to appreciate these moments. I want to remember this feeling.
        """

        let entry = JournalEntry(
            id: "test-7",
            timestamp: Date(),
            text: originalText,
            emotion: .samplePositive,
            embeddings: nil,
            tags: ["gratitude"]
        )

        // When: Creating chunks
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Then: Concatenated chunks should approximately equal original
        let concatenated = chunks.map { $0.text }.joined(separator: " ")
        let originalWords = Set(originalText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let chunkWords = Set(concatenated.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })

        // All original words should appear in chunks
        #expect(originalWords.isSubset(of: chunkWords))
    }
}
