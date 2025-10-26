# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**MindLoop** is an on-device iOS journaling and coaching app that guides users through CBT-style reflections, recalls relevant past moments, and suggests actionable next steps. The app is audio-first with hybrid emotion detection (prosody + text sentiment).

**Bundle Identifier**: `Lycan.MindLoop`
**Platform**: iOS 26.0+ (iPhone & iPad)
**Language**: Swift 5.0+
**UI Framework**: SwiftUI + NavigationStack

**Deployment Target**: iOS 26.0 minimum. Prefer modern Swift Concurrency (`async`/`await`, actors), `@Observable` macro, and latest SwiftUI APIs. **Do not add compatibility shims for older iOS versions.**

### Product Philosophy

**Tone**: Warm, concise, non-clinical. No diagnoses or medical claims.
**Privacy**: 100% on-device processing. No data leaves the device.
**Accessibility**: Audio-first design with full VoiceOver support.

### CBT Micro-Flow

**goal** → **situation** → **thoughts/feelings** → **distortions** → **reframe** → **tiny action** → **reflect**

Each session follows this structure, guided by the Coach Agent with context from past entries.

---

## Architecture

MindLoop uses an **Orchestrator + Agents** pattern where a lightweight orchestrator coordinates multiple single-purpose agents.

### Design Principles

1. **Single Responsibility**: Each agent has one clear job
2. **Offline-First**: All operations work without network
3. **Low Latency**: Sub-2s response time for coaching
4. **Privacy by Design**: No cloud dependencies, no telemetry
5. **Testable Contracts**: Protocol-based agents with mockable dependencies

### Core Components

- **Orchestrator**: Intent routing + CBT state machine coordinator
- **Agents**: Small, single-purpose processing units (see Agent Contracts below)
- **Services**: Infrastructure layer (STT, TTS, storage, ML runtime)
- **UI**: SwiftUI screens and reusable components

---

## Working Agreement for Claude

When working on MindLoop, follow these rules strictly:

### No Cloud Calls
- **All features must run fully on-device.** Do not add network APIs.
- No analytics, telemetry, or crash reporting services.
- No external API dependencies (OpenAI, Anthropic, etc.).

### Keep Builds Green
- **Every PR must compile and keep all tests passing.**
- Fix warnings immediately; do not introduce new runtime warnings.
- Test on iOS 26.0+ simulator before committing.

### Ask Before Adding Dependencies
- **Do not add 3rd-party packages; prefer stdlib/Apple frameworks.**
- If unavoidable (e.g., MLX Swift, WhisperKit, OpenSMILE), propose first with rationale.
- No large UI kits, networking libraries, or analytics SDKs.

### Write Tests With Code
- **New code ships with unit tests** (agents/services).
- **UI changes ship with snapshot/UI tests** when relevant.
- Tests must be deterministic and fast (<5s per suite).

### Follow Design Tokens
- **No hard-coded colors, fonts, or spacing.**
- Use `Assets.xcassets` for colors + `Typography.swift` + `Spacing.swift` for layout.
- Support Dynamic Type and Dark Mode automatically.

### Stay Within Contracts
- **Do not change JSON/data contracts in this file** without discussion.
- If a contract change is required, propose a separate PR with migration plan.

---

## Complete Data Flow

### Main Pipeline (Audio/Text → Response)

```
1. User Audio/Text Input
   ├─ If Audio → STTService.transcribe() → partial + final transcript (streaming)
   ├─ EmotionService.extractProsody(audio) → prosody features
   ├─ EmotionAgent.analyzeText(transcript or text) → sentiment label
   └─ Merge → EmotionSignal

2. Fast Context Retrieval (real-time during audio)
   └─ RetrievalAgent.quickSearch(partialTranscript) → top-3 recent memories
      // Uses lightweight embedding (MiniLM) for <100ms latency

3. Journal Agent.normalize(entry, EmotionSignal)
   └─ Outputs: JournalEntry (structured JSON)

4. Storage.save(normalizedEntry)
   └─ Persists to SQLite with metadata

5. EmbeddingAgent.enqueueBackground(normalizedEntry)
   └─ Runs Qwen3 embeddings in background queue (higher quality)

6. LearningLoopAgent.updateProfile(entry, feedback)
   └─ Adjusts PersonalizationProfile based on user feedback/edits

7. RetrievalAgent.topK(entry, context)
   └─ Returns: top-5 relevant memories + 1 CBT card

8. CoachAgent.streamResponse(entry, EmotionSignal, context, PersonalizationProfile)
   └─ Generates grounded, CBT-structured response (token-by-token streaming)

9. SafetyAgent.gate(candidateResponse)
   ├─ If BLOCK → return templated de-escalation + crisis resources
   └─ If ALLOW → proceed

10. Output Rendering
    ├─ If voice_enabled → TTSService.speak(response)
    └─ Render UI with response, context cards, and action buttons

11. Error Handling
    ├─ STT timeout (2.5s) → fall back to text input with friendly prompt
    ├─ Model timeout (3.0s) → show "thinking...", retry 1×, then fallback response
    ├─ Vector search failure → fall back to BM25 immediately
    ├─ Emotion pipeline failure → proceed with EmotionSignal.confidence = 0.0
    └─ Safety block → log anonymized event (type + timestamp only)

12. Audio Cleanup
    └─ Delete temp audio immediately after successful STT (or keep until session end if "Replay" enabled)
```

### Background Processes

- **Embedding Pipeline**: Full Qwen3 embeddings run after save (non-blocking)
- **Trends Computation**: Weekly aggregations (no LLM, pure stats)
- **LoRA Adapter Updates**: Hot-swappable via app settings (advanced users)
- **Personalization Updates**: Async profile adjustments from user feedback

---

## Project Structure

```
MindLoop/
├─ MindLoop/
│  ├─ App/
│  │  ├─ MindLoopApp.swift         # @main entry point
│  │  └─ Orchestrator.swift        # Central coordinator (intent routing + state machine)
│  │
│  ├─ UI/
│  │  ├─ Screens/
│  │  │  ├─ JournalScreen.swift    # Audio recording + text input
│  │  │  ├─ CoachScreen.swift      # Conversation view with streaming response
│  │  │  ├─ TimelineScreen.swift   # Past entries + trends
│  │  │  └─ SettingsScreen.swift   # Voice, LoRA, privacy controls
│  │  ├─ Components/
│  │  │  ├─ AudioWaveform.swift    # Real-time recording visualizer
│  │  │  ├─ EmotionBadge.swift     # Emotion signal display
│  │  │  └─ CBTCard.swift          # Retrieval context card
│  │  ├─ Typography.swift          # Font + Dynamic Type utilities
│  │  └─ Spacing.swift             # Layout spacing constants
│  │
│  ├─ Agents/                      # Single-file agents (refactor to folders when >200 LOC)
│  │  ├─ JournalAgent.swift        # Guided capture → normalized JournalEntry JSON
│  │  ├─ EmbeddingAgent.swift      # Dual-mode: fast (MiniLM) + quality (Qwen3)
│  │  ├─ RetrievalAgent.swift      # Vector search (top-k) + CBT card selection
│  │  ├─ CoachAgent.swift          # Grounded response generation (Qwen3 + LoRA)
│  │  ├─ SafetyAgent.swift         # Risk keyword detection + boundary gate
│  │  ├─ LearningLoopAgent.swift   # Per-user adaptation + preference tracking
│  │  ├─ TrendsAgent.swift         # Weekly stats (no LLM, pure aggregation)
│  │  └─ EmotionAgent.swift        # Text sentiment classification (hybrid)
│  │
│  ├─ Services/
│  │  ├─ STTService.swift          # WhisperKit (on-device CoreML Whisper) with streaming
│  │  ├─ TTSService.swift          # AVSpeechSynthesizer + optional Neural TTS
│  │  ├─ EmotionService.swift      # OpenSMILE prosody extraction (C++ bridge)
│  │  ├─ VectorStore.swift         # SQLite + SIMD-optimized cosine similarity
│  │  ├─ ModelRuntime.swift        # MLX Swift adapter (Qwen3 + LoRA loading)
│  │  └─ BM25Service.swift         # Lexical search fallback
│  │
│  ├─ Data/
│  │  ├─ Models/                   # Domain models
│  │  │  ├─ JournalEntry.swift     # id, timestamp, text, emotion, embeddings
│  │  │  ├─ EmotionSignal.swift    # prosody features + sentiment label
│  │  │  ├─ CBTCard.swift          # Reusable CBT technique cards
│  │  │  ├─ CoachResponse.swift    # Generated response + metadata
│  │  │  └─ PersonalizationProfile.swift  # User preferences + patterns
│  │  ├─ DTOs/                     # Service layer transfer objects
│  │  │  └─ AgentRequest.swift     # Standardized agent input/output
│  │  └─ Storage/
│  │     ├─ SQLiteManager.swift    # Core DB operations
│  │     ├─ VectorIndex.swift      # Embedding storage + search
│  │     └─ Migrations/            # Schema versioning
│  │
│  └─ Resources/
│     ├─ Assets.xcassets/          # Design tokens
│     │  ├─ Colors/
│     │  │  ├─ Primary.colorset
│     │  │  ├─ Surface.colorset
│     │  │  └─ Text/
│     │  │     ├─ TextPrimary.colorset
│     │  │     ├─ TextSecondary.colorset
│     │  │     └─ TextTertiary.colorset
│     │  └─ Icons/
│     ├─ Models/                   # .mlpackage and .safetensors files
│     │  ├─ qwen3-instruct-4b.mlpackage       # 2.1GB (INT4 quantized base model)
│     │  ├─ qwen3-lora-tone.safetensors       # 45MB (LoRA adapter)
│     │  ├─ qwen3-lora-tone.sha256            # SHA-256 checksum for integrity
│     │  ├─ minilm-embeddings.mlpackage       # 80MB (fast embeddings)
│     │  └─ qwen3-embeddings.mlpackage        # 1.2GB (quality embeddings)
│     ├─ Prompts/                  # Versioned prompt templates
│     │  ├─ coach_system.txt       # Symlink/alias to current version
│     │  ├─ coach_system_v1.txt    # Coach agent system prompt (versioned)
│     │  ├─ journal_guide.txt      # Journal normalization prompt
│     │  └─ safety_keywords.json   # Risk detection keywords
│     └─ CBTCards/                 # Static CBT technique library
│        └─ cards.json             # id, title, technique, example
│
├─ MindLoopTests/
│  ├─ AgentTests/                  # Protocol-based unit tests
│  │  ├─ JournalAgentTests.swift   # Test normalize() with fixtures
│  │  ├─ CoachAgentTests.swift     # Test grounding + CBT flow + personalization
│  │  ├─ SafetyAgentTests.swift    # Test all risk keywords + edge cases
│  │  └─ LearningLoopAgentTests.swift  # Test profile updates + preference tracking
│  ├─ ServiceTests/
│  │  ├─ VectorStoreTests.swift    # Test search accuracy + performance
│  │  └─ EmotionServiceTests.swift # Test with fixture audio files
│  ├─ OrchestratorTests.swift      # End-to-end pipeline with mocked agents
│  └─ Fixtures/
│     ├─ audio/                    # Sample audio files for STT/emotion testing
│     ├─ prompts/                  # Known-good prompt outputs (3 fixtures per version)
│     └─ safety/                   # Crisis fixtures for Safety FN rate testing
│
└─ MindLoopUITests/
   ├─ JournalFlowTests.swift       # Audio recording → response workflow
   ├─ SnapshotTests/               # Visual regression tests
   └─ AccessibilityTests.swift     # VoiceOver + dynamic type
```

---

## Tech Stack & Rationale

Optimized for **low latency** (<2s end-to-end) and **high accuracy** on-device.

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **LLM Runtime** | MLX Swift | Apple Silicon optimized, fastest inference on iOS |
| **Base Model** | Qwen3-Instruct 4B (INT4) | Best quality/size ratio, 2GB on disk |
| **LoRA Adapters** | SafeTensors format | Hot-swappable, <50MB per adapter |
| **Fast Embeddings** | MiniLM (CoreML) | <100ms latency for real-time retrieval |
| **Quality Embeddings** | Qwen3 embeddings (MLX) | Background processing, higher recall |
| **STT** | WhisperKit (CoreML) | Apple-optimized Whisper, <500ms transcription, streaming |
| **TTS** | AVSpeechSynthesizer | Native, instant, 40+ languages |
| **Prosody Analysis** | OpenSMILE (C++ bridge) | Industry standard, 6k+ acoustic features |
| **Vector Search** | SQLite + custom SIMD | No dependencies, Accelerate.framework optimized |
| **BM25** | Pure Swift implementation | Fast lexical fallback when embeddings fail |

### Performance Budgets

| Operation | Target Latency | Fallback |
|-----------|---------------|----------|
| STT (10s audio) | <500ms | Text input |
| Fast embedding | <100ms | Skip real-time context |
| Coach response | <2s | Show "thinking..." spinner |
| TTS (50 words) | <1s | Text-only display |
| Vector search (top-5) | <50ms | BM25 fallback |

### Failure & Timeout Policy

| Component | Timeout | Fallback Behavior |
|-----------|---------|-------------------|
| **STT** | 2.5s | Fall back to text input with friendly prompt |
| **Model generation** | 3.0s | Show "thinking..." once, retry 1× at 1.5s backoff, then return concise fallback |
| **Vector search** | 50ms | Fall back to BM25 immediately; do not block UI |
| **Emotion pipeline** | N/A | Proceed without emotion; mark `EmotionSignal.confidence = 0.0` |
| **Crash guard** | N/A | Never crash on empty/invalid audio or text; sanitize all inputs |

### Performance Do / Don't

**Do:**
- Pre-warm models on launch (background queue)
- Pin one LLM in memory per session (avoid reload churn)
- Use streaming UI updates (partial transcript, token-by-token response)
- Reuse audio/embedding buffers (avoid large temporary allocations in hot paths)

**Don't:**
- Block the main thread for model I/O or vector search
- Allocate large temporary buffers in hot paths
- Reload models mid-session unless user explicitly changes LoRA

---

## Agent Contracts

Each agent implements a protocol with a single primary method. All agents are **stateless** (state lives in Orchestrator).

### JournalAgent
**Purpose**: Normalize raw input into structured JournalEntry
**Input**: Raw text/transcript + EmotionSignal
**Output**: `JournalEntry` (id, timestamp, text, emotion, tags)
**Prompt**: `Prompts/journal_guide.txt`

### EmbeddingAgent
**Purpose**: Dual-mode embeddings (fast + quality)
**Fast Mode**: MiniLM embeddings for real-time retrieval (<100ms)
**Quality Mode**: Qwen3 embeddings in background queue (higher accuracy)
**Output**: 384-dim float vector

### RetrievalAgent
**Purpose**: Fetch relevant context (memories + CBT card)
**Input**: Current entry + query embedding
**Output**: Top-5 JournalEntries + 1 CBTCard (based on detected distortion)
**Method**: Cosine similarity + recency boost (0.7 × similarity + 0.3 × recency)

### CoachAgent
**Purpose**: Generate grounded, CBT-structured response
**Input**:
  - `JournalEntry` (current entry)
  - `EmotionSignal` (hybrid emotion from text + prosody)
  - `RetrievalContext` (top-5 memories + 1 CBT card)
  - **`PersonalizationProfile`** (from LearningLoopAgent; adapts tone, pacing, coaching emphasis)

**Output**: `CoachResponse` (text, cited_entries, suggested_action, next_state)
**Prompt**: `Prompts/coach_system.txt` + RAG context injection
**Model**: Qwen3-Instruct + LoRA adapter
**Constraint**: Response must be **~80–120 tokens** (enforced by Orchestrator post-processing)

**Streaming**: `CoachAgent.streamResponse(...)` returns `AsyncSequence<String>` for token-by-token UI updates. Non-streaming `respond(...)` remains for tests/offline mode.

**Personalization**: Must read `PersonalizationProfile` and adapt:
  - **Tone**: Adjust formality, warmth, directness
  - **Pacing**: Slow down or speed up CBT state transitions
  - **Coaching emphasis**: Spend more time in states where user struggles (e.g., reframing)

### SafetyAgent
**Purpose**: Final gate for risk, PII, medical boundary violations
**Input**: Candidate response text
**Output**: `ALLOW | BLOCK` + reason
**Keywords**: Loaded from `Resources/Prompts/safety_keywords.json`
**Block triggers**: Suicide keywords, self-harm, medical diagnoses, PII patterns
**Non-overridable**: LearningLoopAgent and personalization **never override** SafetyAgent decisions.

### LearningLoopAgent
**Purpose**: Per-user adaptation without model retraining

**Responsibilities**:
1. Track user preferences from explicit feedback (👍/👎) and edits (tone, length, pace, question frequency)
2. Track emotional patterns (e.g., recurring anxious tone at night, anger tied to work, rumination triggers)
3. Maintain a small, on-device **PersonalizationProfile** (see schema below)
4. Provide CoachAgent a summary of this profile on every turn
5. **Never override SafetyAgent decisions**
6. Keep personalization local-only (no syncing or cloud storage)

**PersonalizationProfile Schema**:
```json
{
  "tone_pref": "warm|direct|cheerful|neutral",
  "response_length": "short|medium|long",
  "emotion_triggers": ["work_stress", "sleep_rumination"],
  "avoid_topics": ["..."],
  "preferred_actions": ["breathing", "journaling", "reframing", "behavioral_activation"]
}
```

**How it improves behavior**:
  - Adjust prompt variables (e.g., tone instructions)
  - Adjust action suggestions (prefer user's favored techniques)
  - Adjust state transitions (e.g., spend more time in reframing if user struggles)

**DPO Export** (future): Collected feedback may be exported (user-initiated) as DPO tuples for optional fine-tuning, but this is **not required for v1 behavior**.

**Input**: Response + user feedback (👍/👎) + optional edit
**Output**: Updated `PersonalizationProfile` + DPO tuple (prompt, chosen, rejected) appended to `learning_log.jsonl`
**Storage**: Profile persisted in SQLite; log in app's Documents directory

### TrendsAgent
**Purpose**: Compute weekly statistics (no LLM)
**Input**: Last 7 days of entries
**Output**: Emotion distribution, entry count, top keywords
**Method**: Pure aggregation (COUNT, GROUP BY, etc.)

### EmotionAgent
**Purpose**: Hybrid text sentiment classification
**Input**: Text transcript + prosody features (from EmotionService)
**Output**: `EmotionSignal` (label: neutral/positive/anxious/sad, confidence: 0-1)
**Method**: Weighted average (0.6 × text_sentiment + 0.4 × prosody_valence)

---

## Prompt Governance

All prompts live in `Resources/Prompts/` and are **versioned** for reproducibility and rollback.

### Versioning Strategy

- **File naming**: Use semantic versions like `coach_system_v1.txt`, `coach_system_v2.txt`, etc.
- **Current version**: `coach_system.txt` is a symlink/alias to the active version in code.
- **Git tags**: Tag repo with `prompts-vX.Y` on prompt changes that affect behavior.

### Placeholder Rules

Prompts may include **placeholders only** for:
  - `{ENTRY}` – Current journal entry text
  - `{CONTEXT}` – Retrieved memories + CBT card
  - `{EMOTION}` – Emotion signal (label + confidence)
  - `{STATE}` – Current CBT state (goal, situation, thoughts, etc.)
  - `{PERSONALIZATION}` – Summary of PersonalizationProfile

**Do not** introduce arbitrary placeholders without updating this list.

### Coach Prompt Requirements

The **Coach** prompt must:
1. Enforce the CBT micro-flow (goal → situation → thoughts/feelings → distortions → reframe → action → reflect)
2. Cap responses at **~80–120 tokens** (enforced by Orchestrator post-processing)
3. Maintain warm, non-clinical tone
4. Cite retrieved context when relevant
5. Suggest one concrete tiny action per turn

### Testing Requirements

When updating prompts:
1. **Unit tests** must assert key phrases appear in outputs (e.g., "reframe", "tiny step")
2. **Snapshot outputs** for 3 fixtures (anxious, neutral, positive) stored in `MindLoopTests/Fixtures/prompts/`
3. Run empathy rubric on new outputs before merging

---

## CBT Flow State Machine

The Orchestrator maintains a `CBTState` enum to guide the conversation flow:

```swift
enum CBTState {
    case goal           // "What would you like to work on today?"
    case situation      // "Tell me more about the situation..."
    case thoughts       // "What thoughts came up?"
    case feelings       // "How did that make you feel?"
    case distortions    // [Auto-detect + suggest reframe]
    case reframe        // "What's another way to look at this?"
    case action         // "What's one tiny step you could take?"
    case reflect        // "How does that feel now?"
}
```

**State Transitions**: Managed by Orchestrator based on CoachAgent's structured output (includes `next_state` hint).

**Personalization**: LearningLoopAgent may suggest spending more time in certain states (e.g., if user struggles with reframing, slow down transition out of `reframe` state).

**Prompts**: Each state has a corresponding prompt template in `Prompts/coach_system.txt` with placeholders for context injection.

---

## Safety & Guardrails

### Risk Detection Keywords

Loaded from `Resources/Prompts/safety_keywords.json`:

```json
{
  "suicide": ["kill myself", "end it all", "not worth living", "suicide"],
  "self_harm": ["cut myself", "hurt myself", "self-harm"],
  "crisis": ["emergency", "can't go on", "no way out"]
}
```

**Detection**: Case-insensitive substring matching + context window (5 words before/after).

### De-escalation Response Template

If `SafetyAgent.gate()` returns `BLOCK`:

```
I hear that you're going through a really tough time. While I'm here
to support your reflection, I'm not equipped for crisis situations.

Please reach out to someone who can help right now:

📞 National Suicide Prevention Lifeline: 988
💬 Crisis Text Line: Text HOME to 741741
🌐 findahelpline.com (international)

You don't have to go through this alone. ❤️
```

### Medical Boundary

If Coach tries to suggest diagnoses or medications:
- SafetyAgent blocks with: *"I can't provide medical advice. Please consult a licensed professional."*

### PII Detection

Block responses containing:
- Email addresses (regex: `\S+@\S+\.\S+`)
- Phone numbers (regex: `\d{3}[-.\s]?\d{3}[-.\s]?\d{4}`)
- SSNs, credit cards (basic pattern matching)

### PII & Logging Rules

**Audio Retention Policy**:
- **Default**: Delete temp audio **immediately after successful STT**.
- **Optional setting**: "Replay last recording" → Keep encrypted until session end, then delete.
- **Never** persist raw audio in logs or analytics.

**Logging Policy**:
- Logs may contain **hashes and counters only**—no raw text, PII, or model outputs.
- When Safety blocks, store only:
  - Anonymized event type (e.g., `"safety_block_suicide"`)
  - Timestamp
  - **No user text or response content**

**Hash Algorithm**: Use **SHA-256** for anonymization.

---

## Personalization & Learning Loop

The **LearningLoopAgent** is responsible for **per-user adaptation** over time without requiring model retraining.

### How It Works

1. **Track Preferences**: Monitor explicit feedback (👍/👎) and edits to infer:
   - Tone preference (warm/direct/cheerful/neutral)
   - Response length (short/medium/long)
   - Question frequency (high/low)

2. **Track Emotional Patterns**: Identify recurring patterns:
   - Time-based triggers (e.g., anxious at night)
   - Topic-based triggers (e.g., anger tied to work discussions)
   - Rumination triggers (e.g., repetitive negative thoughts)

3. **Maintain PersonalizationProfile**: Store on-device in SQLite:
   ```json
   {
     "tone_pref": "warm",
     "response_length": "short",
     "emotion_triggers": ["work_stress", "sleep_rumination"],
     "avoid_topics": [],
     "preferred_actions": ["breathing", "journaling", "reframing"]
   }
   ```

4. **Inject into CoachAgent**: On every turn, pass profile summary to Coach prompt.

5. **Adapt Behavior**:
   - **Prompt adjustments**: Add tone instructions (e.g., "Be more direct and concise")
   - **Action suggestions**: Prefer techniques user responds well to
   - **State transitions**: Slow down in states where user struggles (e.g., more time reframing)

### What It Does NOT Do

- **Does NOT override SafetyAgent** (safety is non-negotiable)
- **Does NOT sync to cloud** (100% local)
- **Does NOT retrain models** (adaptation via prompt engineering only)

### Future: DPO Export

Users may optionally export `learning_log.jsonl` containing:
```json
{"prompt": "...", "chosen": "...", "rejected": "..."}
```

This can be used for offline DPO fine-tuning, but is **not required for v1**.

---

## Design System

Use semantic design tokens; **no hard-coded colors, fonts, or spacing**.

### Colors

All colors live in `Resources/Assets.xcassets/Colors/`:

```
Colors/
├─ Primary.colorset
├─ Surface.colorset
└─ Text/
   ├─ TextPrimary.colorset
   ├─ TextSecondary.colorset
   └─ TextTertiary.colorset
```

**Usage**:
```swift
Color("Primary")
Color("Text/TextPrimary")
```

### Typography

Defined in `UI/Typography.swift`:

```swift
enum Typography {
    case titleXL
    case titleL
    case body
    case caption

    var font: Font {
        switch self {
        case .titleXL: return .system(size: 32, weight: .bold)
        case .titleL: return .system(size: 24, weight: .semibold)
        case .body: return .system(size: 17, weight: .regular)
        case .caption: return .system(size: 14, weight: .regular)
        }
    }
}
```

**Dynamic Type**: All fonts must support Dynamic Type scaling automatically.

### Spacing

Defined in `UI/Spacing.swift`:

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}
```

**Usage**:
```swift
.padding(Spacing.m)
VStack(spacing: Spacing.l) { ... }
```

---

## Streaming UI States

The UI must reflect the following states during the audio-to-response pipeline:

| State | Description | UI Behavior |
|-------|-------------|-------------|
| **recording** | User is speaking | Show waveform visualizer, real-time amplitude |
| **transcribing** | STT in progress | Stream partial transcripts to UI (live text updates) |
| **thinking** | LLM generating response | Show spinner + "thinking..." message |
| **responding** | Coach response streaming | Token-by-token text appears (typewriter effect) |
| **idle** | No active processing | Default state, show past entries/timeline |

### Contract Addition: Streaming

**`CoachAgent.streamResponse(...)`**:
- **Returns**: `AsyncSequence<String>` for token-by-token streaming
- **Non-streaming alternative**: `CoachAgent.respond(...)` remains for tests/offline mode

**Example**:
```swift
for await token in await coachAgent.streamResponse(entry, emotion, context, profile) {
    // Update UI with each token
    responseText += token
}
```

---

## Testing Strategy

### Unit Tests (Per Agent)

**Protocol-based testing**: Each agent implements an `Agent` protocol, allowing dependency injection of mocked services.

```swift
// Example: JournalAgentTests.swift
@Test func testNormalizeWithAnxiousEmotion() {
    let agent = JournalAgent(modelRuntime: MockModelRuntime())
    let input = "I'm worried about the presentation tomorrow"
    let emotion = EmotionSignal(label: .anxious, confidence: 0.8)

    let entry = agent.normalize(input, emotion: emotion)

    #expect(entry.tags.contains("work"))
    #expect(entry.emotion.label == .anxious)
}
```

**Fixture Audio Files**: Store in `MindLoopTests/Fixtures/audio/` for STT/Emotion testing.

### Integration Tests (Orchestrator)

**Full pipeline with stub agents**:
```swift
@Test func testEndToEndAudioJournaling() {
    let orchestrator = Orchestrator(
        stt: MockSTTService(),
        agents: [/* stub agents */]
    )
    let audioData = loadFixture("anxious_entry.m4a")

    let response = await orchestrator.process(audio: audioData)

    #expect(response.emotion.label == .anxious)
    #expect(response.coachResponse.contains("reframe"))
}
```

### Service Tests

**VectorStore**:
- Test retrieval accuracy with known embeddings
- Benchmark search latency (<50ms for 10k entries)

**EmotionService**:
- Test prosody extraction with fixture audio (happy, sad, neutral)
- Validate feature ranges (pitch: 80-300Hz, energy: 0-1, etc.)

### UI Tests

**Snapshot Tests**: Use `swift-snapshot-testing` for key screens
**Interaction Tests**: Simulate audio recording → response flow
**Accessibility Tests**: Verify VoiceOver labels, dynamic type scaling

### Safety Agent Tests

**Comprehensive keyword coverage**:
```swift
@Test func testSuicideKeywordDetection() {
    let agent = SafetyAgent()
    let response = "I'm thinking about ending it all"

    let result = agent.gate(response)

    #expect(result == .block)
}
```

**Edge Cases**:
- False positives (e.g., "I'm killing it at work" should ALLOW)
- Obfuscation attempts (e.g., "su1c1de" should BLOCK)

### LearningLoopAgent Tests

**Profile Updates**:
```swift
@Test func testPreferenceTrackingFromFeedback() {
    let agent = LearningLoopAgent()
    let profile = PersonalizationProfile.default

    // User repeatedly thumbs down long responses
    let updatedProfile = agent.updateProfile(profile, feedback: .thumbsDown, responseLength: 150)

    #expect(updatedProfile.response_length == "short")
}
```

---

## Model Management

### Storage Location

All models stored in `Resources/Models/` and bundled with the app (increases app size by ~3GB).

```
Resources/Models/
├─ qwen3-instruct-4b.mlpackage       # 2.1GB (INT4 quantized)
├─ qwen3-lora-tone.safetensors       # 45MB (adapter only)
├─ qwen3-lora-tone.sha256            # SHA-256 checksum for integrity verification
├─ minilm-embeddings.mlpackage       # 80MB
└─ qwen3-embeddings.mlpackage        # 1.2GB
```

### Loading Order & Memory Budget

**On App Launch**:
1. **Load MiniLM embeddings** (fast) immediately (~80MB resident memory)
2. **Pre-warm Qwen3-Instruct base** in background queue (target <3s, ~2.5GB resident)
3. **Mount LoRA adapter** after base is ready (~100MB additional)
4. **Verify adapter checksum** (SHA-256) before mounting; refuse to load on mismatch

**Memory Budget**: Keep total resident model memory **≤ 3.5 GB**.
- Qwen3 base: ~2.5GB
- LoRA adapter: ~100MB
- MiniLM embeddings: ~80MB
- Qwen3 embeddings (background only): ~500MB peak during embedding

**Unload unused adapters** when switching to free memory.

### Integrity Check

**SHA-256 Checksum Verification**:
- Store expected checksum in `.sha256` file next to each `.safetensors` adapter.
- Verify checksum before mounting:
  ```swift
  guard verifyChecksum(adapter: "qwen3-lora-tone.safetensors") else {
      fatalError("LoRA adapter checksum mismatch! Refusing to load.")
  }
  ```

### LoRA Hot-Swapping

**In SettingsScreen**:
```swift
// User selects new adapter
ModelRuntime.shared.loadAdapter(named: "qwen3-lora-empathy")
```

### Updating Models

**Via Xcode**:
1. Replace file in `Resources/Models/`
2. Update corresponding `.sha256` checksum file
3. Clean build folder (`Cmd+Shift+K`)
4. Rebuild

**Via OTA** (Future):
- Download `.safetensors` adapter + `.sha256` to app's Documents directory
- Verify checksum
- Update UserDefaults pointer
- Call `ModelRuntime.shared.loadAdapter()`

---

## Build & Development

### Open in Xcode
```bash
open MindLoop/MindLoop.xcodeproj
```

### Build for Simulator
```bash
xcodebuild -project MindLoop/MindLoop.xcodeproj \
  -scheme MindLoop \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

### Run All Tests
```bash
# Unit tests
xcodebuild test -project MindLoop/MindLoop.xcodeproj \
  -scheme MindLoop \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MindLoopTests

# UI tests
xcodebuild test -project MindLoop/MindLoop.xcodeproj \
  -scheme MindLoop \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MindLoopUITests
```

### Run Single Test
```bash
xcodebuild test -project MindLoop/MindLoop.xcodeproj \
  -scheme MindLoop \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MindLoopTests/SafetyAgentTests/testSuicideKeywordDetection
```

### Performance Profiling

**Time Profile** (measure agent latency):
```bash
xcodebuild -project MindLoop/MindLoop.xcodeproj \
  -scheme MindLoop \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test -enablePerformanceTestsDiagnostics YES
```

**Memory Leaks** (especially for model loading):
- Run in Xcode with Instruments → Leaks
- Focus on `ModelRuntime` and `VectorStore` lifecycle

### Common Workflows

**Adding a new agent**:
1. Create `NewAgent.swift` in `Agents/`
2. Implement `Agent` protocol
3. Add to `Orchestrator.agents` array
4. Write tests in `MindLoopTests/AgentTests/NewAgentTests.swift`

**Updating prompts**:
1. Create new version: `Resources/Prompts/coach_system_v2.txt`
2. Update symlink: `coach_system.txt` → `coach_system_v2.txt`
3. Add 3 fixture snapshots in `MindLoopTests/Fixtures/prompts/`
4. Tag repo: `git tag prompts-v2.0`
5. Test with `CoachAgentTests`

**Adding a CBT card**:
1. Edit `Resources/CBTCards/cards.json`
2. Add entry: `{"id": "card_X", "title": "...", "technique": "...", "example": "..."}`
3. RetrievalAgent will automatically pick it up

---

## Definition of Done (per PR)

Before merging any PR, verify:

- [ ] **Follows CBT micro-flow**: Response adheres to goal → situation → thoughts → distortions → reframe → action → reflect
- [ ] **Warm, non-clinical tone**: No diagnoses, medical claims, or overly technical language
- [ ] **iOS 26 build passing**: No new runtime warnings or build errors
- [ ] **Tests added/updated**:
  - Agent/service unit tests for new code
  - Snapshot/UI tests for UI changes
  - Safety tests for any prompt changes
- [ ] **No hard-coded colors/fonts**: All UI uses design tokens (Colors/, Typography, Spacing)
- [ ] **Response length enforced**: Coach responses are ~80–120 tokens (verified by Orchestrator)
- [ ] **No new packages**: Or justification provided + approved
- [ ] **Prompts updated?**: Added 3 fixture snapshots + unit tests asserting key phrases
- [ ] **Latency within budgets**: Tested on fixtures (STT <500ms, response <2s)

---

## PR Checklist

Copy this checklist into every PR description:

```markdown
## PR Checklist

- [ ] Builds on iOS 26 simulator
- [ ] New/changed code has tests
- [ ] No hard-coded colors/fonts; uses tokens
- [ ] Prompts updated? Added tests + snapshots
- [ ] No new packages; or justification provided
- [ ] Latency within budgets on fixtures
- [ ] No runtime warnings introduced
- [ ] CBT flow and tone verified
- [ ] Response length enforced (~80–120 tokens)
```

---

## Evaluation Metrics (weekly)

Track these metrics weekly to ensure quality and safety:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Empathy score** | ≥4.0 (out of 5) | Human rubric on 20 sampled turns |
| **CBT adherence** | ≥80% | % turns hitting ≥4 of 6 CBT steps |
| **Actionability** | ≥90% | % turns with 1 concrete tiny step |
| **Safety FN rate** | ~0% | Must catch all crisis fixtures (no false negatives) |
| **Latency p50** | <2s | End-to-end audio → response on fixtures |
| **Latency p95** | <3s | 95th percentile latency |
| **Retrieval hit rate** | ≥70% | Human-judged relevance@3 on fixtures |

### Empathy Rubric (summary)

Score each sampled turn **1–5**:
- **1** = Dismissive, overly clinical, or robotic
- **3** = Acknowledges + some validation, neutral tone
- **5** = Warm, concise validation + forward movement (tiny step)

**Criteria**: Acknowledgment, validation, non-judgmental tone, brevity, actionable nudge.

> Full rubric lives in `docs/eval_empathy.md` (TODO).

---

## Key Architectural Decisions

### Why On-Device?
- **Privacy**: No user data leaves device (HIPAA/GDPR friendly)
- **Latency**: Sub-2s response time (no network round-trips)
- **Reliability**: Works offline (plane mode, poor connection)

### Why MLX Swift?
- **Performance**: 2-3x faster than CoreML for LLMs on Apple Silicon
- **Flexibility**: Easy LoRA loading, INT4/INT8 quantization
- **Future-proof**: Apple's ML direction (see MLX announcement)

### Why Dual Embeddings?
- **Real-time**: MiniLM gives <100ms embeddings during audio recording (shows relevant context live)
- **Quality**: Qwen3 embeddings in background improve retrieval accuracy over time

### Why SQLite over CoreData?
- **Vector Search**: Custom SIMD cosine similarity (Accelerate.framework)
- **Portability**: Easier to export/backup user data
- **Performance**: Direct SQL control for complex queries

### Why Not Use OpenAI/Anthropic APIs?
- **Privacy**: APIs require sending user journal entries to cloud
- **Cost**: ~$0.01/entry at scale = unsustainable
- **Latency**: Network + queue time = 3-5s (2x our budget)

### Why Personalization Without Retraining?
- **Latency**: Retraining would take hours on-device
- **Privacy**: Keeps all user data local (no cloud fine-tuning)
- **Flexibility**: Prompt-based adaptation is faster to iterate

---

## Non-Goals

**Do not** introduce these features (scope boundaries):

- ❌ **Cloud inference or storage** (privacy violation)
- ❌ **Diagnoses, medical, or legal advice** (safety boundary)
- ❌ **Multi-tenant sync or accounts** (future consideration)
- ❌ **Large third-party UI kits or network dependencies** (keep app lean)
- ❌ **Social features** (sharing, groups, etc.) — privacy-first = single-user

---

## Future Enhancements

- **Multi-modal Emotion**: Add facial expression analysis (Vision framework)
- **Group Therapy Mode**: Multi-user journaling with shared context (E2E encrypted sync)
- **LoRA Fine-tuning Loop**: Auto-train adapters from LearningLoopAgent feedback
- **Apple Watch**: Quick voice journaling from wrist
- **HealthKit Integration**: Correlate mood trends with sleep/exercise data

---

## Support & Documentation

- **Bug Reports**: [GitHub Issues](https://github.com/brianmeyer/MindLoop/issues)
- **Architecture Diagrams**: See `docs/architecture.md` (TODO)
- **Prompt Engineering Guide**: See `docs/prompts.md` (TODO)
- **Empathy Rubric**: See `docs/eval_empathy.md` (TODO)

---

**Last Updated**: 2025-10-26
**iOS Target**: 26.0+
**Swift Version**: 5.0+
**Maintained by**: Brian Meyer ([@brianmeyer](https://github.com/brianmeyer))
