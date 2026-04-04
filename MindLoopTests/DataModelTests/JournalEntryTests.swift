//
//  JournalEntryTests.swift
//  MindLoopTests
//
//  Unit tests for JournalEntry data model
//

import Testing
import Foundation
@testable import MindLoop

@Suite("JournalEntry Tests")
struct JournalEntryTests {
    
    @Test("JournalEntry encodes and decodes correctly")
    func testCodable() throws {
        // Use a fixed whole-second Date to avoid ISO 8601 sub-second precision loss
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let entry = JournalEntry(
            id: "sample-1",
            timestamp: fixedDate,
            text: "I'm feeling stressed about the presentation tomorrow. I keep thinking about all the things that could go wrong.",
            emotion: EmotionSignal(
                label: .anxious,
                confidence: 0.78,
                valence: -0.4,
                arousal: 0.6,
                prosodyFeatures: [:]
            ),
            tags: ["work", "stress", "presentation"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(JournalEntry.self, from: data)

        #expect(decoded == entry)
        #expect(decoded.id == entry.id)
        #expect(decoded.text == entry.text)
        #expect(decoded.emotion == entry.emotion)
        #expect(decoded.tags == entry.tags)
    }
    
    @Test("JournalEntry initializes with default values")
    func testDefaultInitialization() {
        let entry = JournalEntry(
            text: "Test entry",
            emotion: EmotionSignal.sampleNeutral
        )
        
        #expect(!entry.id.isEmpty)
        #expect(entry.tags.isEmpty)
        #expect(entry.text == "Test entry")
    }
    
    @Test("JournalEntry preview truncates long text")
    func testPreview() {
        let shortText = "Short text"
        let shortEntry = JournalEntry(
            text: shortText,
            emotion: EmotionSignal.sampleNeutral
        )
        #expect(shortEntry.preview == shortText)
        
        let longText = String(repeating: "a", count: 150)
        let longEntry = JournalEntry(
            text: longText,
            emotion: EmotionSignal.sampleNeutral
        )
        #expect(longEntry.preview.count == 103) // 100 chars + "..."
        #expect(longEntry.preview.hasSuffix("..."))
    }
    
    @Test("JournalEntry word count is accurate")
    func testWordCount() {
        let entry1 = JournalEntry(
            text: "One two three",
            emotion: EmotionSignal.sampleNeutral
        )
        #expect(entry1.wordCount == 3)
        
        let entry2 = JournalEntry(
            text: "Word   with    extra    spaces",
            emotion: EmotionSignal.sampleNeutral
        )
        #expect(entry2.wordCount == 4)
        
        let entry3 = JournalEntry(
            text: "",
            emotion: EmotionSignal.sampleNeutral
        )
        #expect(entry3.wordCount == 0)
    }
    
    @Test("JournalEntry formatted date is readable")
    func testFormattedDate() {
        let date = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let entry = JournalEntry(
            id: "test",
            timestamp: date,
            text: "Test",
            emotion: EmotionSignal.sampleNeutral
        )
        
        #expect(!entry.formattedDate.isEmpty)
        #expect(entry.formattedDate.contains("2021"))
    }
    
    @Test("JournalEntry formatted time is readable")
    func testFormattedTime() {
        let entry = JournalEntry(
            text: "Test",
            emotion: EmotionSignal.sampleNeutral
        )
        
        #expect(!entry.formattedTime.isEmpty)
        #expect(entry.formattedTime.contains(":"))
    }
}
