//
//  ModelRuntimeTests.swift
//  MindLoopTests
//
//  Tests for MLX model loading and generation
//  MLX requires physical device with Metal GPU — tests skip on simulator
//

import Testing
import Foundation
@testable import MindLoop

#if targetEnvironment(simulator)
@MainActor
@Suite("ModelRuntime Tests (Simulator - Skipped)")
struct ModelRuntimeTests {

    @Test("Simulator tests skipped - MLX requires physical device")
    func testSimulatorSkip() async throws {
        print("ModelRuntime tests require a physical device with Metal GPU")
        print("MLX does not work on iOS Simulator")
        print("Build verification: ModelRuntime compiles successfully")
    }
}
#else
@MainActor
@Suite("ModelRuntime Tests")
struct ModelRuntimeTests {

    // MARK: - Model Loading

    @Test("Load Gemma 4 E2B model from disk")
    func testLoadGemmaModel() async throws {
        let runtime = ModelRuntime.shared

        try await runtime.loadModel(modelPath: "gemma-4-e2b-it-4bit")

        #expect(runtime.isLoaded == true)
        #expect(runtime.memoryUsageMB > 0)
    }

    @Test("Generate text with Gemma 4 E2B")
    func testTextGeneration() async throws {
        let runtime = ModelRuntime.shared

        if !runtime.isLoaded {
            try await runtime.loadModel(modelPath: "gemma-4-e2b-it-4bit")
        }

        var fullResponse = ""
        for await token in runtime.generate(prompt: "What's one small thing I can do today?", maxTokens: 50) {
            fullResponse += token
        }

        #expect(fullResponse.count > 10)
    }

    // MARK: - Embeddings

    @Test("Generate embedding with gte-small (384-dim)")
    func testEmbedding() async throws {
        let runtime = ModelRuntime.shared

        let embedding = try await runtime.generateEmbedding(text: "I'm feeling anxious about tomorrow")

        #expect(embedding.count == 384)

        let maxVal = embedding.max() ?? 0
        let minVal = embedding.min() ?? 0
        #expect(maxVal <= 2.0)
        #expect(minVal >= -2.0)
    }

    @Test("Embedding latency is under 50ms")
    func testEmbeddingPerformance() async throws {
        let runtime = ModelRuntime.shared

        let start = Date()
        _ = try await runtime.generateEmbedding(text: "I'm feeling anxious")
        let duration = Date().timeIntervalSince(start)

        #expect(duration < 0.05, "Embedding should be <50ms, got \(Int(duration * 1000))ms")
    }

    // MARK: - Memory

    @Test("Memory usage stays within 2GB budget")
    func testMemoryBudget() async throws {
        let runtime = ModelRuntime.shared

        if !runtime.isLoaded {
            try await runtime.loadModel(modelPath: "gemma-4-e2b-it-4bit")
        }

        #expect(runtime.memoryUsageMB <= 2000, "Memory \(runtime.memoryUsageMB)MB exceeds 2GB budget")
    }
}
#endif
