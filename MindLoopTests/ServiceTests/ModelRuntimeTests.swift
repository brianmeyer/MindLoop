//
//  ModelRuntimeTests.swift
//  MindLoopTests
//
//  Tests for MLX model loading and generation
//  ⚠️ MLX requires physical device with Metal GPU - tests will skip on simulator
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
        print("⚠️  ModelRuntime tests require a physical device with Metal GPU")
        print("⚠️  MLX does not work on iOS Simulator")
        print("✅  Build verification: ModelRuntime compiles successfully")
    }
}
#else
@MainActor
@Suite("ModelRuntime Tests")
struct ModelRuntimeTests {

    // MARK: - Model Loading Tests

    @Test("Load Qwen3-4B model from disk")
    func testLoadQwen3Model() async throws {
        let runtime = ModelRuntime.shared

        // Path to downloaded model
        let modelPath = "Resources/Models/qwen3-4b-instruct-mlx"

        print("🧪 Testing Qwen3-4B model loading...")

        // Attempt to load model
        try await runtime.loadModel(from: modelPath)

        // Verify model loaded
        #expect(runtime.isLoaded == true)
        #expect(runtime.memoryUsageMB > 0)

        print("✅ Model loaded: \(runtime.memoryUsageMB)MB")
    }

    @Test("Generate text with Qwen3-4B")
    func testTextGeneration() async throws {
        let runtime = ModelRuntime.shared

        // Ensure model is loaded
        if !runtime.isLoaded {
            let modelPath = "Resources/Models/qwen3-4b-instruct-mlx"
            try await runtime.loadModel(from: modelPath)
        }

        print("🧪 Testing text generation...")

        let prompt = "You are a warm, supportive coach. Respond in 2 sentences: What's one small thing I can do today?"

        var fullResponse = ""
        for await token in runtime.generate(prompt: prompt, maxTokens: 50, temperature: 0.7) {
            fullResponse += token
            print(token, terminator: "")
        }
        print() // newline

        // Verify we got a response
        #expect(fullResponse.count > 0)
        #expect(fullResponse.count > 10) // Should be more than a few chars

        print("✅ Generated: \(fullResponse.prefix(100))...")
    }

    // MARK: - Embedding Tests

    @Test("Generate embedding with Qwen3-Embedding-0.6B")
    func testEmbedding() async throws {
        let runtime = ModelRuntime.shared

        print("🧪 Testing Qwen3-Embedding-0.6B (462-dim)...")

        let text = "I'm feeling anxious about tomorrow's presentation"
        let embedding = try await runtime.generateEmbedding(text: text)

        // Qwen3-Embedding-0.6B should produce 462-dim vectors
        #expect(embedding.count == 462)

        // Check values are normalized (roughly -1 to 1)
        let maxVal = embedding.max() ?? 0
        let minVal = embedding.min() ?? 0
        #expect(maxVal <= 2.0)
        #expect(minVal >= -2.0)

        print("✅ Embedding: \(embedding.count)-dim, range: [\(minVal), \(maxVal)]")
    }

    @Test("Embedding latency is under 200ms")
    func testEmbeddingPerformance() async throws {
        let runtime = ModelRuntime.shared

        let text = "I'm feeling anxious about tomorrow's presentation"

        // Measure embedding latency
        let start = Date()
        _ = try await runtime.generateEmbedding(text: text)
        let duration = Date().timeIntervalSince(start)

        print("⏱️  Embedding: \(Int(duration * 1000))ms")

        // Should be under 200ms
        #expect(duration < 0.2, "Embedding should be <200ms, got \(Int(duration * 1000))ms")
    }

    // MARK: - Memory Tests

    @Test("Memory usage stays within budget")
    func testMemoryBudget() async throws {
        let runtime = ModelRuntime.shared

        // Load model if not loaded
        if !runtime.isLoaded {
            let modelPath = "Resources/Models/qwen3-4b-instruct-mlx"
            try await runtime.loadModel(from: modelPath)
        }

        let memoryMB = runtime.memoryUsageMB

        print("💾 Memory usage: \(memoryMB)MB")

        // Should be under 3.5GB total
        #expect(memoryMB <= 3500, "Memory usage \(memoryMB)MB exceeds 3.5GB budget")
    }
}
#endif
