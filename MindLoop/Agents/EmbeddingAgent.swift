//
//  EmbeddingAgent.swift
//  MindLoop
//
//  Embedding generation using bge-small-en-v1.5 (384-dim, <50ms latency, MTEB 58.6)
//  Chunk-aware: splits long entries at emotion boundaries via ChunkingService
//

import Foundation

/// Embedding generation agent using bge-small-en-v1.5 via MLXEmbedders
final class EmbeddingAgent: AgentProtocol, @unchecked Sendable {

    // MARK: - AgentProtocol

    typealias Input = String
    typealias Output = [Float]

    var name: String { "EmbeddingAgent" }

    /// Satisfy `AgentProtocol.process(_:)` by delegating to the convenience method.
    func process(_ input: String) async throws -> [Float] {
        try await generate(text: input)
    }

    // MARK: - Properties

    /// Shared singleton instance
    static let shared = EmbeddingAgent()

    private let modelRuntime = ModelRuntime.shared

    private init() {}

    // MARK: - Embedding Generation

    /// Generate embedding using bge-small-en-v1.5 (<50ms target, 384-dim)
    /// - Parameter text: Input text
    /// - Returns: 384-dimensional embedding vector
    func generate(text: String) async throws -> [Float] {
        guard !text.isEmpty else {
            throw EmbeddingError.emptyText
        }

        return try await modelRuntime.generateEmbedding(text: text)
    }

    // MARK: - Batch Processing

    /// Generate embeddings for multiple texts in parallel
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of embedding vectors
    func generateBatch(texts: [String]) async throws -> [[Float]] {
        try await withThrowingTaskGroup(of: (Int, [Float]).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let embedding = try await self.generate(text: text)
                    return (index, embedding)
                }
            }

            var results: [(Int, [Float])] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Chunk-Aware Embedding

    /// Generate embeddings for journal entry chunks
    func generateForEntry(entry: JournalEntry) async throws -> [(chunk: SemanticChunk, embedding: [Float])] {
        let chunks = ChunkingService.shared.createChunks(from: entry)

        var results: [(chunk: SemanticChunk, embedding: [Float])] = []
        for chunk in chunks {
            let embedding = try await generate(text: chunk.text)
            results.append((chunk: chunk, embedding: embedding))
        }

        return results
    }

    // MARK: - Background Queue

    /// Enqueue entry for background embedding with automatic chunking
    func enqueueBackground(entry: JournalEntry, completion: @escaping (Int) -> Void) {
        Task.detached(priority: .background) {
            do {
                let chunkEmbeddings = try await self.generateForEntry(entry: entry)

                for (chunk, embedding) in chunkEmbeddings {
                    try VectorStore.shared.storeChunkEmbedding(
                        chunk: chunk,
                        vector: embedding
                    )
                }

                let chunkCount = chunkEmbeddings.count
                await MainActor.run { completion(chunkCount) }
            } catch {
                print("EmbeddingAgent: Background embedding failed: \(error)")
                await MainActor.run { completion(0) }
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
