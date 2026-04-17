//
//  ModelDownloaderTests.swift
//  MindLoopTests
//
//  Tests for ModelDownloader — model availability checks and state management.
//  Actual downloads are not tested (requires network).
//

import Testing
import Foundation
@testable import MindLoop

@MainActor
@Suite("ModelDownloader Tests")
struct ModelDownloaderTests {

    @Test("Initial state is idle or ready (singleton persists across runs)")
    func testInitialState() {
        let downloader = ModelDownloader.shared
        // Singleton state persists across tests/sim runs — in the simulator,
        // testSimulatorSkipsDownload may have already moved it to .ready.
        #expect(downloader.state == .idle || downloader.state == .ready)
        #expect(downloader.isModelAvailable == (downloader.state == .ready))
    }

    @Test("modelDirectoryURL points to Documents/gemma-4-e2b-it-4bit")
    func testModelDirectoryURL() {
        let downloader = ModelDownloader.shared
        let url = downloader.modelDirectoryURL
        #expect(url.lastPathComponent == "gemma-4-e2b-it-4bit")
        #expect(url.path.contains("Documents"))
    }

    #if targetEnvironment(simulator)
    @Test("Simulator skips download and reports ready")
    func testSimulatorSkipsDownload() async {
        let downloader = ModelDownloader.shared
        await downloader.ensureModelAvailable()
        #expect(downloader.state == .ready)
        #expect(downloader.isModelAvailable == true)
    }
    #endif

    @Test("Cancel resets state to idle")
    func testCancelDownload() async {
        let downloader = ModelDownloader.shared
        downloader.cancelDownload()
        // cancelDownload() schedules the reset via Task { @MainActor in ... };
        // yield so the queued task runs before we assert.
        await Task.yield()
        #expect(downloader.state == .idle)
        #expect(downloader.progress == 0.0)
    }

    @Test("State equatable works correctly")
    func testStateEquatable() {
        #expect(ModelDownloader.State.idle == ModelDownloader.State.idle)
        #expect(ModelDownloader.State.ready == ModelDownloader.State.ready)
        #expect(ModelDownloader.State.downloading == ModelDownloader.State.downloading)
        #expect(ModelDownloader.State.failed("x") == ModelDownloader.State.failed("x"))
        #expect(ModelDownloader.State.failed("x") != ModelDownloader.State.failed("y"))
        #expect(ModelDownloader.State.idle != ModelDownloader.State.ready)
    }
}
