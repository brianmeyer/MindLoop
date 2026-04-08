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

    @Test("Initial state is idle")
    func testInitialState() {
        let downloader = ModelDownloader.shared
        #expect(downloader.state == .idle)
        #expect(downloader.progress == 0.0)
        #expect(downloader.isModelAvailable == false)
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
    func testCancelDownload() {
        let downloader = ModelDownloader.shared
        downloader.cancelDownload()
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
