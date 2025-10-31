import Foundation
import NaturalLanguage

/// Service for semantic chunking of journal entries that exceed embedding model token limits
/// Splits long entries at sentence boundaries while staying under 400 tokens per chunk
/// Future enhancement: Split at emotion/prosody boundaries when per-segment data is available
final class ChunkingService {
    // MARK: - Singleton

    static let shared = ChunkingService()

    // MARK: - Constants

    /// Maximum tokens per chunk (embedding model limit is ~512, use 400 for safety)
    private let maxTokensPerChunk = 400

    /// Approximate words per token ratio (rough estimate: ~0.75 tokens per word)
    private let wordsPerToken: Double = 0.75

    /// Maximum words per chunk (derived from token limit)
    private var maxWordsPerChunk: Int {
        Int(Double(maxTokensPerChunk) * wordsPerToken)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Check if an entry needs chunking
    /// - Parameter entry: Journal entry to check
    /// - Returns: True if entry exceeds token limit
    func needsChunking(_ entry: JournalEntry) -> Bool {
        let estimatedTokens = estimateTokens(entry.text)
        return estimatedTokens > maxTokensPerChunk
    }

    /// Create semantic chunks from a journal entry
    /// - Parameter entry: Journal entry to chunk
    /// - Returns: Array of semantic chunks (returns single chunk if entry is short)
    func createChunks(from entry: JournalEntry) -> [SemanticChunk] {
        // If entry is short enough, return single chunk
        if !needsChunking(entry) {
            return [createSingleChunk(from: entry)]
        }

        // Split text into sentences
        let sentences = splitIntoSentences(entry.text)

        // Group sentences into chunks under token limit
        let chunkTexts = groupSentencesIntoChunks(sentences)

        // Create SemanticChunk objects
        return chunkTexts.enumerated().map { index, text in
            createChunk(
                from: entry,
                chunkIndex: index,
                text: text,
                totalChunks: chunkTexts.count
            )
        }
    }

    // MARK: - Private Methods

    /// Create a single chunk for an entry that doesn't need chunking
    private func createSingleChunk(from entry: JournalEntry) -> SemanticChunk {
        SemanticChunk(
            parentEntryId: entry.id,
            chunkIndex: 0,
            text: entry.text,
            startTime: 0,
            endTime: 0, // No audio timing for text entries
            dominantEmotion: entry.emotion.label,
            emotionConfidence: Float(entry.emotion.confidence),
            valence: Float(entry.emotion.valence),
            arousal: Float(entry.emotion.arousal),
            avgPitch: entry.emotion.prosodyFeatures["pitch_mean"].map { Float($0) },
            avgEnergy: entry.emotion.prosodyFeatures["energy_mean"].map { Float($0) },
            avgSpeakingRate: entry.emotion.prosodyFeatures["speaking_rate"].map { Float($0) },
            tokenCount: estimateTokens(entry.text),
            createdAt: entry.timestamp
        )
    }

    /// Create a chunk from an entry at a specific index
    private func createChunk(
        from entry: JournalEntry,
        chunkIndex: Int,
        text: String,
        totalChunks: Int
    ) -> SemanticChunk {
        // For now, all chunks inherit the entry's emotion
        // Future: Calculate per-chunk emotion when segment data is available
        SemanticChunk(
            parentEntryId: entry.id,
            chunkIndex: chunkIndex,
            text: text,
            startTime: 0, // Future: Calculate from audio segments
            endTime: 0,   // Future: Calculate from audio segments
            dominantEmotion: entry.emotion.label,
            emotionConfidence: Float(entry.emotion.confidence),
            valence: Float(entry.emotion.valence),
            arousal: Float(entry.emotion.arousal),
            avgPitch: entry.emotion.prosodyFeatures["pitch_mean"].map { Float($0) },
            avgEnergy: entry.emotion.prosodyFeatures["energy_mean"].map { Float($0) },
            avgSpeakingRate: entry.emotion.prosodyFeatures["speaking_rate"].map { Float($0) },
            tokenCount: estimateTokens(text),
            createdAt: entry.timestamp
        )
    }

    /// Split text into sentences using NaturalLanguage framework
    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences.isEmpty ? [text] : sentences
    }

    /// Group sentences into chunks that fit within token limit
    private func groupSentencesIntoChunks(_ sentences: [String]) -> [String] {
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentWordCount = 0

        for sentence in sentences {
            let sentenceWordCount = wordCount(sentence)

            // If single sentence exceeds limit, split it (edge case)
            if sentenceWordCount > maxWordsPerChunk {
                // Flush current chunk if not empty
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: " "))
                    currentChunk = []
                    currentWordCount = 0
                }

                // Split long sentence by words
                let splitSentences = splitLongSentence(sentence)
                chunks.append(contentsOf: splitSentences)
                continue
            }

            // Check if adding this sentence would exceed limit
            if currentWordCount + sentenceWordCount > maxWordsPerChunk && !currentChunk.isEmpty {
                // Start new chunk
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [sentence]
                currentWordCount = sentenceWordCount
            } else {
                // Add to current chunk
                currentChunk.append(sentence)
                currentWordCount += sentenceWordCount
            }
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks.isEmpty ? [sentences.joined(separator: " ")] : chunks
    }

    /// Split a very long sentence into smaller chunks (edge case handling)
    private func splitLongSentence(_ sentence: String) -> [String] {
        let words = sentence.components(separatedBy: .whitespaces)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentCount = 0

        for word in words {
            if currentCount + 1 > maxWordsPerChunk && !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [word]
                currentCount = 1
            } else {
                currentChunk.append(word)
                currentCount += 1
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }

    /// Estimate token count from text (rough approximation)
    /// Uses word count / 0.75 as tokens are typically 0.75-1.3 words
    func estimateTokens(_ text: String) -> Int {
        let words = Double(wordCount(text))
        return Int(words / wordsPerToken)
    }

    /// Count words in text
    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Future Enhancement Notes

/*
 Future enhancement when per-segment emotion data is available from STT:

 1. Update JournalEntry to include segments:
    struct TranscriptSegment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let emotion: EmotionSignal
    }
    let segments: [TranscriptSegment]

 2. Implement emotion-aware boundary detection:
    func detectBoundaries(entry: JournalEntry) -> [Int] {
        var boundaries: [Int] = [0]
        var currentEmotion: EmotionSignal.Label? = nil
        var currentTokens = 0

        for (i, segment) in entry.segments.enumerated() {
            let tokens = estimateTokens(segment.text)

            // Hard constraint: max 400 tokens
            if currentTokens + tokens > maxTokensPerChunk {
                boundaries.append(i)
                currentTokens = 0
                continue
            }

            // Emotion change detection
            if let prevEmotion = currentEmotion,
               prevEmotion != segment.emotion.label {
                boundaries.append(i)
                currentTokens = 0
            }

            currentEmotion = segment.emotion.label
            currentTokens += tokens
        }
        return boundaries
    }

 3. Update createChunk to use segment timing and emotion data
 */
