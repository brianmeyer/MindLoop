import Foundation

/// A semantic chunk of a journal entry, split at emotion/prosody boundaries
/// Used to handle entries that exceed embedding model token limits (~400 tokens)
struct SemanticChunk: Identifiable, Codable, Sendable {
    /// Unique identifier: "entry-{parentId}_chunk-{index}"
    let id: String

    /// Parent journal entry ID
    let parentEntryId: String

    /// Zero-based chunk index within parent entry
    let chunkIndex: Int

    /// Chunk text content
    let text: String

    /// Start time within parent entry audio (seconds)
    let startTime: TimeInterval

    /// End time within parent entry audio (seconds)
    let endTime: TimeInterval

    // MARK: - Aggregate Emotion

    /// Dominant emotion label for this chunk (most frequent)
    let dominantEmotion: EmotionSignal.Label

    /// Average emotion confidence across segments in chunk
    let emotionConfidence: Float

    /// Average valence (-1.0 = negative, +1.0 = positive)
    let valence: Float

    /// Average arousal (0.0 = calm, 1.0 = excited)
    let arousal: Float

    // MARK: - Aggregate Prosody

    /// Average pitch in Hz (from OpenSMILE features)
    let avgPitch: Float?

    /// Average energy/volume (0.0-1.0, from OpenSMILE features)
    let avgEnergy: Float?

    /// Average speaking rate in syllables/second (from OpenSMILE features)
    let avgSpeakingRate: Float?

    /// Estimated token count (used for chunking algorithm)
    let tokenCount: Int

    /// Timestamp when chunk was created
    let createdAt: Date

    // MARK: - Initialization

    init(
        parentEntryId: String,
        chunkIndex: Int,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        dominantEmotion: EmotionSignal.Label,
        emotionConfidence: Float,
        valence: Float,
        arousal: Float,
        avgPitch: Float? = nil,
        avgEnergy: Float? = nil,
        avgSpeakingRate: Float? = nil,
        tokenCount: Int,
        createdAt: Date = Date()
    ) {
        self.id = "\(parentEntryId)_chunk-\(chunkIndex)"
        self.parentEntryId = parentEntryId
        self.chunkIndex = chunkIndex
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.dominantEmotion = dominantEmotion
        self.emotionConfidence = emotionConfidence
        self.valence = valence
        self.arousal = arousal
        self.avgPitch = avgPitch
        self.avgEnergy = avgEnergy
        self.avgSpeakingRate = avgSpeakingRate
        self.tokenCount = tokenCount
        self.createdAt = createdAt
    }
}

// MARK: - Computed Properties

extension SemanticChunk {
    /// Duration of chunk in seconds
    var duration: TimeInterval {
        endTime - startTime
    }

    /// Human-readable duration string (e.g., "0:30")
    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Summary emotion string for UI display
    var emotionSummary: String {
        let confidencePercent = Int(emotionConfidence * 100)
        return "\(dominantEmotion.rawValue) (\(confidencePercent)%)"
    }
}

// MARK: - Equatable

extension SemanticChunk: Equatable {
    static func == (lhs: SemanticChunk, rhs: SemanticChunk) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension SemanticChunk: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
