//
//  EmbeddingAgent.swift
//  MindLoop
//
//  Single-model embedding generation using Qwen3-Embedding-0.6B
//  462-dim vectors, <200ms latency
//

import Foundation

/// Embedding generation agent using Qwen3-Embedding-0.6B
final class EmbeddingAgent {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = EmbeddingAgent()

    private let modelRuntime = ModelRuntime.shared

    private init() {}

    // MARK: - Embedding Generation

    /// Generate embedding using Qwen3-Embedding-0.6B (<200ms target)
    /// - Parameter text: Input text
    /// - Returns: 462-dimensional embedding vector
    func generate(text: String) async throws -> [Float] {
        guard !text.isEmpty else {
            throw EmbeddingError.emptyText
        }

        // Use Qwen3-Embedding-0.6B (462-dim, <200ms)
        return try await modelRuntime.generateEmbedding(text: text)
    }

    // MARK: - Batch Processing

    /// Generate embeddings for multiple texts in parallel
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of embedding vectors
    func generateBatch(texts: [String]) async throws -> [[Float]] {
        try await withThrowingTaskGroup(of: (Int, [Float]).self) { group in
            // Process in parallel
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let embedding = try await self.generate(text: text)
                    return (index, embedding)
                }
            }

            // Collect results in original order
            var results: [(Int, [Float])] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Chunk-Aware Embedding

    /// Generate embeddings for journal entry chunks
    /// - Parameter entry: Journal entry to embed (may be split into chunks)
    /// - Returns: Array of (chunk, embedding) tuples
    func generateForEntry(entry: JournalEntry) async throws -> [(chunk: SemanticChunk, embedding: [Float])] {
        // Use ChunkingService to split entry if needed
        let chunks = ChunkingService.shared.createChunks(from: entry)

        // Generate embeddings for each chunk
        var results: [(chunk: SemanticChunk, embedding: [Float])] = []

        for chunk in chunks {
            let embedding = try await generate(text: chunk.text)
            results.append((chunk: chunk, embedding: embedding))
        }

        return results
    }

    // MARK: - Background Queue

    /// Enqueue entry for background embedding with automatic chunking
    /// - Parameters:
    ///   - entry: Journal entry to embed
    ///   - completion: Called when all chunks are embedded
    func enqueueBackground(entry: JournalEntry, completion: @escaping (Int) -> Void) {
        Task.detached(priority: .background) {
            do {
                // Generate embeddings for all chunks
                let chunkEmbeddings = try await self.generateForEntry(entry: entry)

                // Store all chunk embeddings in database
                for (chunk, embedding) in chunkEmbeddings {
                    try await VectorStore.shared.storeChunkEmbedding(
                        chunk: chunk,
                        vector: embedding
                    )
                }

                let chunkCount = chunkEmbeddings.count

                await MainActor.run {
                    completion(chunkCount)
                }

                print("EmbeddingAgent: Background embedding complete for entry \(entry.id) (\(chunkCount) chunks)")
            } catch {
                print("EmbeddingAgent: Background embedding failed: \(error)")
                await MainActor.run {
                    completion(0)
                }
            }
        }
    }
}

// MARK: - Types

extension EmbeddingAgent {
    enum EmbeddingError: Error, CustomStringConvertible {
        case emptyText
        case generationFailed(reason: String)
        case dimensionMismatch(expected: Int, got: Int)

        var description: String {
            switch self {
            case .emptyText:
                return "Cannot generate embedding for empty text"
            case .generationFailed(let reason):
                return "Embedding generation failed: \(reason)"
            case .dimensionMismatch(let expected, let got):
                return "Embedding dimension mismatch: expected \(expected), got \(got)"
            }
        }
    }
}
