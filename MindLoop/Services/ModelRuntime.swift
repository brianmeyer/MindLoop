//
//  ModelRuntime.swift
//  MindLoop
//
//  Model loading and inference using MLX Swift
//  Manages Qwen3-Instruct-4B (LLM) and Qwen3-Embedding-0.6B (embeddings)
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Observation
import Tokenizers

/// Model runtime for LLM and embedding inference
@MainActor
@Observable
final class ModelRuntime {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = ModelRuntime()

    /// Loading state
    private(set) var isLoaded = false

    /// Embedding model loaded state
    private(set) var isEmbeddingLoaded = false

    /// Memory usage in MB
    private(set) var memoryUsageMB: Int = 0

    /// LLM model container (Qwen3-4B-Instruct)
    private var llmContainer: ModelContainer?

    /// Embedding model container (Qwen3-Embedding-0.6B)
    private var embeddingContainer: ModelContainer?

    /// Model paths
    private let llmModelPath = "qwen3-4b-instruct-mlx"
    private let embeddingModelPath = "qwen3-embedding-0.6b-4bit"

    private init() {}

    // MARK: - Model Loading

    /// Load LLM model from Resources/Models directory
    /// - Parameter progressHandler: Optional progress callback (0.0-1.0)
    func loadModel(from modelPath: String = "qwen3-4b-instruct-mlx", progressHandler: ((Double) -> Void)? = nil) async throws {
        guard !isLoaded else {
            print("ModelRuntime: LLM already loaded")
            return
        }

        print("ModelRuntime: Loading Qwen3-4B-Instruct from \(modelPath)...")

        // Set GPU cache limit (20MB)
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        // Get model directory URL
        guard let modelURL = getModelURL(path: modelPath) else {
            throw ModelError.modelNotFound(path: modelPath)
        }

        let startTime = Date()

        // Create configuration for local model directory
        // Try using the local path as the model ID
        let configuration = ModelConfiguration(
            id: modelURL.path,
            defaultPrompt: "You are a helpful assistant."
        )

        // Load model from local directory
        llmContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            progressHandler?(progress.fractionCompleted)
            print("ModelRuntime: Loading... \(Int(progress.fractionCompleted * 100))%")
        }

        let loadTime = Date().timeIntervalSince(startTime)
        isLoaded = true

        // Update memory usage
        updateMemoryUsage()

        print("ModelRuntime: LLM loaded in \(String(format: "%.2f", loadTime))s, memory: \(memoryUsageMB)MB")
    }

    /// Load embedding model
    func loadEmbeddingModel(progressHandler: ((Double) -> Void)? = nil) async throws {
        guard !isEmbeddingLoaded else {
            print("ModelRuntime: Embedding model already loaded")
            return
        }

        print("ModelRuntime: Loading Qwen3-Embedding-0.6B from \(embeddingModelPath)...")

        // Get model directory URL
        guard let modelURL = getModelURL(path: embeddingModelPath) else {
            throw ModelError.modelNotFound(path: embeddingModelPath)
        }

        let startTime = Date()

        // Create configuration for local embedding model directory
        let configuration = ModelConfiguration(
            id: modelURL.path,
            defaultPrompt: "" // Embedding models don't need prompts
        )

        // Load embedding model
        embeddingContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            progressHandler?(progress.fractionCompleted)
            print("ModelRuntime: Loading embedding... \(Int(progress.fractionCompleted * 100))%")
        }

        let loadTime = Date().timeIntervalSince(startTime)
        isEmbeddingLoaded = true

        // Update memory usage
        updateMemoryUsage()

        print("ModelRuntime: Embedding model loaded in \(String(format: "%.2f", loadTime))s, memory: \(memoryUsageMB)MB")
    }

    // MARK: - Text Generation

    /// Generate text with streaming output
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - maxTokens: Maximum tokens to generate (default: 120)
    ///   - temperature: Sampling temperature (default: 0.7)
    /// - Returns: AsyncStream of generated tokens
    func generate(
        prompt: String,
        maxTokens: Int = 120,
        temperature: Float = 0.7
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let container = llmContainer, isLoaded else {
                    print("ModelRuntime: LLM not loaded")
                    continuation.finish()
                    return
                }

                do {
                    // Prepare input
                    let input = UserInput(prompt: prompt)

                    // Generate with streaming
                    _ = try await container.perform { context in
                        let preparedInput = try await context.processor.prepare(input: input)

                        let parameters = GenerateParameters(temperature: temperature, topP: 0.9)

                        return try MLXLMCommon.generate(
                            input: preparedInput,
                            parameters: parameters,
                            context: context
                        ) { tokens in
                            // Decode tokens to text
                            let text = context.tokenizer.decode(tokens: tokens)

                            // Yield token
                            continuation.yield(text)

                            // Check if we should continue
                            if tokens.count >= maxTokens {
                                return .stop
                            }
                            return .more
                        }
                    }

                    continuation.finish()
                } catch {
                    print("ModelRuntime: Generation failed: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    /// Generate text synchronously (for testing)
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - maxTokens: Maximum tokens to generate
    /// - Returns: Complete generated text
    func generateSync(prompt: String, maxTokens: Int = 120) async throws -> String {
        var result = ""

        for await token in generate(prompt: prompt, maxTokens: maxTokens) {
            result += token
        }

        return result
    }

    // MARK: - Embeddings

    /// Generate embedding vector (462-dim for Qwen3-Embedding-0.6B)
    /// - Parameter text: Input text
    /// - Returns: 462-dimensional embedding vector
    func generateEmbedding(text: String) async throws -> [Float] {
        guard let _ = embeddingContainer, isEmbeddingLoaded else {
            throw ModelError.embeddingModelNotLoaded
        }

        // For now, return placeholder - embedding extraction needs specific implementation
        // TODO: Implement proper embedding extraction from Qwen3-Embedding model
        // This may require using the model's hidden states or pooling strategy

        let dimension = 462
        print("ModelRuntime: Generating \(dimension)-dim embedding for: \"\(text.prefix(50))...\"")

        // Placeholder: Generate random normalized embedding
        // In production, this will use the actual embedding model
        var embedding = (0..<dimension).map { _ in Float.random(in: -1...1) }

        // Normalize to unit length
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        embedding = embedding.map { $0 / magnitude }

        return embedding
    }

    // MARK: - Memory Management

    /// Update memory usage estimate
    private func updateMemoryUsage() {
        // Rough estimates based on model sizes:
        // Qwen3-4B-Instruct (4-bit): ~2.5GB
        // Qwen3-Embedding-0.6B (4-bit): ~320MB

        var totalMB = 0

        if isLoaded {
            totalMB += 2500 // LLM model
        }

        if isEmbeddingLoaded {
            totalMB += 320 // Embedding model
        }

        memoryUsageMB = totalMB
    }

    /// Unload LLM model to free memory
    func unloadModel() {
        llmContainer = nil
        isLoaded = false
        updateMemoryUsage()
        print("ModelRuntime: LLM unloaded")
    }

    /// Unload embedding model to free memory
    func unloadEmbedding() {
        embeddingContainer = nil
        isEmbeddingLoaded = false
        updateMemoryUsage()
        print("ModelRuntime: Embedding model unloaded")
    }

    // MARK: - Utilities

    /// Get model directory URL from Resources
    private func getModelURL(path: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else {
            print("ModelRuntime: Resource URL not found")
            return nil
        }

        let modelURL = resourceURL
            .appendingPathComponent("Models")
            .appendingPathComponent(path)

        print("ModelRuntime: Model path: \(modelURL.path)")

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("ModelRuntime: Model directory not found at \(modelURL.path)")
            return nil
        }

        return modelURL
    }
}

// MARK: - Types

extension ModelRuntime {
    enum ModelError: Error, CustomStringConvertible {
        case modelNotFound(path: String)
        case embeddingModelNotLoaded
        case notLoaded
        case loadingFailed(reason: String)
        case generationFailed(reason: String)
        case timeout
        case checksumMismatch(file: String)

        var description: String {
            switch self {
            case .modelNotFound(let path):
                return "Model not found at path: \(path)"
            case .embeddingModelNotLoaded:
                return "Embedding model not loaded"
            case .notLoaded:
                return "Model not loaded"
            case .loadingFailed(let reason):
                return "Model loading failed: \(reason)"
            case .generationFailed(let reason):
                return "Text generation failed: \(reason)"
            case .timeout:
                return "Model operation timeout"
            case .checksumMismatch(let file):
                return "Checksum mismatch for file: \(file)"
            }
        }
    }
}
