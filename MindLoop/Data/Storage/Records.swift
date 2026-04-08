//
//  Records.swift
//  MindLoop
//
//  GRDB Record types for database persistence.
//  These bridge between domain models and database tables.
//

import Foundation
import GRDB

// MARK: - JournalEntryRecord

/// GRDB record for journalEntry table
struct JournalEntryRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "journalEntry"

    var id: String
    var timestamp: Date
    var text: String
    var emotionLabel: String
    var emotionConfidence: Double
    var emotionValence: Double
    var emotionArousal: Double
    var emotionProsodyFeatures: String
    var tags: String

    // MARK: - Conversion to/from Domain Model

    init(from entry: JournalEntry) {
        self.id = entry.id
        self.timestamp = entry.timestamp
        self.text = entry.text
        self.emotionLabel = entry.emotion.label.rawValue
        self.emotionConfidence = entry.emotion.confidence
        self.emotionValence = entry.emotion.valence
        self.emotionArousal = entry.emotion.arousal
        self.emotionProsodyFeatures = Self.encodeProsody(entry.emotion.prosodyFeatures)
        self.tags = Self.encodeTags(entry.tags)
    }

    func toDomain() -> JournalEntry {
        let emotion = EmotionSignal(
            label: EmotionSignal.Label(rawValue: emotionLabel) ?? .neutral,
            confidence: emotionConfidence,
            valence: emotionValence,
            arousal: emotionArousal,
            prosodyFeatures: Self.decodeProsody(emotionProsodyFeatures)
        )

        return JournalEntry(
            id: id,
            timestamp: timestamp,
            text: text,
            emotion: emotion,
            tags: Self.decodeTags(tags)
        )
    }

    // MARK: - Encoding Helpers

    private static func encodeTags(_ tags: [String]) -> String {
        (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private static func decodeTags(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func encodeProsody(_ features: [String: Double]) -> String {
        (try? JSONEncoder().encode(features)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    private static func decodeProsody(_ json: String) -> [String: Double] {
        guard let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
}

// MARK: - SemanticChunkRecord

/// GRDB record for semanticChunk table
struct SemanticChunkRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "semanticChunk"

    var id: String
    var parentEntryId: String
    var chunkIndex: Int
    var text: String
    var startTime: Double
    var endTime: Double
    var dominantEmotion: String
    var emotionConfidence: Double
    var valence: Double
    var arousal: Double
    var avgPitch: Double
    var avgEnergy: Double
    var avgSpeakingRate: Double
    var tokenCount: Int
    var embedding: Data?

    // MARK: - Conversion

    init(from chunk: SemanticChunk, embedding: [Float]? = nil) {
        self.id = chunk.id
        self.parentEntryId = chunk.parentEntryId
        self.chunkIndex = chunk.chunkIndex
        self.text = chunk.text
        self.startTime = chunk.startTime
        self.endTime = chunk.endTime
        self.dominantEmotion = chunk.dominantEmotion.rawValue
        self.emotionConfidence = Double(chunk.emotionConfidence)
        self.valence = Double(chunk.valence)
        self.arousal = Double(chunk.arousal)
        self.avgPitch = Double(chunk.avgPitch ?? 0)
        self.avgEnergy = Double(chunk.avgEnergy ?? 0)
        self.avgSpeakingRate = Double(chunk.avgSpeakingRate ?? 0)
        self.tokenCount = chunk.tokenCount
        self.embedding = embedding.map { Self.embeddingToBlob($0) }
    }

    /// Store an embedding as a blob
    static func embeddingToBlob(_ embedding: [Float]) -> Data {
        embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    /// Extract an embedding from a blob
    func embeddingVector() -> [Float]? {
        guard let data = embedding else { return nil }
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }
}

// MARK: - PersonalizationProfileRecord

/// GRDB record for personalizationProfile table
struct PersonalizationProfileRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "personalizationProfile"

    var id: String
    var tonePreference: String
    var responseLength: String
    var emotionTriggers: String
    var avoidTopics: String
    var preferredActions: String
    var lastUpdated: Date
    var userName: String
    var moodValue: Double

    static func makeDefault() -> PersonalizationProfileRecord {
        PersonalizationProfileRecord(
            id: "default",
            tonePreference: "warm",
            responseLength: "medium",
            emotionTriggers: "[]",
            avoidTopics: "[]",
            preferredActions: "[\"breathing\",\"journaling\",\"reframing\"]",
            lastUpdated: Date(),
            userName: "",
            moodValue: 0.5
        )
    }
}

// MARK: - EmotionNodeRecord

/// GRDB record for emotion graph nodes
struct EmotionNodeRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "emotionNode"

    var id: String
    var label: String
    var category: String
    var frequency: Int
    var lastSeen: Date
}

// MARK: - EmotionEdgeRecord

/// GRDB record for emotion graph edges
struct EmotionEdgeRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "emotionEdge"

    var id: Int64?
    var fromId: String
    var toId: String
    var weight: Double
    var edgeType: String
    var createdAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
