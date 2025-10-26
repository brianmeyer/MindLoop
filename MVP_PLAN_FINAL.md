# MindLoop MVP Implementation Plan (FINAL)

**Version**: 2.0
**Date**: 2025-10-26
**Status**: ✅ Ready for Phase 0

---

## Project Constraints

| Constraint | Value |
|------------|-------|
| **Target Device** | iPhone 15+ (A17 Pro minimum) |
| **iOS Version** | 26.0+ |
| **Timeline** | 10-14 weeks |
| **Team Size** | 1-2 developers |
| **Hardware** | M1 MacBook Pro 16GB (for model conversion if needed) |
| **Model Source** | `lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit` |
| **Personalization** | Phase A only (rules-based, no LoRA fine-tuning) |

---

## Success Criteria

**Technical**:
- User can record audio → get transcription → receive CBT coaching (<3s end-to-end)
- All processing on-device (0 network calls)
- Safety gates work (crisis detection → resources, 0% false negatives)
- Personalization adapts to feedback (pattern accuracy ≥75%)
- Hybrid emotion detection (prosody via OpenSMILE + text sentiment)

**Quality**:
- Coach empathy score ≥4.0/5.0
- CBT adherence ≥80%
- Actionability ≥90% (responses have tiny steps)

**Reliability**:
- Crash-free rate >99.5% during TestFlight
- All test suites pass (unit, integration, UI)

---

## Phase 0: Project Setup & Foundation (Week 1)

**Duration**: 4-5 days

### Goals
- Create project structure matching CLAUDE.md
- Set up design tokens
- Establish dependency baseline
- Create core data models

### Deliverables

#### 0.1: Project Structure
- [ ] Create folder structure:
  ```
  MindLoop/
  ├─ App/ (Orchestrator, MindLoopApp)
  ├─ UI/ (Screens/, Components/, Typography, Spacing)
  ├─ Agents/ (8 agent files)
  ├─ Services/ (6 service files)
  ├─ Data/ (Models/, DTOs/, Storage/)
  └─ Resources/ (Assets.xcassets, Models/, Prompts/, CBTCards/)
  ```
- [ ] Move `ContentView.swift` → `UI/Screens/`
- [ ] Create placeholder files for all 8 agents + 6 services

#### 0.2: Design System
- [ ] `Assets.xcassets/Colors/`:
  - Primary, Surface, Text/TextPrimary, TextSecondary, TextTertiary
  - Test in Dark Mode
- [ ] `UI/Typography.swift`:
  ```swift
  enum Typography {
      case titleXL, titleL, body, caption
      var font: Font { /* Dynamic Type support */ }
  }
  ```
- [ ] `UI/Spacing.swift`:
  ```swift
  enum Spacing {
      static let xs: CGFloat = 4
      static let s: CGFloat = 8
      static let m: CGFloat = 12
      static let l: CGFloat = 16
      static let xl: CGFloat = 24
  }
  ```

#### 0.3: Core Data Models
- [ ] `Data/Models/JournalEntry.swift` (id, timestamp, text, emotion, embedding, tags)
- [ ] `Data/Models/EmotionSignal.swift` (label enum, confidence, prosody features)
- [ ] `Data/Models/CBTCard.swift` (id, title, technique, example)
- [ ] `Data/Models/CoachResponse.swift` (text, cited_entries, action, next_state)
- [ ] `Data/Models/PersonalizationProfile.swift` (tone, length, triggers, actions)
- [ ] Add `Codable` + unit tests for each (encode/decode)

#### 0.4: Dependency Setup
**Pre-Approved Dependencies**:
- [ ] Add MLX Swift via SPM: `https://github.com/ml-explore/mlx-swift`
- [ ] Add WhisperKit via SPM: `https://github.com/argmaxinc/WhisperKit`
- [ ] Add swift-snapshot-testing via SPM: `https://github.com/pointfreeco/swift-snapshot-testing`
- [ ] Verify project builds after adding all deps
- [ ] Total app size increase: <100MB (before models)

### Testing Gate 0
- ✅ Project builds without errors on iOS 26 simulator (iPhone 15 Pro)
- ✅ All 5 data models have passing unit tests (20+ tests total)
- ✅ Design tokens work in sample view (no hard-coded colors)
- ✅ Folder structure matches CLAUDE.md exactly
- ✅ No runtime warnings

**Time Estimate**: 4-5 days

---

## Phase 1: Storage & Data Layer (Week 1-2)

**Duration**: 6-7 days

### Goals
- SQLite database with migrations
- Vector storage for embeddings
- BM25 lexical search
- Test fixture library for all future testing

### Deliverables

#### 1.1: SQLite Manager
- [ ] `Data/Storage/SQLiteManager.swift`:
  - Database initialization
  - Connection pooling
  - CRUD for JournalEntry
  - Transaction support
- [ ] Schema:
  ```sql
  CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY,
    timestamp INTEGER NOT NULL,
    text TEXT NOT NULL,
    emotion_label TEXT,
    emotion_confidence REAL,
    embedding BLOB,
    tags TEXT  -- JSON array
  );
  CREATE INDEX idx_timestamp ON journal_entries(timestamp DESC);

  CREATE TABLE personalization_profile (
    user_id TEXT PRIMARY KEY,
    profile_json TEXT NOT NULL,  -- encrypted
    updated_at INTEGER NOT NULL
  );
  ```
- [ ] `Data/Storage/Migrations/` system
- [ ] Unit tests: insert, query, update, delete (30+ tests)

#### 1.2: Vector Index
- [ ] `Data/Storage/VectorIndex.swift`:
  - Store embeddings (BLOB, 384-dim float32)
  - Cosine similarity (Accelerate.framework SIMD)
  - Recency boost: `0.7 × similarity + 0.3 × recency_score`
  - Benchmark: <50ms for top-5 with 10k entries
- [ ] Generate 10k synthetic embeddings for benchmarking
- [ ] Unit tests: search accuracy + performance

#### 1.3: BM25 Service
- [ ] `Services/BM25Service.swift`:
  - Tokenization (whitespace + lowercasing)
  - TF-IDF calculation
  - BM25 scoring (k1=1.5, b=0.75)
  - Top-K retrieval
- [ ] Unit tests: known queries → expected results

#### 1.4: CBT Cards
- [ ] `Resources/CBTCards/cards.json` with 15 cards:
  - Cognitive distortions (8 types)
  - Reframing techniques (4)
  - Behavioral activation (3)
- [ ] Loader utility

#### 1.5: Test Fixture Library (CRITICAL)
**Safety Fixtures** (`MindLoopTests/Fixtures/safety/`):
- [ ] 50 crisis text samples:
  - 15 suicide keywords (varied phrasings)
  - 10 self-harm keywords
  - 10 emergency/crisis contexts
  - 10 false positives ("killing it at work")
  - 5 obfuscation ("su1c1de")
- [ ] Store as JSON: `[{"text": "...", "expected": "BLOCK|ALLOW", "reason": "..."}]`

**Empathy Fixtures** (`MindLoopTests/Fixtures/prompts/`):
- [ ] 20 journal entries (5 anxious, 5 sad, 5 angry, 5 neutral/positive)
- [ ] For each, write gold-standard coach response (human-authored)
- [ ] Score with empathy rubric (target 4-5)

**Audio Fixtures** (`MindLoopTests/Fixtures/audio/`):
- [ ] 10 audio samples (10s each):
  - 2 anxious (fast speech, high pitch)
  - 2 sad (slow, low energy)
  - 2 angry (loud, intense)
  - 2 neutral (calm)
  - 2 with background noise
- [ ] Manual transcription (ground truth for STT)

**Performance Fixtures**:
- [ ] 10k synthetic journal entries for vector search

**Time to create**: 2-3 days (can parallelize with storage work)

### Testing Gate 1
- ✅ Can persist 100 journal entries to SQLite
- ✅ Vector search: top-5 in <50ms (10k entries)
- ✅ BM25 fallback works
- ✅ Migrations run without errors
- ✅ All 50 safety fixtures loaded and validated
- ✅ All 20 empathy fixtures loaded
- ✅ All 10 audio fixtures ready (transcribed)
- ✅ No memory leaks (Instruments check)

**Time Estimate**: 6-7 days

---

## Phase 2: ML Model Integration (Week 2-4)

**Duration**: 10-14 days

### Goals
- Get Qwen3-Instruct-2507 4B running on-device
- Implement dual embedding pipeline
- Set up WhisperKit for STT
- Validate performance budgets

### Deliverables

#### 2.1: Model Acquisition (NO CONVERSION NEEDED!)
- [ ] Download from HuggingFace:
  ```
  Model: lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit
  URL: https://huggingface.co/lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit
  Size: ~2.1GB
  Format: MLX (ready for MLX Swift)
  Quantization: 4-bit (INT4)
  ```
- [ ] Download embedding models:
  - MiniLM-L6-v2 (CoreML, ~80MB) for fast embeddings
  - Qwen3 embeddings (MLX format, ~1.2GB) for quality embeddings
- [ ] Generate SHA-256 checksums for all models
- [ ] Store in `Resources/Models/` with `.sha256` files
- [ ] Create identity LoRA adapter (passthrough for testing)

**Backup plan**: If MLX version has issues, use GGUF with llama.cpp Swift bindings.

#### 2.2: ModelRuntime Service
- [ ] `Services/ModelRuntime.swift`:
  - Load Qwen3 base model (background thread, <3s target)
  - Mount LoRA adapter with checksum verification
  - Generate text with streaming (`AsyncSequence<String>`)
  - Memory tracking (target: ≤2.7GB resident)
  - Timeout handling (3.0s with retry)
- [ ] Unit tests: generate text, verify streaming
- [ ] Performance tests: <2s for 100 tokens

#### 2.3: Embedding Service (Dual-Mode)
- [ ] Add to `Services/ModelRuntime.swift`:
  - Fast mode: MiniLM (<100ms target)
  - Quality mode: Qwen3 embeddings (background queue, <500ms)
  - Output: 384-dim float array
- [ ] Unit tests: dimension verification
- [ ] Performance tests: MiniLM <100ms, Qwen3 <500ms

#### 2.4: WhisperKit Integration
- [ ] `Services/STTService.swift`:
  - Initialize Whisper model (use smallest model for speed)
  - Transcribe with streaming if supported (check docs)
  - Handle timeout (2.5s)
  - Fallback to text input on failure
- [ ] Test with 10 audio fixtures
- [ ] Verify accuracy >90% on clean audio
- [ ] Performance: <500ms for 10s audio

#### 2.5: Model Pre-warming
- [ ] Add to `MindLoopApp.swift`:
  - Load MiniLM immediately (~100ms)
  - Pre-warm Qwen3 in background Task (target <3s)
  - Show loading indicator if models not ready
  - Total launch time target: <5s on iPhone 15 Pro

### Testing Gate 2
**Model Performance**:
- ✅ Qwen3 generates coherent text (100 tokens in <2s on iPhone 15 Pro)
- ✅ Streaming works (tokens arrive progressively)
- ✅ MiniLM embeddings: <100ms per text
- ✅ WhisperKit transcribes fixtures with >90% accuracy
- ✅ All models load within 3s on launch

**Memory Budget**:
- ✅ MiniLM: ≤100MB resident
- ✅ Qwen3 base: ≤2.7GB resident
- ✅ LoRA adapter: ≤150MB additional
- ✅ **Total: ≤3.0GB** (buffer for app overhead)
- ✅ Measured with Instruments on iPhone 15 Pro

**Reliability**:
- ✅ LoRA checksum verification works
- ✅ No crashes on timeout/failure
- ✅ Graceful degradation if models fail to load

**Time Estimate**: 10-14 days (buffer for MLX Swift learning curve)

---

## Phase 3: Agent Implementation (Week 4-6)

**Duration**: 12-14 days

### Goals
- Implement all 8 agents with protocol-based architecture
- Each agent tested in isolation
- Prompts loaded from Resources/Prompts/
- **Personalization Phase A** fully implemented

### Deliverables

#### 3.1: Agent Protocol
- [ ] `Agents/AgentProtocol.swift`:
  ```swift
  protocol Agent {
      associatedtype Input
      associatedtype Output
      func process(_ input: Input) async throws -> Output
  }
  ```

#### 3.2: JournalAgent
- [ ] `Agents/JournalAgent.swift`:
  - Input: raw text + EmotionSignal
  - Output: JournalEntry (normalized, with tags)
  - Prompt: `Resources/Prompts/journal_guide.txt`
- [ ] Create `journal_guide.txt`
- [ ] Unit tests: 5 fixtures → verify tags extraction

#### 3.3: EmotionAgent (Hybrid)
- [ ] `Agents/EmotionAgent.swift`:
  - Input: text + prosody features (from EmotionService)
  - Output: EmotionSignal (label + confidence)
  - Method: Weighted average (0.6 × text_sentiment + 0.4 × prosody_valence)
- [ ] Unit tests: "worried" + high pitch → anxious

#### 3.4: RetrievalAgent
- [ ] `Agents/RetrievalAgent.swift`:
  - Input: JournalEntry + query text
  - Output: Top-5 entries + 1 CBT card
  - Uses VectorStore + BM25 fallback
  - Recency boost formula
- [ ] Unit tests: relevance verification
- [ ] Edge case: empty database → empty results (no crash)

#### 3.5: CoachAgent
- [ ] `Agents/CoachAgent.swift`:
  - Input: JournalEntry + EmotionSignal + RetrievalContext + **PersonalizationProfile**
  - Output: CoachResponse (text, citations, action, next_state)
  - Prompt: `Resources/Prompts/coach_system_v1.txt`
  - Streaming: `streamResponse()` → `AsyncSequence<String>`
  - Non-streaming: `respond()` for tests
  - **Token limit**: 80-120 tokens (measure with `countTokens()`)
- [ ] Create `coach_system_v1.txt` with:
  - CBT micro-flow enforcement
  - Personalization variable injection (tone, pacing)
  - Token budget guidance
- [ ] Unit tests: 3 empathy fixtures → verify tone, actionability, token count
- [ ] Snapshot tests: store outputs in `Fixtures/prompts/coach_v1/`

**Personalization Integration**:
- [ ] Read `PersonalizationProfile` on every turn
- [ ] Inject tone instructions (e.g., "Be more direct and concise")
- [ ] Adjust token limit based on `response_length` (60/100/140)
- [ ] Prioritize preferred actions in suggestions

#### 3.6: SafetyAgent
- [ ] `Agents/SafetyAgent.swift`:
  - Input: candidate response text
  - Output: `ALLOW | BLOCK` + reason
  - Keywords from `Resources/Prompts/safety_keywords.json`
  - PII detection (email, phone, SSN regex)
- [ ] Create `safety_keywords.json`
- [ ] Unit tests: 50 safety fixtures → verify 0% false negatives
- [ ] False positive corpus: 200 normal entries → verify <5% false positives
- [ ] Edge cases: "killing it at work" → ALLOW, "su1c1de" → BLOCK

**False Positive Corpus**:
- [ ] Collect 200 normal journal entries:
  - 50 from public datasets (anonymized)
  - 50 synthetic (LLM-generated "normal day")
  - 50 edge cases (dark humor, strong language)
  - 50 CBT-relevant ("killing negative thoughts")
- [ ] Store in `Fixtures/safety/normal_corpus.json`

#### 3.7: LearningLoopAgent (Phase A - Rules-Based)
- [ ] `Agents/LearningLoopAgent.swift`:
  - Input: Response + feedback (👍/👎) + optional edit
  - Output: Updated PersonalizationProfile
  - Storage: SQLite (encrypted) + `learning_log.jsonl`

**Pattern Detection Logic**:
- [ ] **Time-based**: 3+ anxious entries 10pm-12am → `night_anxiety`
- [ ] **Day-based**: 3+ stressful Sundays in 4 weeks → `sunday_anxiety`
- [ ] **Emotion-topic**: 5+ "work" + "anxious" → `work_stress`
- [ ] **Rumination**: 2+ entries >70% similarity in 24h → `rumination_loop`
- [ ] **Action preference**: 5+ 👍 on breathing → prefer in suggestions

**Adaptation Mechanisms**:
- [ ] Tone adjustment: Update `tone_pref` after 3 consistent feedback signals
- [ ] Length adjustment: Track avg tokens of 👍 vs 👎 responses
- [ ] Pacing: Detect struggling states (user edits reframe responses often)
- [ ] Actions: Track which techniques get 👍, prioritize in future

**NOT in MVP (Phase B-1)**:
- ❌ Local LoRA fine-tuning
- ❌ On-device model training
- ❌ DPO dataset usage (logged for future)

**Unit Tests**:
- [ ] 10 entries with "work" + "anxious" → detect `work_stress` (≥75% confidence)
- [ ] 5 Sunday anxious entries → detect `sunday_anxiety`
- [ ] 5 thumbs down on long responses → `response_length` changes to "short"

#### 3.8: TrendsAgent
- [ ] `Agents/TrendsAgent.swift`:
  - Input: Date range
  - Output: Emotion distribution, entry count, top keywords
  - Pure SQL aggregation (no LLM)
- [ ] Unit tests: 7 days → correct stats

### Testing Gate 3
**Agent Functionality**:
- ✅ All 8 agents have passing unit tests (100+ tests total)
- ✅ CoachAgent generates warm, CBT-structured responses (manual review of 20 samples)
- ✅ SafetyAgent: 0% false negatives on 50 crisis fixtures
- ✅ SafetyAgent: <5% false positives on 200 normal corpus
- ✅ RetrievalAgent relevance: >70% (human-judged on 20 queries)

**Personalization (Phase A)**:
- ✅ Pattern detection works: 10 entries with pattern → profile detects it (≥75% accuracy)
- ✅ Tone adaptation: Repeated feedback → profile adjusts `tone_pref`
- ✅ Length adaptation: Track 👍/👎 → adjust `response_length`

**Token Limits**:
- ✅ All CoachAgent responses: 80-120 tokens
- ✅ If exceeds 120: prompt needs tuning (log warning)

**Time Estimate**: 12-14 days

---

## Phase 4: Orchestrator & Pipeline (Week 6-7)

**Duration**: 5-7 days

### Goals
- Wire all agents together
- Implement CBT state machine
- End-to-end text input → response pipeline

### Deliverables

#### 4.1: CBT State Machine
- [ ] `App/Orchestrator.swift`:
  - Define `CBTState` enum:
    ```swift
    enum CBTState {
        case goal, situation, thoughts, feelings,
             distortions, reframe, action, reflect
    }
    ```
  - State transition logic (based on CoachAgent `next_state` hint)
  - Personalization adjustments (slow down in struggling states)

#### 4.2: Orchestrator Pipeline (12 Steps)
1. **Input normalization** (text or audio path)
2. **Fast context retrieval** (skip for MVP, add in Phase 10)
3. **JournalAgent.normalize()**
4. **Storage.save()**
5. **EmbeddingAgent.enqueueBackground()** (quality embeddings)
6. **LearningLoopAgent.updateProfile()** (if feedback present)
7. **RetrievalAgent.topK()** (top-5 + 1 CBT card)
8. **CoachAgent.respond()** (with PersonalizationProfile)
   - Token count check: if >140, truncate + log warning
9. **SafetyAgent.gate()**
   - If BLOCK → return de-escalation template + resources
10. **Output rendering** (return to UI)
11. **Error handling** (timeout, fallback responses)
12. **Audio cleanup** (N/A for text, handled in Phase 5)

- [ ] Timeout handling at each step
- [ ] Fallback responses on failure

#### 4.3: Session Management
- [ ] Track session state (current CBTState, history)
- [ ] Persist to disk (resume after app restart)
- [ ] Clear on "New Entry" button

### Testing Gate 4
**End-to-End**:
- ✅ Text input → receive coaching response (all 12 steps execute)
- ✅ CBT state transitions correctly (goal → ... → reflect)
- ✅ Safety gate blocks crisis text, shows resources
- ✅ Retrieval injects top-5 relevant entries + 1 CBT card
- ✅ Personalization profile updates after feedback

**Performance**:
- ✅ Response latency <2s on iPhone 15 Pro (10 test entries, average)
- ✅ Memory: orchestrator adds <200MB to budget

**Reliability**:
- ✅ All error paths tested (timeout, model failure, safety block)
- ✅ Orchestrator unit tests pass (with mocked agents)

**Time Estimate**: 5-7 days

---

## Phase 5: Audio Pipeline (Week 7-9)

**Duration**: 8-10 days

### Goals
- Audio recording with waveform visualization
- STT integration (WhisperKit)
- **OpenSMILE prosody extraction** (CRITICAL for MVP)
- Hybrid emotion detection

### Deliverables

#### 5.1: Audio Recording
- [ ] `UI/Components/AudioRecorder.swift`:
  - AVAudioRecorder
  - Real-time waveform (AVAudioPlayer peak levels)
  - Max duration: 60s
  - Save to temp directory (.m4a format)
- [ ] UI state: recording → show waveform, stop button

#### 5.2: STT Integration
- [ ] Wire STTService into Orchestrator
- [ ] Check if WhisperKit supports streaming:
  - **If YES**: Stream partial transcripts every 500ms
  - **If NO**: Show spinner + "Transcribing...", display final only
- [ ] Handle timeout (2.5s) → fallback to text input
- [ ] Delete temp audio after successful transcription

#### 5.3: OpenSMILE Integration (CRITICAL)
**Deliverable**: `Services/EmotionService.swift`

**Why critical**: OpenSMILE provides 6k+ acoustic features (pitch, jitter, shimmer, formants) for accurate emotion detection. Simple AVAudioEngine features are insufficient for clinical-quality prosody.

**Steps**:
- [ ] Download OpenSMILE:
  ```bash
  git clone https://github.com/audeering/opensmile.git
  cd opensmile
  mkdir build && cd build
  cmake -DCMAKE_BUILD_TYPE=Release ..
  make
  ```
- [ ] Create C++ bridging header:
  - [ ] Add `MindLoop-Bridging-Header.h` to Xcode
  - [ ] Include OpenSMILE headers
  - [ ] Verify iOS compatibility (may need adjustments)
- [ ] Integrate extraction:
  ```swift
  // Services/EmotionService.swift
  import OpenSMILE // via bridging header

  func extractProsody(from audioURL: URL) -> ProsodyFeatures {
      // Call OpenSMILE C++ API
      // Extract: pitch (mean, variance), energy, jitter, shimmer, formants
      // Return as Swift struct
  }
  ```
- [ ] Map features to arousal/valence:
  - High pitch variance + high energy → high arousal
  - Low energy + low pitch → low arousal (sad)
  - Fast speech rate → high arousal
- [ ] Return `ProsodyFeatures` (struct with 20-30 key features)

**Testing**:
- [ ] Run on 10 audio fixtures
- [ ] Verify features in expected ranges:
  - Pitch: 80-300Hz
  - Energy: 0-1 normalized
  - Jitter: 0-0.05 (low = calm)
  - Shimmer: 0-0.1
- [ ] Compare with manual labeling (anxious, sad, neutral, angry)

**Time Budget**: 3-4 days (includes C++ bridge setup + testing)

**Fallback**: If OpenSMILE integration fails on iOS, use pre-computed features from research datasets (less accurate but viable).

#### 5.4: Hybrid Emotion Detection
- [ ] Wire EmotionService into Orchestrator (step 1)
- [ ] Merge prosody + text sentiment in EmotionAgent:
  ```swift
  let textScore = textSentiment() // 0-1 (negative to positive)
  let prosodyScore = prosody.valence // 0-1 (from OpenSMILE features)
  let confidence = min(prosody.confidence, textConfidence)

  let finalScore = 0.6 * textScore + 0.4 * prosodyScore
  return EmotionSignal(label: mapToLabel(finalScore), confidence: confidence)
  ```

#### 5.5: Audio → Response Flow
- [ ] Update Orchestrator step 1:
  - If audio: STT → EmotionService → EmotionAgent → merge
  - If text: EmotionAgent only (no prosody)
- [ ] Integration test: record fixture audio → receive response

### Testing Gate 5
**Audio Pipeline**:
- ✅ Record audio → transcribe → get coaching response (full flow works)
- ✅ STT accuracy >90% on 10 clean audio fixtures
- ✅ Waveform visualization shows real-time levels

**OpenSMILE**:
- ✅ Prosody extraction works on all 10 fixtures
- ✅ Features in expected ranges (pitch, energy, jitter, shimmer)
- ✅ Hybrid emotion detection: accuracy >70% vs. manual labels
- ✅ Merge with text sentiment works correctly

**Privacy**:
- ✅ Audio files deleted after transcription (verify with breakpoint)

**Performance**:
- ✅ STT latency <500ms for 10s audio
- ✅ OpenSMILE extraction <200ms
- ✅ End-to-end audio latency <3s (record 10s → response)

**Time Estimate**: 8-10 days (OpenSMILE adds 3-4 days)

---

## Phase 6: UI Implementation (Week 9-11)

**Duration**: 11-13 days

### Goals
- Build all 4 main screens
- Implement streaming response UI
- Add personalization visibility
- Design polish

### Deliverables

#### 6.1: Journal Screen
- [ ] `UI/Screens/JournalScreen.swift`:
  - Large audio recording button (centered)
  - Waveform during recording
  - Text input fallback (TextEditor)
  - Submit button
  - Loading states: recording/transcribing/thinking/responding
- [ ] Streaming response: token-by-token typewriter effect
- [ ] Emotion badge (EmotionBadge component)

#### 6.2: Coach Screen (Conversation View)
- [ ] `UI/Screens/CoachScreen.swift`:
  - Chat bubble UI (user entries + coach responses)
  - Context cards (retrieved memories + CBT card)
  - Action button (e.g., "Try breathing exercise")
  - Feedback buttons (👍/👎) on each response
  - "New Entry" button → restart session
- [ ] Uses Typography + Spacing tokens
- [ ] Dark Mode support

#### 6.3: Timeline Screen
- [ ] `UI/Screens/TimelineScreen.swift`:
  - List of past journal entries (by date)
  - Tap to view full entry + coach response
  - Emotion badges
  - Search bar (BM25 search)
  - Weekly trends section (TrendsAgent)

#### 6.4: Settings Screen
- [ ] `UI/Screens/SettingsScreen.swift`:
  - Voice toggle (TTS on/off)
  - LoRA adapter selector (dropdown, default: tone)
  - "Replay last recording" toggle
  - **Personalization section** (NEW):
    - "What I've Learned About You" header
    - Show detected patterns (e.g., "Work stress on weekdays")
    - Show preferences (tone: warm, length: short, actions: breathing)
    - "Reset Personalization" button (with confirmation alert)
    - Privacy note: "All data stays on your device"
  - Clear all data button (with confirmation)

#### 6.5: Reusable Components
- [ ] `UI/Components/AudioWaveform.swift`
- [ ] `UI/Components/EmotionBadge.swift` (color-coded by emotion)
- [ ] `UI/Components/CBTCard.swift` (card display with technique)
- [ ] `UI/Components/LoadingSpinner.swift` ("thinking..." text)
- [ ] `UI/Components/FeedbackButtons.swift` (👍/👎)

#### 6.6: Navigation
- [ ] Update `MindLoopApp.swift`:
  - NavigationStack with TabView
  - 3 tabs: Journal, Timeline, Settings
  - Initial screen: Journal

#### 6.7: TTS Integration (IN MVP)
- [ ] `Services/TTSService.swift`:
  - Use AVSpeechSynthesizer
  - Speak coach response if voice toggle enabled
  - Stop on user tap/new input
- [ ] Wire into Orchestrator step 10
- [ ] Settings toggle persists to UserDefaults

**Time to add**: 3 hours

### Testing Gate 6
**UI Functionality**:
- ✅ All 4 screens build and render correctly
- ✅ Can record audio → see response in Journal screen
- ✅ Timeline shows past entries
- ✅ Settings persist (voice, LoRA, replay)
- ✅ Personalization section shows detected patterns
- ✅ Reset personalization button clears profile

**UX**:
- ✅ Streaming response animates smoothly (no jank)
- ✅ Dark Mode works on all screens
- ✅ VoiceOver labels on all interactive elements
- ✅ Dynamic Type scaling works

**Quality**:
- ✅ No hard-coded colors/fonts (design token audit)
- ✅ UI tests pass (basic interaction flows)
- ✅ Snapshot tests pass (4 screens × 2 modes = 8 snapshots)

**Time Estimate**: 11-13 days

---

## Phase 7: Polish & Performance (Week 11-12)

**Duration**: 7-8 days

### Goals
- Hit all latency budgets
- Memory optimization
- Bug fixes from dogfooding

### Deliverables

#### 7.1: Performance Optimization
- [ ] Profile with Instruments (Time Profiler):
  - Identify hot paths in vector search
  - Optimize embedding generation (reuse buffers)
  - Ensure no main thread blocking
- [ ] Verify latency budgets on iPhone 15 Pro:
  - STT <500ms ✅
  - Fast embedding <100ms ✅
  - Coach response <2s ✅
  - Vector search <50ms ✅
- [ ] Reduce app launch time (current: <5s, target: <3s)

#### 7.2: Memory Management
- [ ] Profile with Instruments (Leaks & Allocations):
  - Fix any leaks (especially ModelRuntime, OpenSMILE C++ bridge)
  - Verify models unload when unused
  - Check temp audio cleanup
- [ ] Stress test: 100 journal entries, memory stable
- [ ] Final memory check: ≤3.5GB under load

#### 7.3: Dogfooding & Bug Fixes
- [ ] Internal testing (1 week):
  - Record 20+ real journal entries
  - Collect feedback on coach quality
  - Identify edge cases
- [ ] Fix top 10 bugs
- [ ] Improve prompts based on feedback

#### 7.4: Error Handling Audit
- [ ] Test all error paths:
  - Low memory warnings
  - Background app termination
  - Corrupted audio files
  - Empty/invalid input
- [ ] Ensure graceful degradation (no crashes)

### Testing Gate 7
**Performance**:
- ✅ All latency budgets met on iPhone 15 Pro
- ✅ Memory ≤3.5GB under load (100 entries)
- ✅ No memory leaks (Instruments clean)
- ✅ Launch time <3s

**Quality**:
- ✅ 0 crashes during 1-week dogfooding
- ✅ Coach empathy score ≥4.0 (20 samples)
- ✅ CBT adherence ≥80% (20 samples)
- ✅ Safety FN rate = 0% on crisis fixtures

**Tests**:
- ✅ All unit tests pass (200+ tests)
- ✅ All UI tests pass
- ✅ All snapshot tests pass

**Time Estimate**: 7-8 days

---

## Phase 8: Launch Prep (Week 12-14)

**Duration**: 8-9 days

### Goals
- Device testing on iPhone 15/16 Pro
- Privacy audit
- TestFlight release

### Deliverables

#### 8.1: Device Testing
- [ ] Test on 3+ devices:
  - iPhone 16 Pro (A18 Pro) - fastest, baseline
  - iPhone 15 Pro (A17 Pro) - target minimum
  - iPhone 15 (A16 Bionic) - fallback if 15 Pro unavailable
  - iPad Pro (M2) - large screen
- [ ] Performance verification (each device):
  - Model load <3s (measure 3×, average)
  - Response latency p50 <2s (10 entries)
  - STT <500ms (5 audio samples)
  - No thermal throttling (10-minute session)
  - Memory <3.5GB

**If iPhone 15 fails budgets**:
- Update minimum to iPhone 15 Pro (A17 Pro)
- Document: "Requires iPhone 15 Pro or newer"

#### 8.2: Privacy Audit
- [ ] Verify 0 network calls (monitor with Charles Proxy for 1 hour)
- [ ] Audit logs: no PII, only SHA-256 hashes
- [ ] Review App Store privacy labels
- [ ] Test "Delete All Data" functionality
- [ ] Verify OpenSMILE doesn't log raw audio

#### 8.3: App Store Prep
- [ ] Create listing (title, description, keywords)
- [ ] Take screenshots (4 screens × light + dark = 8 images)
- [ ] Demo video (optional)
- [ ] Privacy policy page: "100% on-device, no data collection"

#### 8.4: TestFlight Release
- [ ] Archive build in Xcode
- [ ] Upload to App Store Connect
- [ ] Add 5-10 internal testers
- [ ] Collect feedback (1 week)
- [ ] Fix critical bugs

### Testing Gate 8 (MVP Complete)
**Core Features**:
- ✅ Audio recording → transcription → coaching works
- ✅ Text input fallback works
- ✅ Safety gates: crisis → resources (0% FN)
- ✅ Personalization: feedback → profile updates (≥75% pattern accuracy)
- ✅ Retrieval: past context injected
- ✅ Timeline view works
- ✅ TTS speaks responses (if enabled)

**Performance**:
- ✅ Latency <3s end-to-end (p50 on iPhone 15 Pro)
- ✅ Memory ≤3.5GB
- ✅ Launch time <3s

**Quality**:
- ✅ Coach empathy ≥4.0/5.0 (20 TestFlight samples)
- ✅ CBT adherence ≥80%
- ✅ Actionability ≥90% (tiny steps present)
- ✅ Safety FN rate = 0%

**Reliability**:
- ✅ 0 crashes during 1-week TestFlight (5+ users)
- ✅ All test suites pass

**Privacy**:
- ✅ Privacy audit clean (0 network calls)
- ✅ Audio deleted after STT
- ✅ Logs contain no PII

**Time Estimate**: 8-9 days

---

## Timeline Summary

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 0: Setup | 4-5 days | Week 1 |
| Phase 1: Storage | 6-7 days | Week 2 |
| Phase 2: ML | 10-14 days | Week 4 |
| Phase 3: Agents | 12-14 days | Week 6 |
| Phase 4: Orchestrator | 5-7 days | Week 7 |
| Phase 5: Audio + OpenSMILE | 8-10 days | Week 9 |
| Phase 6: UI | 11-13 days | Week 11 |
| Phase 7: Polish | 7-8 days | Week 12 |
| Phase 8: Launch | 8-9 days | Week 14 |

**Total**: 71-87 days = **10-14 weeks**

---

## Critical Path

```
Phase 0 (Setup)
  ↓
Phase 1 (Storage + Fixtures) ─────→ Phase 3 (Agents need storage + fixtures)
  ↓                                      ↓
Phase 2 (ML Models) ──────────────→ Phase 3 (Agents need ML)
                                        ↓
                                   Phase 4 (Orchestrator)
                                        ↓
                                   Phase 5 (Audio + OpenSMILE)
                                        ↓
                                   Phase 6 (UI)
                                        ↓
                                   Phase 7 (Polish)
                                        ↓
                                   Phase 8 (Launch)
```

**Parallelization**:
- Phase 1 (Storage) + Phase 2 (ML) can overlap slightly
- Multiple agents in Phase 3 can be built in parallel
- UI screens in Phase 6 can be built in parallel

---

## Risk Mitigation

### High-Risk Items

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **OpenSMILE iOS compatibility** | Medium | High | Test C++ bridge early (Week 1), have AVAudioEngine fallback |
| **MLX Swift learning curve** | Medium | Medium | Use lmstudio-community pre-quantized model (no conversion) |
| **Prompt engineering iterations** | High | Medium | Budget 3-4 days in Phase 3, hire CBT consultant if needed |
| **Memory exceeds 3.5GB** | Low | High | Check at Gate 2, 4, 6, 7; unload unused models |
| **Safety false negatives** | Low | Critical | Comprehensive 50-fixture test, manual review of 100+ samples |
| **TestFlight crashes** | Medium | High | Test on 3+ devices, handle all error paths |

### Contingency Plans

**If OpenSMILE fails**:
- Use AVAudioEngine basic prosody (pitch, energy only)
- Quality: empathy score may drop to 3.7-3.9 (still viable)

**If MLX model too slow**:
- Switch to smaller model (Qwen2.5-1.5B)
- Or use GGUF format with llama.cpp Swift

**If prompt quality poor**:
- Hire CBT therapist consultant (budget: $500-1000)
- Iterate with rubric scoring

---

## Success Metrics (Post-Launch)

### Week 1 Targets
- 50+ journal entries across beta testers
- 0 crashes
- Empathy score ≥4.0
- Safety FN rate = 0%

### Week 4 Targets
- 10+ daily active users
- 5+ entries per user (avg)
- D7 retention >40%

---

## Post-MVP Roadmap

**Phase 9**: Real-time context retrieval (fast embeddings during audio)

**Phase 10**: Full OpenSMILE integration (if simplified in MVP)

**Phase 11 (Phase B-1)**: On-device LoRA fine-tuning
- Trigger: ≥50 entries, ≥30 feedback samples, user opt-in
- Training: 30-60 min on-device (M1+ chip)
- Validation: empathy ≥4.0, safety clean

**Phase 12**: Apple Watch quick journaling

**Phase 13**: HealthKit integration

---

## Approved Decisions

✅ **Model**: `lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit`

✅ **Target**: iPhone 15+ (A17 Pro minimum)

✅ **Personalization**: Phase A only (rules-based)

✅ **OpenSMILE**: CRITICAL for MVP (include C++ bridge)

✅ **TTS**: Include in MVP (AVSpeechSynthesizer)

✅ **Timeline**: 10-14 weeks acceptable

✅ **Hardware**: M1 MacBook Pro 16GB available if needed

---

## Next Steps

1. **Approve this plan** ✅
2. **Create project in Xcode** → Start Phase 0.1
3. **Set up folder structure** → Phase 0.1
4. **Add dependencies** → Phase 0.4
5. **Create data models** → Phase 0.3

**Ready to start Phase 0?**

---

**Last Updated**: 2025-10-26
**Status**: ✅ APPROVED - Ready for implementation
**Confidence**: 90% in 10-14 week timeline
