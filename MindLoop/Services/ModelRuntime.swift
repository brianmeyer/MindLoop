//
//  ModelRuntime.swift
//  MindLoop
//
//  Model loading and inference using MLX Swift
//  Manages Gemma 4 E2B-it (LLM) and gte-small (embeddings)
//

import Foundation
import Observation
import os

#if !targetEnvironment(simulator)
import MLX
import MLXLLM
import MLXLMCommon
import MLXEmbedders
// `@preconcurrency` suppresses Sendable warnings from the HuggingFace
// swift-transformers Tokenizer types we bridge into `MLXLMCommon.Tokenizer`.
// Under Swift 6 the upstream `any Tokenizer` is non-Sendable, but our
// TokenizerBridge is only read from `@MainActor`-isolated code and the MLX
// ModelContainer's internal isolated queue.
@preconcurrency import Tokenizers
#endif

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

    /// Whether the user chose to skip model loading
    private(set) var skippedModelLoad = false

    /// Memory usage in MB
    private(set) var memoryUsageMB: Int = 0

    /// Last error encountered during `generate(...)`, if any. Exposed so
    /// callers (Orchestrator) can surface a meaningful error when the LLM
    /// stream finishes without producing any chunks. Cleared at the start
    /// of each `generate` call.
    private(set) var lastGenerationError: String?

    /// Last error encountered during `loadModel(...)`, if any. Exposed so
    /// `MindLoopApp` can show a meaningful retry prompt instead of
    /// silently dismissing the loading overlay. Cleared at the start of
    /// each `loadModel` call. (REC-301)
    private(set) var lastLoadError: String?

    /// Guard flag preventing concurrent `loadModel` calls. Two rapid
    /// taps on the Retry button would otherwise both pass the
    /// `!isLoaded` guard and fire overlapping MLXLMCommon.loadModelContainer
    /// calls — the second would compete for memory and likely crash. (REC-301)
    private(set) var isLoading = false

    #if !targetEnvironment(simulator)
    /// LLM model container (Gemma 4 E2B-it, MLX 4-bit, ~1GB)
    private var llmContainer: MLXLMCommon.ModelContainer?

    /// Embedding model container (bge-small-en-v1.5, 384-dim, ~19MB)
    private var embeddingContainer: MLXEmbedders.ModelContainer?
    #endif

    /// Model paths
    private let llmModelPath = "gemma-4-e2b-it-4bit"
    private let embeddingModelPath = "bge-small-en-v1.5-4bit"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.mindloop",
        category: "ModelRuntime"
    )

    /// Embedding dimension for bge-small-en-v1.5
    static let embeddingDimension = 384

    private init() {}

    // MARK: - Model Loading

    /// Load LLM model from a directory URL or Bundle fallback.
    /// - Parameters:
    ///   - modelDirectoryURL: Optional directory URL containing model files (e.g. from ModelDownloader).
    ///     When nil, falls back to Bundle.main/Resources/Models/.
    ///   - modelPath: Model subdirectory name (used for Bundle fallback).
    ///   - progressHandler: Optional progress callback (0.0-1.0).
    func loadModel(
        from modelDirectoryURL: URL? = nil,
        modelPath: String = "gemma-4-e2b-it-4bit",
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        #if targetEnvironment(simulator)
        Self.logger.info("LLM loading skipped on simulator")
        lastLoadError = nil
        isLoaded = true
        progressHandler?(1.0)
        return
        #else
        guard !isLoaded else {
            Self.logger.info("LLM already loaded")
            return
        }
        // Concurrent-load guard: a rapid double-tap on the overlay's
        // Retry button could otherwise fire two overlapping MLX loads.
        guard !isLoading else {
            Self.logger.info("LLM load already in progress — skipping")
            return
        }
        isLoading = true
        defer { isLoading = false }

        // Clear any prior failure so the overlay can transition back to
        // the "loading" state on retry. (REC-301)
        lastLoadError = nil

        do {
            // Resolve model directory: explicit URL > Bundle fallback
            let modelURL: URL
            if let directoryURL = modelDirectoryURL {
                modelURL = directoryURL
            } else if let bundleURL = getModelURL(path: modelPath) {
                modelURL = bundleURL
            } else {
                throw ModelError.modelNotFound(path: modelPath)
            }

            // Verify all required model files are present before MLX
            // attempts to parse them — produces a clearer error than
            // a downstream "file not found" surfaced from deep inside
            // the quantized weight loader. (REC-301)
            let missing = missingModelFiles(at: modelURL)
            if !missing.isEmpty {
                throw ModelError.modelFilesIncomplete(missing: missing)
            }

            Self.logger.info("Loading Gemma 4 E2B-it from \(modelURL.path)")

            // Set GPU cache limit (20MB) — updated API per mlx-swift docs.
            MLX.Memory.cacheLimit = 20 * 1024 * 1024

            let startTime = Date()

            // Load model from local directory. Fully qualified to disambiguate
            // from MLXEmbedders.loadModelContainer (same name, different container).
            let container = try await MLXLMCommon.loadModelContainer(
                from: modelURL,
                using: HuggingFaceTokenizerLoader()
            )
            llmContainer = container

            let loadTime = Date().timeIntervalSince(startTime)
            isLoaded = true

            // Update memory usage
            updateMemoryUsage()

            Self.logger.info("LLM loaded in \(String(format: "%.2f", loadTime))s, memory: \(self.memoryUsageMB)MB")
        } catch {
            // Capture the error so MindLoopApp can show a meaningful retry
            // prompt instead of silently dismissing the loading overlay.
            let errorType = String(describing: type(of: error))
            let desc = String(describing: error).prefix(100)
            lastLoadError = "\(errorType): \(desc)"
            Self.logger.error(
                "LLM load failed (\(errorType, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        #endif
    }

    /// Return the list of required Gemma model files that are missing
    /// from the given directory. Used to produce a clear
    /// `modelFilesIncomplete` error instead of a cryptic MLX failure
    /// when the background download was interrupted. (REC-301)
    private func missingModelFiles(at directory: URL) -> [String] {
        // Canonical file list — mirrors ModelDownloader.requiredFiles.
        // Keep in sync if that list changes.
        let required: [String] = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "generation_config.json",
            "chat_template.jinja",
            "processor_config.json",
            "model.safetensors.index.json",
            "model.safetensors",
        ]
        let fm = FileManager.default
        return required.filter { name in
            !fm.fileExists(atPath: directory.appendingPathComponent(name).path)
        }
    }

    /// Load the bge-small-en-v1.5 embedding model bundled in the app.
    ///
    /// Uses `MLXEmbedders.loadModelContainer(from:using:)` with the existing
    /// `HuggingFaceTokenizerLoader`. The 4-bit bge-small model is ~19MB on
    /// disk and produces 384-dim L2-normalized embeddings. (REC-289)
    func loadEmbeddingModel(progressHandler: ((Double) -> Void)? = nil) async throws {
        #if targetEnvironment(simulator)
        Self.logger.info("Embedding model loading skipped on simulator")
        isEmbeddingLoaded = true
        progressHandler?(1.0)
        return
        #else
        guard !isEmbeddingLoaded else {
            Self.logger.info("Embedding model already loaded")
            return
        }

        guard let modelURL = getModelURL(path: embeddingModelPath) else {
            throw ModelError.modelNotFound(path: embeddingModelPath)
        }

        Self.logger.info("Loading bge-small-en-v1.5-4bit from \(modelURL.path)")
        let startTime = Date()

        // Fully qualified to disambiguate from MLXLMCommon.loadModelContainer.
        let container = try await MLXEmbedders.loadModelContainer(
            from: modelURL,
            using: HuggingFaceTokenizerLoader()
        )
        embeddingContainer = container

        isEmbeddingLoaded = true
        updateMemoryUsage()
        progressHandler?(1.0)

        let loadTime = Date().timeIntervalSince(startTime)
        Self.logger.info("Embedding model loaded in \(String(format: "%.2f", loadTime))s")
        #endif
    }

    // MARK: - Text Generation

    /// Generate text with streaming output.
    ///
    /// Uses the modern `AsyncStream<Generation>`-based MLXLMCommon API.
    /// Each yielded string is a single text delta (not cumulative), so
    /// callers can concatenate with `+=` directly.
    ///
    /// - Parameters:
    ///   - prompt: Input prompt
    ///   - maxTokens: Maximum tokens to generate (default: 120)
    ///   - temperature: Sampling temperature (default: 0.7)
    /// - Returns: AsyncStream of generated text chunks
    func generate(
        prompt: String,
        maxTokens: Int = 120,
        temperature: Float = 0.7
    ) -> AsyncStream<String> {
        #if targetEnvironment(simulator)
        return AsyncStream { continuation in
            continuation.yield("[Simulator stub] Response to: \(prompt.prefix(50))")
            continuation.finish()
        }
        #else
        // Clear any prior error so callers can check after the stream ends.
        lastGenerationError = nil

        return AsyncStream { continuation in
            Task {
                guard let container = llmContainer, isLoaded else {
                    Self.logger.warning("LLM not loaded")
                    self.lastGenerationError = "LLM not loaded (isLoaded=\(self.isLoaded))"
                    continuation.finish()
                    return
                }

                let params = GenerateParameters(
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: 0.9
                )

                // Use an AsyncStream to tally chunks after the perform
                // closure returns — avoids Swift 6 mutation-in-Sendable-closure
                // warning from a captured `var` counter.
                final class Counter { var value = 0 }
                let counter = Counter()
                do {
                    // Yield chunks directly from inside perform so the caller
                    // sees tokens progressively (typewriter UX). The inner
                    // AsyncStream<Generation> is iterated here; each `.chunk`
                    // is forwarded to the outer `AsyncStream<String>`.
                    //
                    // `AsyncStream.Continuation` is `@unchecked Sendable`, so
                    // capturing `continuation` in the `@Sendable` perform
                    // closure is safe.
                    try await container.perform { context in
                        let preparedInput = try await context.processor.prepare(
                            input: UserInput(prompt: prompt)
                        )

                        let stream = try MLXLMCommon.generate(
                            input: preparedInput,
                            parameters: params,
                            context: context
                        )

                        for await generation in stream {
                            if Task.isCancelled { break }
                            if case .chunk(let text) = generation {
                                continuation.yield(text)
                                counter.value += 1
                            }
                            // .info / .toolCall ignored for v1
                        }
                    }
                    if counter.value == 0 {
                        // Stream finished without producing any text chunks.
                        // Record a diagnostic so Orchestrator can surface it.
                        self.lastGenerationError = "stream finished with 0 chunks"
                        Self.logger.error("Generation produced 0 chunks")
                    }
                    continuation.finish()
                } catch {
                    let errorType = String(describing: type(of: error))
                    self.lastGenerationError = "\(errorType): \(error.localizedDescription)"
                    Self.logger.error(
                        "Generation failed (\(errorType, privacy: .public)): \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.finish()
                }
            }
        }
        #endif
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

    /// Generate a 384-dim L2-normalized semantic embedding for the input text
    /// using bge-small-en-v1.5 via MLXEmbedders. (REC-289)
    ///
    /// - Parameter text: Input text. Longer than 512 tokens will be truncated;
    ///   callers should pass pre-chunked text from `ChunkingService` (max 400
    ///   tokens per chunk, split at emotion boundaries).
    /// - Returns: 384-dimensional L2-normalized `[Float]` suitable for cosine
    ///   similarity search in `VectorStore`.
    func generateEmbedding(text: String) async throws -> [Float] {
        #if targetEnvironment(simulator)
        // Deterministic stub: hash text into a normalized vector for simulator.
        // The simulator doesn't load MLX weights, so we fabricate a stable
        // vector from the raw bytes. This is only used for UI development.
        let dimension = Self.embeddingDimension
        var vec = [Float](repeating: 0, count: dimension)
        for (i, char) in text.utf8.enumerated() {
            let idx = i % dimension
            vec[idx] += Float(char) * 0.001
        }
        let mag = sqrt(vec.reduce(0) { $0 + $1 * $1 })
        if mag > 0 { vec = vec.map { $0 / mag } }
        return vec
        #else
        guard let container = embeddingContainer, isEmbeddingLoaded else {
            throw ModelError.embeddingModelNotLoaded
        }

        // Run the bge-small forward pass and extract the raw CLS token.
        //
        // IMPORTANT: We do pooling manually instead of using MLXEmbedders'
        // `Pooling` module. The `.cls` strategy in MLXEmbedders uses
        // `inputs.pooledOutput` — which is BERT's built-in `tanh(pooler(CLS))`
        // trained for next-sentence-prediction, NOT the raw CLS hidden state.
        // sentence-transformers bge-small was trained to use the RAW CLS
        // token (equivalent to MLXEmbedders' `.first` strategy), so we take
        // it directly from `hiddenStates[:, 0, :]` and L2-normalize manually.
        //
        // Fully qualify `MLXLMCommon.Tokenizer` — without the prefix Swift
        // cannot decide between it and `Tokenizers.Tokenizer` (swift-transformers).
        let dim = Self.embeddingDimension
        let embedding: [Float] = await container.perform {
            (model: EmbeddingModel, tokenizer: MLXLMCommon.Tokenizer, _: Pooling) -> [Float] in

            // Tokenize. BERT max 512; truncate defensively even though chunks
            // are capped at 400 tokens upstream.
            var ids = tokenizer.encode(text: text, addSpecialTokens: true)
            if ids.count > 512 {
                ids = Array(ids.prefix(512))
            }

            // Single-item "batch": shape [1, seqLen]
            let inputArray = MLXArray(ids.map { Int32($0) })
                .reshaped([1, ids.count])
            // Mask is all ones — no padding since batch size is 1.
            // Bert.swift casts the mask to the embedding dtype internally,
            // so Int32 is fine.
            let mask = MLXArray.ones([1, ids.count], dtype: .int32)
            let tokenTypes = MLXArray.zeros(like: inputArray)

            // Forward pass through the embedding model
            let modelOutput = model(
                inputArray,
                positionIds: nil,
                tokenTypeIds: tokenTypes,
                attentionMask: mask
            )

            // Extract the raw CLS token: hiddenStates shape is
            // [batch=1, seqLen, hidden=384] → cls shape [1, 384].
            guard let hidden = modelOutput.hiddenStates else {
                return [Float](repeating: 0, count: dim)
            }
            var cls = hidden[0..., 0, 0...]

            // L2-normalize along the feature axis so cosine similarity works
            // the same way regardless of input length. Done manually with
            // explicit math to avoid ambiguity between MLX and MLXEmbedders
            // both exposing `l2Normalized()` extensions.
            let squared = cls * cls
            let sumSq = squared.sum(axes: [-1], keepDims: true)
            let norm = MLX.sqrt(sumSq + MLXArray(Float(1e-12)))
            cls = cls / norm
            cls.eval()

            // Shape [1, 384] — extract the first (and only) row.
            let vec: [Float] = cls[0].asArray(Float.self)
            return vec
        }

        // Safety: if the model returned the wrong size, pad/truncate.
        if embedding.count == dim {
            return embedding
        } else if embedding.count > dim {
            return Array(embedding.prefix(dim))
        } else {
            return embedding + [Float](repeating: 0, count: dim - embedding.count)
        }
        #endif
    }

    // MARK: - Memory Management

    /// Update memory usage estimate
    private func updateMemoryUsage() {
        // Memory estimates per CLAUDE.md:
        // Gemma 4 E2B-it (4-bit): ~3.3GB on disk, ~2.5GB resident
        // bge-small-en-v1.5 (fp32): ~383MB on disk, ~130MB resident

        var totalMB = 0

        if isLoaded {
            totalMB += 2500 // Gemma 4 E2B LLM (4-bit)
        }

        if isEmbeddingLoaded {
            totalMB += 130 // bge-small-en-v1.5 embeddings (fp32)
        }

        memoryUsageMB = totalMB
    }

    /// Unload LLM model to free memory
    func unloadModel() {
        #if !targetEnvironment(simulator)
        llmContainer = nil
        #endif
        isLoaded = false
        updateMemoryUsage()
        Self.logger.info("LLM unloaded")
    }

    /// Unload embedding model to free memory
    func unloadEmbedding() {
        #if !targetEnvironment(simulator)
        embeddingContainer = nil
        #endif
        isEmbeddingLoaded = false
        updateMemoryUsage()
        Self.logger.info("Embedding model unloaded")
    }

    // MARK: - Utilities

    /// Get model directory URL from Resources
    private func getModelURL(path: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else {
            Self.logger.warning("Resource URL not found")
            return nil
        }

        let modelURL = resourceURL
            .appendingPathComponent("Models")
            .appendingPathComponent(path)

        Self.logger.debug("Model path: \(modelURL.path)")

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Self.logger.warning("Model directory not found at \(modelURL.path)")
            return nil
        }

        return modelURL
    }
}

// MARK: - Types

extension ModelRuntime {
    enum ModelError: Error, CustomStringConvertible {
        case modelNotFound(path: String)
        case modelFilesIncomplete(missing: [String])
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
            case .modelFilesIncomplete(let missing):
                return "Model files incomplete: missing \(missing.joined(separator: ", "))"
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

// MARK: - TokenizerLoader

#if !targetEnvironment(simulator)
/// Bridges a HuggingFace swift-transformers Tokenizer to the MLXLMCommon.Tokenizer protocol.
private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

/// Loads a tokenizer from a local model directory using HuggingFace swift-transformers.
struct HuggingFaceTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}
#endif
