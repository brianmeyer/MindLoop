//
//  JournalAgentTests.swift
//  MindLoopTests
//
//  Tests for JournalAgent: text normalization, tag extraction, and entry creation.
//

import Testing
import Foundation
@testable import MindLoop

struct JournalAgentTests {

    private let agent = JournalAgent()

    // MARK: - Text Normalization

    @Test func normalizeTrimsWhitespace() {
        let entry = agent.normalize(
            text: "   Hello world   ",
            emotion: .sampleNeutral
        )
        #expect(entry.text == "Hello world")
    }

    @Test func normalizeCollapsesMultipleNewlines() {
        let entry = agent.normalize(
            text: "First paragraph.\n\n\nSecond paragraph.\n\n\n\nThird paragraph.",
            emotion: .sampleNeutral
        )
        #expect(entry.text == "First paragraph.\nSecond paragraph.\nThird paragraph.")
    }

    @Test func normalizeRemovesLeadingPunctuationArtifacts() {
        let entry = agent.normalize(
            text: "...So I was thinking about work today",
            emotion: .sampleNeutral
        )
        #expect(entry.text == "So I was thinking about work today")
    }

    @Test func normalizeRemovesTrailingPunctuationArtifacts() {
        let entry = agent.normalize(
            text: "I felt really tired today,,,",
            emotion: .sampleNeutral
        )
        #expect(entry.text == "I felt really tired today")
    }

    @Test func normalizePreservesTrailingSentenceEnder() {
        let entry = agent.normalize(
            text: "How do I handle this?",
            emotion: .sampleNeutral
        )
        #expect(entry.text == "How do I handle this?")
    }

    @Test func normalizeHandlesMessySTTOutput() {
        let messyText = "  ,,,  So I had this meeting with my boss today... \n\n\n  and it went badly...  \n\n  "
        let entry = agent.normalize(text: messyText, emotion: .sampleNeutral)

        // Should be trimmed, newlines collapsed, leading artifacts removed
        #expect(!entry.text.hasPrefix(" "))
        #expect(!entry.text.hasPrefix(","))
        #expect(!entry.text.contains("\n\n"))
    }

    // MARK: - Tag Extraction: Work

    @Test func extractsWorkTagFromWorkKeywords() {
        let workTexts = [
            "I had a terrible meeting today",
            "My boss was really critical",
            "The deadline is stressing me out",
            "My coworker said something hurtful",
            "I can't focus at the office"
        ]
        for text in workTexts {
            let entry = agent.normalize(text: text, emotion: .sampleNeutral)
            #expect(entry.tags.contains("work"), "Expected 'work' tag for: \(text)")
        }
    }

    // MARK: - Tag Extraction: Relationship

    @Test func extractsRelationshipTag() {
        let entry = agent.normalize(
            text: "I had an argument with my partner last night",
            emotion: .sampleNeutral
        )
        #expect(entry.tags.contains("relationship"))
    }

    @Test func extractsFamilyRelationshipTag() {
        let entry = agent.normalize(
            text: "My mom called and we had a long talk about family stuff",
            emotion: .sampleNeutral
        )
        #expect(entry.tags.contains("relationship"))
    }

    // MARK: - Tag Extraction: Health

    @Test func extractsHealthTag() {
        let entry = agent.normalize(
            text: "I didn't sleep well and I'm so tired",
            emotion: .sampleNeutral
        )
        #expect(entry.tags.contains("health"))
    }

    // MARK: - Tag Extraction: Mood-Derived

    @Test func extractsAnxietyMoodTag() {
        let entry = agent.normalize(
            text: "Something happened today",
            emotion: .sampleAnxious
        )
        #expect(entry.tags.contains("anxiety"))
    }

    @Test func extractsSadnessMoodTag() {
        let entry = agent.normalize(
            text: "Something happened today",
            emotion: .sampleSad
        )
        #expect(entry.tags.contains("sadness"))
    }

    @Test func extractsPositivityMoodTag() {
        let entry = agent.normalize(
            text: "Something happened today",
            emotion: .samplePositive
        )
        #expect(entry.tags.contains("positivity"))
    }

    @Test func neutralEmotionProducesNoMoodTag() {
        let entry = agent.normalize(
            text: "Something happened today",
            emotion: .sampleNeutral
        )
        #expect(!entry.tags.contains("anxiety"))
        #expect(!entry.tags.contains("sadness"))
        #expect(!entry.tags.contains("positivity"))
    }

    // MARK: - Tag Extraction: Multiple Tags

    @Test func extractsMultipleTags() {
        let entry = agent.normalize(
            text: "I'm tired from work and my boss was difficult in the meeting",
            emotion: .sampleAnxious
        )
        #expect(entry.tags.contains("work"))
        #expect(entry.tags.contains("health"))
        #expect(entry.tags.contains("anxiety"))
    }

    @Test func tagsAreUnique() {
        let entry = agent.normalize(
            text: "work work work job meeting office",
            emotion: .sampleNeutral
        )
        // "work" should appear only once even though multiple work keywords match
        let workCount = entry.tags.filter { $0 == "work" }.count
        #expect(workCount == 1)
    }

    @Test func tagsAreSorted() {
        let entry = agent.normalize(
            text: "I'm tired from work and my partner is upset",
            emotion: .sampleAnxious
        )
        // Tags should be in sorted order
        let sorted = entry.tags.sorted()
        #expect(entry.tags == sorted)
    }

    // MARK: - Empty / Edge Cases

    @Test func emptyTextProducesEmptyEntry() {
        let entry = agent.normalize(text: "", emotion: .sampleNeutral)
        #expect(entry.text.isEmpty)
        #expect(entry.tags.isEmpty)
    }

    @Test func whitespaceOnlyTextProducesEmptyEntry() {
        let entry = agent.normalize(text: "   \n\n  \t  ", emotion: .sampleNeutral)
        #expect(entry.text.isEmpty)
    }

    @Test func punctuationOnlyTextProducesEmptyEntry() {
        let entry = agent.normalize(text: "...,,,---", emotion: .sampleNeutral)
        #expect(entry.text.isEmpty)
    }

    // MARK: - Entry Properties

    @Test func entryHasGeneratedUUID() {
        let entry = agent.normalize(text: "Test entry", emotion: .sampleNeutral)
        #expect(!entry.id.isEmpty)
        // Verify it looks like a UUID (36 chars with hyphens)
        #expect(entry.id.count == 36)
    }

    @Test func entryHasCurrentTimestamp() {
        let before = Date()
        let entry = agent.normalize(text: "Test entry", emotion: .sampleNeutral)
        let after = Date()

        #expect(entry.timestamp >= before)
        #expect(entry.timestamp <= after)
    }

    @Test func entryAttachesEmotionSignal() {
        let emotion = EmotionSignal.sampleAnxious
        let entry = agent.normalize(text: "I feel worried", emotion: emotion)

        #expect(entry.emotion.label == .anxious)
        #expect(entry.emotion.confidence == emotion.confidence)
        #expect(entry.emotion.valence == emotion.valence)
        #expect(entry.emotion.arousal == emotion.arousal)
    }

    @Test func entryHasNilEmbeddings() {
        let entry = agent.normalize(text: "Test entry", emotion: .sampleNeutral)
        #expect(entry.embeddings == nil)
    }

    @Test func twoEntriesHaveDifferentIDs() {
        let entry1 = agent.normalize(text: "First", emotion: .sampleNeutral)
        let entry2 = agent.normalize(text: "Second", emotion: .sampleNeutral)
        #expect(entry1.id != entry2.id)
    }

    // MARK: - Case Insensitivity

    @Test func tagExtractionIsCaseInsensitive() {
        let entry = agent.normalize(
            text: "I had a MEETING with my BOSS at the OFFICE",
            emotion: .sampleNeutral
        )
        #expect(entry.tags.contains("work"))
    }
}
