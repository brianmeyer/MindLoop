//
//  FixtureGenerator.swift
//  MindLoop
//
//  Generates realistic fixture data for testing
//  Creates 100 journal entries with varied emotions, topics, and timestamps
//

import Foundation

/// Generates realistic fixture data for testing
struct FixtureGenerator {
    
    /// Generates 100 realistic journal entries
    static func generateJournalEntries() -> [JournalEntry] {
        var entries: [JournalEntry] = []
        let now = Date()
        
        // Generate entries over the past 90 days
        for i in 0..<100 {
            let daysAgo = Double(i) * 0.9 // ~0.9 days between entries
            let timestamp = now.addingTimeInterval(-daysAgo * 86400)
            
            // Select a random template
            let template = templates.randomElement()!
            
            let entry = JournalEntry(
                id: UUID().uuidString,
                timestamp: timestamp,
                text: template.text,
                emotion: template.emotion,
                embeddings: nil, // Will be generated in Phase 2
                tags: template.tags
            )
            
            entries.append(entry)
        }
        
        return entries
    }
    
    // MARK: - Templates
    
    private struct EntryTemplate {
        let text: String
        let emotion: EmotionSignal
        let tags: [String]
    }
    
    private static let templates: [EntryTemplate] = [
        // Work stress
        EntryTemplate(
            text: "I'm feeling overwhelmed with the deadline coming up. So many tasks and not enough time. I keep thinking I'm going to mess everything up.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.85, valence: -0.6, arousal: 0.8),
            tags: ["work", "stress", "deadline"]
        ),
        EntryTemplate(
            text: "Another long day at work. My manager keeps piling on more projects. I don't know how I'm supposed to get it all done. Feeling burnt out.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.78, valence: -0.5, arousal: 0.7),
            tags: ["work", "burnout", "overwhelm"]
        ),
        EntryTemplate(
            text: "The presentation went better than I expected! I was so nervous beforehand, but once I started talking, it felt natural. My team seemed engaged.",
            emotion: EmotionSignal(label: .positive, confidence: 0.82, valence: 0.7, arousal: 0.5),
            tags: ["work", "achievement", "presentation"]
        ),
        
        // Relationships
        EntryTemplate(
            text: "Had a wonderful conversation with my friend today. It reminded me how important these connections are. Feeling grateful for the support.",
            emotion: EmotionSignal(label: .positive, confidence: 0.88, valence: 0.8, arousal: 0.3),
            tags: ["friendship", "gratitude", "connection"]
        ),
        EntryTemplate(
            text: "Got into an argument with my partner. I said things I didn't mean. Now I feel terrible and don't know how to make it right.",
            emotion: EmotionSignal(label: .sad, confidence: 0.75, valence: -0.7, arousal: 0.4),
            tags: ["relationship", "conflict", "regret"]
        ),
        EntryTemplate(
            text: "Spent quality time with family this weekend. We laughed, shared stories, and just enjoyed being together. These moments mean everything.",
            emotion: EmotionSignal(label: .positive, confidence: 0.90, valence: 0.85, arousal: 0.4),
            tags: ["family", "connection", "gratitude"]
        ),
        
        // Self-reflection
        EntryTemplate(
            text: "I've been noticing a pattern. Every time I face a challenge, my first thought is that I can't do it. But when I push through, I usually can. Why do I doubt myself so much?",
            emotion: EmotionSignal(label: .neutral, confidence: 0.65, valence: -0.2, arousal: 0.3),
            tags: ["self-reflection", "doubt", "pattern"]
        ),
        EntryTemplate(
            text: "Today I practiced saying no to things I don't have capacity for. It felt uncomfortable but also freeing. Maybe I'm learning to set boundaries.",
            emotion: EmotionSignal(label: .positive, confidence: 0.72, valence: 0.5, arousal: 0.3),
            tags: ["boundaries", "growth", "self-care"]
        ),
        EntryTemplate(
            text: "Feeling stuck in the same old patterns. I know what I need to change but can't seem to take action. It's frustrating.",
            emotion: EmotionSignal(label: .sad, confidence: 0.70, valence: -0.4, arousal: 0.2),
            tags: ["stuck", "frustration", "change"]
        ),
        
        // Health & wellness
        EntryTemplate(
            text: "Went for a run this morning. My mind was racing before, but the movement helped clear my head. Exercise really does make a difference.",
            emotion: EmotionSignal(label: .positive, confidence: 0.80, valence: 0.6, arousal: 0.6),
            tags: ["exercise", "wellness", "clarity"]
        ),
        EntryTemplate(
            text: "Another night of poor sleep. Woke up feeling exhausted and irritable. The racing thoughts just won't stop when I try to rest.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.82, valence: -0.5, arousal: 0.6),
            tags: ["sleep", "fatigue", "rumination"]
        ),
        EntryTemplate(
            text: "I've been eating better and it's starting to show. More energy, better mood. Small changes are adding up.",
            emotion: EmotionSignal(label: .positive, confidence: 0.76, valence: 0.5, arousal: 0.4),
            tags: ["health", "progress", "self-care"]
        ),
        
        // Anxiety & worry
        EntryTemplate(
            text: "Can't stop thinking about all the things that could go wrong. My mind keeps jumping from one worry to the next. It's exhausting.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.90, valence: -0.7, arousal: 0.9),
            tags: ["anxiety", "worry", "rumination"]
        ),
        EntryTemplate(
            text: "Social event coming up and I'm already dreading it. What if I say something awkward? What if I don't fit in? Why do I do this to myself?",
            emotion: EmotionSignal(label: .anxious, confidence: 0.83, valence: -0.6, arousal: 0.7),
            tags: ["social anxiety", "worry", "catastrophizing"]
        ),
        EntryTemplate(
            text: "Noticed my anxiety spiraling today. Instead of fighting it, I just acknowledged it was there. It helped a bit. Progress, even if small.",
            emotion: EmotionSignal(label: .neutral, confidence: 0.68, valence: 0.1, arousal: 0.4),
            tags: ["anxiety", "acceptance", "mindfulness"]
        ),
        
        // Achievement & progress
        EntryTemplate(
            text: "Finished that project I've been working on for weeks! It's not perfect, but it's done. I'm proud of myself for sticking with it.",
            emotion: EmotionSignal(label: .positive, confidence: 0.85, valence: 0.75, arousal: 0.6),
            tags: ["achievement", "project", "pride"]
        ),
        EntryTemplate(
            text: "Small win today: I responded to that difficult email instead of avoiding it. It wasn't as bad as I built it up to be.",
            emotion: EmotionSignal(label: .positive, confidence: 0.74, valence: 0.4, arousal: 0.3),
            tags: ["achievement", "avoidance", "progress"]
        ),
        EntryTemplate(
            text: "Looking back at my journal from a month ago, I can see how much I've grown. The things that felt impossible then are manageable now.",
            emotion: EmotionSignal(label: .positive, confidence: 0.80, valence: 0.7, arousal: 0.3),
            tags: ["growth", "reflection", "progress"]
        ),
        
        // Sadness & disappointment
        EntryTemplate(
            text: "Didn't get the opportunity I was hoping for. Feeling disappointed and questioning if I'm on the right path.",
            emotion: EmotionSignal(label: .sad, confidence: 0.79, valence: -0.6, arousal: 0.3),
            tags: ["disappointment", "career", "doubt"]
        ),
        EntryTemplate(
            text: "Some days I just feel heavy. No specific reason, just a general sadness that sits with me. It's okay to have these days.",
            emotion: EmotionSignal(label: .sad, confidence: 0.72, valence: -0.5, arousal: 0.2),
            tags: ["sadness", "acceptance", "mood"]
        ),
        EntryTemplate(
            text: "Missing someone who's no longer in my life. The grief comes in waves. Today was a hard wave.",
            emotion: EmotionSignal(label: .sad, confidence: 0.88, valence: -0.8, arousal: 0.4),
            tags: ["grief", "loss", "sadness"]
        ),
        
        // Neutral observations
        EntryTemplate(
            text: "Nothing particularly good or bad happened today. Just a regular day. Sometimes that's okay.",
            emotion: EmotionSignal(label: .neutral, confidence: 0.95, valence: 0.0, arousal: 0.1),
            tags: ["routine", "neutral", "acceptance"]
        ),
        EntryTemplate(
            text: "Noticed how the seasons are changing. Small reminder that everything moves in cycles, including my moods.",
            emotion: EmotionSignal(label: .neutral, confidence: 0.88, valence: 0.1, arousal: 0.2),
            tags: ["observation", "seasons", "perspective"]
        ),
        EntryTemplate(
            text: "Today was productive but uneventful. Got through my tasks, took care of what needed doing. Solid day.",
            emotion: EmotionSignal(label: .neutral, confidence: 0.90, valence: 0.2, arousal: 0.3),
            tags: ["routine", "productivity", "neutral"]
        ),
        
        // Gratitude
        EntryTemplate(
            text: "Three things I'm grateful for today: morning coffee, a kind message from a friend, and the sunset I caught on my way home.",
            emotion: EmotionSignal(label: .positive, confidence: 0.84, valence: 0.7, arousal: 0.3),
            tags: ["gratitude", "appreciation", "mindfulness"]
        ),
        EntryTemplate(
            text: "Even on hard days, there's always something to appreciate. Today it was the simple comfort of my favorite meal.",
            emotion: EmotionSignal(label: .positive, confidence: 0.76, valence: 0.5, arousal: 0.2),
            tags: ["gratitude", "comfort", "perspective"]
        ),
        
        // Stress & overwhelm
        EntryTemplate(
            text: "Everything feels like too much right now. Work, personal life, responsibilities. I need to figure out how to create some breathing room.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.84, valence: -0.7, arousal: 0.8),
            tags: ["overwhelm", "stress", "balance"]
        ),
        EntryTemplate(
            text: "The to-do list keeps growing faster than I can complete it. Trying to remember that I can only do what I can do.",
            emotion: EmotionSignal(label: .anxious, confidence: 0.77, valence: -0.4, arousal: 0.6),
            tags: ["stress", "tasks", "acceptance"]
        ),
        
        // Hope & optimism
        EntryTemplate(
            text: "Things have been tough lately, but I'm starting to see light at the end of the tunnel. Maybe it will get better.",
            emotion: EmotionSignal(label: .positive, confidence: 0.70, valence: 0.5, arousal: 0.3),
            tags: ["hope", "optimism", "perspective"]
        ),
        EntryTemplate(
            text: "Had a moment today where I felt genuinely excited about the future. Haven't felt that in a while. Holding onto this feeling.",
            emotion: EmotionSignal(label: .positive, confidence: 0.82, valence: 0.8, arousal: 0.7),
            tags: ["hope", "excitement", "future"]
        )
    ]
}
