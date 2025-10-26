# PERSONALIZATION.md

**MindLoop Personalization Architecture**

---

## 1. Purpose & Scope

MindLoop personalizes the coaching experience to each user's emotional patterns, preferences, and history — while staying **local-first, safe, predictable, and non-clinical**.

This document defines how personalization works, in two phases:

| Phase | Name | Method | Goal |
|-------|------|--------|------|
| **Phase A (v1)** | Adaptive Personalization Layer | Agent-based + prompt-variable adaptation | Fast, stable, on-device personalization |
| **Phase B-1 (v2)** | On-Device Adaptive Model Layer | Local LoRA fine-tuning (rare, opt-in) | Deeper long-term personalization |

---

## 2. Core Principles

- **Privacy-first** → personalization data never leaves device
- **Safety-first** → SafetyAgent always overrides personalization
- **Explainability** → user can see, reset, or modify personalization
- **Lightweight-first** → Phase A must feel instant
- **User-controlled** → opt-in for deeper personalization (Phase B-1)

---

## 3. Data Inputs for Personalization

The personalization system uses the following signals:

| Input Type | Examples | Used For |
|------------|----------|----------|
| **Emotion Signals** | Prosody (OpenSMILE), sentiment labels | tone + pacing adjustments |
| **User Feedback** | 👍/👎, editing responses, skipping flows | tuning tone, length, question frequency |
| **Journal Metadata** | timestamps, tags, action results | pattern detection (sleep, work triggers) |
| **Behavioral Patterns** | rumination loops, avoidance, repeated themes | when to slow down/reframe |
| **Preferences** | tone, action type preference, length | shaping response delivery |

---

## 4. Personalization Profile (Core Data Structure)

This profile evolves over time and is passed into the CoachAgent.

```json
{
  "tone_pref": "warm|direct|cheerful|neutral",
  "response_length": "short|medium|long",
  "emotion_triggers": ["work_stress", "sleep_rumination"],
  "avoid_topics": [],
  "preferred_actions": ["reframing", "breathing"],
  "quiet_hours": ["00:00-06:00"],
  "last_7d_pattern": "sunday_anxiety",
  "rumination_likelihood": 0.4
}
```

### Storage Rules
- SQLite + encrypted blob
- Updated incrementally, never during Safety-critical events
- User can "Reset Personalization" anytime

### Retention
- **Journals**: permanent unless user deletes
- **Audio**: deleted post-STT
- **Emotion summaries**: aggregated, not raw logs

---

## 5. PHASE A (v1) — Adaptive Personalization Layer

**Status**: ✅ In MVP

**Goal**: Personalization through rules, prompts, and agent behavior, **not model retraining**.

### A.1 Behavior It Can Adapt

| Category | Example |
|----------|---------|
| **Tone** | warmer during sadness / more direct during avoidance |
| **Length** | shorter during rumination / longer during clarity |
| **Flow pacing** | more time in reflection or reframing |
| **Strategy preference** | suggest grounding if user favors it |
| **Trigger awareness** | "Work stress seems common — want to set boundaries?" |

### A.2 Pattern Detection

**Time of Day** → late night = gentle tone + grounding

**Day of Week** → recurring Sunday stress

**Emotion Recurrence** → "anxiety + work" pairing

**Rumination Loops** → slow down, break cycle early

#### Detection Logic Examples

| Pattern | Detection Logic |
|---------|----------------|
| `night_anxiety` | 3+ anxious entries between 10pm-12am within 7 days |
| `sunday_anxiety` | 3+ stressful Sundays within 4 weeks |
| `work_stress` | 5+ entries with "work" keyword + anxious/angry emotion |
| `rumination_loop` | 2+ entries with >70% text similarity within 24 hours |
| `breathing_preference` | 5+ 👍 reactions on breathing exercise suggestions |

### A.3 Coach Integration

The CoachAgent MUST:
- read `PersonalizationProfile` each turn
- adapt tone, pacing, and technique selection
- still follow the CBT micro-flow

**Example Adaptations**:

```swift
// Tone adjustment
if profile.tone_pref == "direct" {
    systemPrompt += "\nBe more direct and concise. Avoid excessive warmth."
}

// Length adjustment
let tokenLimit = profile.response_length == "short" ? 60 :
                 profile.response_length == "long" ? 140 : 100

// Pacing adjustment
if profile.last_7d_pattern == "struggles_with_reframing" {
    // Stay in reframe state longer, ask more guiding questions
    minTurnsInReframe = 2 // instead of 1
}

// Strategy preference
if profile.preferred_actions.contains("breathing") {
    // Prioritize breathing exercises in action suggestions
    suggestedActions.insert(breathingExercise, at: 0)
}
```

### A.4 UI Feedback Loop

User can teach the system through:
- **👍/👎 reactions** (after each coach response)
- **Editing a coach response** (shows desired tone/length)
- **Selecting preferred techniques** (implicit preference signal)

### A.5 Safety Boundary (Phase A)

- ❌ If emotion signal is high-arousal, personalization CANNOT soften crisis guidance
- ❌ SafetyAgent ALWAYS overrides final output
- ❌ Personalization CANNOT remove disclaimers or risk steps
- ✅ Can adjust tone/pacing in **safe contexts only**

---

## 6. PHASE B-1 (v2) — On-Device Adaptive Model Layer (LoRA)

**Status**: ❌ Post-MVP (Phase 11 in roadmap)

**Goal**: When enough data exists AND the user opts in, the system can fine-tune a private, local LoRA head for deeper personalization.

### B.1 Trigger Conditions

- ≥ **50 journal entries**
- ≥ **30 feedback samples** (👍/👎 + edits)
- Safety score meets threshold (no crisis events in last 14 days)
- **User opt-in** (explicit consent in Settings)

### B.2 LoRA Workflow (on-device)

1. **Generate mini SFT/DPO dataset** from history
   - Use `learning_log.jsonl` (prompt, chosen, rejected tuples)
   - Filter out Safety-blocked entries
   - Anonymize (SHA-256 hashes for logging only)

2. **Train small LoRA adapter locally** (battery-intensive = run on charger)
   - Use MLX Swift training API
   - Rank: 8-16 (small adapter, <50MB)
   - Epochs: 1-3 (prevent overfitting)
   - Target: 30-60 minutes training time

3. **Validate**:
   - Empathy ≥ 4.0 threshold (run on 10 held-out samples)
   - Safety = clean (no crisis misses on fixtures)
   - Regression tests pass (coach still follows CBT flow)

4. **SHA-256 checksum validation**
   - Store checksum next to adapter
   - Verify before mounting

5. **Mount adapter**
   - Replace previous adapter (keep last 2 versions for rollback)
   - Show user: "Personalization updated based on your feedback"

### B.3 Rollback + Safety

- Keep last known "good" LoRA (versioned: `user_lora_v1`, `user_lora_v2`)
- **Auto-rollback** if:
  - Safety metrics fail (any crisis keyword missed)
  - Empathy score drops below 3.5
  - User gives 3 consecutive 👎 after update
- **Never remove SafetyAgent guardrails** (LoRA cannot override)

### B.4 UI for Phase B-1

**Settings → Advanced Personalization**:
- Toggle: "Enable Deeper Personalization (trains model on your data)"
- Requirements shown: "50 entries, 30 feedback samples"
- Current status: "Training available" or "Not enough data yet"
- Button: "Train Now" (shows estimated time: ~45 min)
- Privacy note: "Training happens on your device. No data sent anywhere."
- Rollback button: "Revert to Previous Version"

---

## 7. Evaluation Metrics

| Metric | Target |
|--------|--------|
| **Empathy (1–5)** | ≥ 4.0 avg |
| **Actionability** | ≥ 1 tiny step/turn |
| **CBT adherence** | ≥ 80% |
| **Safety FN rate** | ~0 |
| **Latency** | ≤ 2s p50 |
| **Pattern accuracy** | ≥ 75% recognizable patterns |
| **User satisfaction** | trending positive |

---

## 8. Public API — LearningLoopAgent (for Orchestrator + Coach)

```swift
protocol LearningLoopAgent {
    /// Update profile based on new feedback event
    func updateProfile(from feedback: FeedbackEvent,
                      emotion: EmotionSignal,
                      entry: JournalEntry) async throws

    /// Get current personalization profile
    func currentProfile() async -> PersonalizationProfile

    /// Save profile to storage
    func save() async throws

    /// Reset all personalization data
    func reset() async throws

    /// Check if Phase B-1 training is available
    func canTrainLoRA() async -> Bool

    /// Trigger Phase B-1 LoRA training (user-initiated)
    func trainLoRA(progressCallback: (Double) -> Void) async throws
}

struct FeedbackEvent {
    let responseID: UUID
    let type: FeedbackType // thumbsUp, thumbsDown, edit
    let editedText: String? // if user edited response
    let timestamp: Date
}

enum FeedbackType {
    case thumbsUp
    case thumbsDown
    case edit(originalText: String, newText: String)
}
```

---

## 9. Non-Goals

- ❌ Cloud training or personalization
- ❌ Diagnoses or therapy claims
- ❌ Emotion manipulation
- ❌ Removing safety requirements
- ❌ Cross-user personalization (each user isolated)

---

## 10. Summary

- **Phase A (MVP)** = fast, private, explainable personalization via agent and prompt behavior
- **Phase B-1 (post-MVP)** = deeper on-device model updates for long-term personalization
- Both remain **fully local, safe, and user-controlled**

---

## 11. Testing Strategy

### Phase A (MVP)
- Create 10 entries with clear pattern (e.g., "work" + "anxious" 5×)
- Verify profile detects `work_stress` trigger
- Verify tone adapts (e.g., more direct after 3× thumbs down on long responses)
- Verify reset button clears all personalization data

### Phase B-1 (post-MVP)
- Generate 50 synthetic entries + 30 feedback samples
- Trigger LoRA training
- Validate empathy score ≥4.0 on held-out set
- Verify safety: run all crisis fixtures, must catch 100%
- Verify rollback works if metrics fail

---

**Last Updated**: 2025-10-26
**Status**: Phase A in MVP, Phase B-1 in Phase 11 (post-MVP)
