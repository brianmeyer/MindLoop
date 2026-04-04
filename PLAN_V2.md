# MindLoop v2 Plan: Updated Architecture & Roadmap

**Date**: 2026-04-04
**Status**: Proposed — replaces MVP_PLAN_FINAL.md
**Branch**: `claude/evaluate-ios-app-VajSn`

---

## What Changed Since v1 Plan

| Decision | v1 (Oct 2025) | v2 (Apr 2026) | Why |
|----------|---------------|---------------|-----|
| **LLM** | Qwen3-4B-Instruct (2.1GB) | Gemma 4 E2B-it 4-bit (~1GB) | Half the size, "any-to-any" multimodal, Apache 2.0, MLX-ready. Upgrade path to E4B later. |
| **Embeddings** | Qwen3-Embedding-0.6B (320MB) | gte-small 4-bit (~15MB) | 20x smaller, MTEB ~61 vs ~62, 384-dim. More than sufficient for journal similarity. |
| **Prosody** | OpenSMILE C++ bridge | Apple native (SFVoiceAnalytics + SpeechAnalyzer) | Zero dependencies. Pitch, jitter, shimmer, speaking rate, pause duration — enough for 4-category emotion. |
| **STT** | Apple Speech Framework (SFSpeechRecognizer) | iOS 26 SpeechAnalyzer (SpeechTranscriber) | Newer, modular, better on-device performance. Replaces WhisperKit dependency too. |
| **Embedding dim** | 462 | 384 | Matches gte-small output. Update VectorStore + schema. |
| **App bundle** | ~3GB models | ~1.1GB models | Gemma4 E2B (~1GB) + gte-small (~15MB) + overhead |

---

## Updated Tech Stack

| Component | Technology | Size | Rationale |
|-----------|-----------|------|-----------|
| **LLM** | Gemma 4 E2B-it (MLX 4-bit) | ~1GB | Smallest Gemma 4, any-to-any multimodal, Apache 2.0 |
| **Embeddings** | gte-small (MLX 4-bit) | ~15MB | Best quality/size ratio at this tier (MTEB ~61) |
| **STT** | SpeechAnalyzer (iOS 26) | 0 | Native, modular, no dependency |
| **TTS** | AVSpeechSynthesizer | 0 | Already implemented, works |
| **Prosody** | SFVoiceAnalytics + SpeechRecognitionMetadata | 0 | Native pitch/jitter/shimmer + speaking rate/pauses |
| **Sound Classification** | SoundAnalysis (SNClassifySoundRequest) | 0 | ~300 built-in categories (laughter, crying, etc.) |
| **Vector Search** | SQLite + SIMD cosine similarity | 0 | Already implemented, production-ready |
| **BM25** | Pure Swift | 0 | Already implemented |

### Memory Budget (Revised)

| Model | Resident Memory |
|-------|----------------|
| Gemma 4 E2B (4-bit) | ~1.5GB |
| gte-small (4-bit) | ~50MB |
| **Total** | **~1.6GB** (down from 3.5GB) |

---

## Updated Pipeline

### Before (v1 — 6 stages)
```
Audio → STT → Text → EmotionService(OpenSMILE prosody) → EmotionAgent(text sentiment)
→ merge → CoachAgent(text + emotion + context) → SafetyAgent → TTS
```

### After (v2 — simplified)
```
Audio → SpeechAnalyzer ──→ Transcript + Prosody (pitch, rate, pauses)
                        └─→ EmotionAgent (prosody + text → 4-label classification)
                        └─→ SoundAnalysis (optional: laughter/crying detection)

Transcript → EmbeddingAgent (gte-small, 384-dim)
          → RetrievalAgent (vector search + BM25 fallback)
          → CoachAgent (Gemma4 E2B + emotion + context + personalization)
          → SafetyAgent (keyword gate)
          → TTS / UI
```

### Key Simplifications
1. **SpeechAnalyzer gives us STT + prosody in one pass** — no separate OpenSMILE pipeline
2. **SFVoiceAnalytics provides per-segment**: pitch, jitter, shimmer, voicing
3. **SFSpeechRecognitionMetadata provides**: speakingRate, averagePauseDuration
4. **EmotionAgent combines native prosody + text sentiment** — simple weighted classifier, no C++ bridge
5. **Gemma 4 E2B handles coaching** — smaller, faster, same MLX Swift integration

---

## Emotion Detection Strategy (Without OpenSMILE)

### Available Native Features

| Feature | Source | What it tells us |
|---------|--------|-----------------|
| **Pitch (F0)** | SFVoiceAnalytics.pitch | High pitch + high variance → anxious; Low pitch → sad |
| **Jitter** | SFVoiceAnalytics.jitter | Voice instability → stress/anxiety |
| **Shimmer** | SFVoiceAnalytics.shimmer | Amplitude variation → emotional arousal |
| **Voicing** | SFVoiceAnalytics.voicing | Voiced vs unvoiced ratio |
| **Speaking Rate** | SFSpeechRecognitionMetadata.speakingRate | Fast → anxious; Slow → sad/reflective |
| **Pause Duration** | SFSpeechRecognitionMetadata.averagePauseDuration | Long pauses → sadness, hesitation |
| **Sound Events** | SoundAnalysis | Crying, laughter, sighing (supplementary) |

### Classification Rules (v1 — rule-based, no ML needed)

```
Anxious: high pitch variance + fast speaking rate + high jitter
Sad:     low pitch + slow speaking rate + long pauses + high shimmer
Positive: moderate pitch + moderate rate + low jitter + low shimmer
Neutral:  baseline values across all features
```

Weighted: `0.6 × text_sentiment + 0.4 × prosody_classification`

This is simpler than OpenSMILE's 6000+ features but sufficient for 4 categories. We can always add a small on-device classifier later if rule-based isn't accurate enough.

---

## MVP Scope (What Ships First)

### MVP = "Record a journal entry, get a CBT coaching response"

**In scope:**
- Voice recording with waveform visualization
- Speech-to-text via SpeechAnalyzer
- Prosody extraction (native) → emotion detection
- Journal entry persistence (SQLite)
- Semantic chunking + embedding (gte-small)
- Vector retrieval for context
- CBT coaching response (Gemma 4 E2B)
- Safety gate (keyword matching)
- Basic personalization (tone/length prefs)

**Out of scope for MVP:**
- LoRA hot-swapping
- Trends/analytics screen
- DPO export
- Sound classification (laughter/crying)
- Settings screen (advanced)
- Timeline/history search
- Apple Watch

---

## Implementation Phases

### Phase 3: Core Agents (The Engine)
**Goal**: Get a working CBT conversation loop end-to-end.

| Ticket | Description | Files | Depends On |
|--------|-------------|-------|------------|
| **3.1** | Define AgentProtocol + base types | `Agents/AgentProtocol.swift` | — |
| **3.2** | Implement SafetyAgent (keyword matching + PII detection) | `Agents/SafetyAgent.swift`, tests | 3.1 |
| **3.3** | Implement EmotionAgent (prosody + text → 4-label) | `Agents/EmotionAgent.swift`, `Services/EmotionService.swift`, tests | 3.1 |
| **3.4** | Implement JournalAgent (normalize raw input → JournalEntry) | `Agents/JournalAgent.swift`, tests | 3.1 |
| **3.5** | Implement RetrievalAgent (vector search + BM25 fallback) | `Agents/RetrievalAgent.swift`, tests | 3.1 |
| **3.6** | Implement CoachAgent (Gemma4 E2B prompt + streaming) | `Agents/CoachAgent.swift`, `Resources/Prompts/coach_system_v1.txt`, tests | 3.1, 3.5 |
| **3.7** | Implement LearningLoopAgent (feedback tracking + profile updates) | `Agents/LearningLoopAgent.swift`, tests | 3.1 |
| **3.8** | Implement Orchestrator (CBT state machine + agent coordination) | `App/Orchestrator.swift`, tests | 3.2–3.7 |

### Phase 4: Model Migration
**Goal**: Swap models, update runtime, verify embeddings work.

| Ticket | Description | Files | Depends On |
|--------|-------------|-------|------------|
| **4.1** | Update ModelRuntime for Gemma 4 E2B loading | `Services/ModelRuntime.swift` | — |
| **4.2** | Add gte-small embedding support (384-dim) | `Services/ModelRuntime.swift`, `Agents/EmbeddingAgent.swift` | 4.1 |
| **4.3** | Update VectorStore for 384-dim embeddings | `Data/Storage/VectorStore.swift`, `Data/Models/SemanticChunk.swift`, migration SQL | — |
| **4.4** | Update EmotionService to use native SFVoiceAnalytics | `Services/EmotionService.swift` | — |
| **4.5** | Replace STTService with SpeechAnalyzer | `Services/STTService.swift` | — |
| **4.6** | Download + bundle Gemma4 E2B + gte-small models | `Resources/Models/` | 4.1, 4.2 |
| **4.7** | Integration test: audio → transcript + prosody → embedding → coach response | Tests | 4.1–4.6 |

### Phase 5: UI Completion
**Goal**: Complete the journaling flow end-to-end in the app.

| Ticket | Description | Files | Depends On |
|--------|-------------|-------|------------|
| **5.1** | Wire JournalCaptureScreen → Orchestrator | `UI/Screens/JournalCaptureScreen.swift` | Phase 3 |
| **5.2** | Build CoachScreen (streaming response + CBT cards) | `UI/Screens/CoachScreen.swift` | Phase 3 |
| **5.3** | Implement EmotionBadge component | `UI/Components/EmotionBadge.swift` | 3.3 |
| **5.4** | Implement CBTCardView component | `UI/Components/CBTCardView.swift` | — |
| **5.5** | Implement FeedbackButtons (thumbs up/down) | `UI/Components/FeedbackButtons.swift` | 3.7 |
| **5.6** | Implement LoadingSpinner / thinking states | `UI/Components/LoadingSpinner.swift` | — |
| **5.7** | Build TimelineScreen (past entries list) | `UI/Screens/TimelineScreen.swift` | — |
| **5.8** | Build SettingsScreen (voice, model info, clear data) | `UI/Screens/SettingsScreen.swift` | — |
| **5.9** | Navigation: wire all screens in ContentView | `UI/Screens/ContentView.swift` | 5.1–5.8 |
| **5.10** | Accessibility pass (VoiceOver labels, Dynamic Type) | All UI files | 5.1–5.9 |

### Phase 6: Polish & TestFlight
**Goal**: Bug fixes, performance tuning, beta release.

| Ticket | Description | Depends On |
|--------|-------------|------------|
| **6.1** | End-to-end integration tests (full pipeline) | Phase 3–5 |
| **6.2** | Performance profiling (latency budgets) | Phase 4 |
| **6.3** | Memory profiling (model loading/unloading) | Phase 4 |
| **6.4** | Safety agent edge case testing (false positives/negatives) | 3.2 |
| **6.5** | Empathy rubric evaluation (20 sampled turns) | Phase 5 |
| **6.6** | Dark mode + Dynamic Type visual QA | Phase 5 |
| **6.7** | TestFlight build + internal beta | 6.1–6.6 |

---

## Post-MVP Roadmap

### v1.1 — Enhanced Emotion
- Sound classification (SoundAnalysis) for laughter/crying/sighing detection
- ML-based emotion classifier (replace rule-based with small CoreML model)
- Emotion trends over time

### v1.2 — Personalization
- TrendsAgent implementation (weekly stats)
- LoRA adapter support in ModelRuntime
- DPO export from learning log

### v1.3 — Upgrade to Gemma 4 E4B
- Swap E2B → E4B for higher quality coaching
- Evaluate any-to-any audio input (skip STT entirely)
- Benchmark latency difference

### v2.0 — Advanced Features
- HealthKit integration (sleep/exercise correlation)
- Apple Watch quick journaling
- Enhanced CBT card library
- Export/backup journal data

---

## Linear Project Structure

When Linear MCP is reconnected, create:

### Project: **MindLoop MVP**

### Milestones:
1. **Core Agents** (Phase 3)
2. **Model Migration** (Phase 4)
3. **UI Completion** (Phase 5)
4. **Polish & TestFlight** (Phase 6)

### Labels:
- `agent` — Agent implementation work
- `model` — ML model integration
- `ui` — UI/UX work
- `infra` — Storage, runtime, services
- `test` — Testing work
- `safety` — Safety-critical work

### Tickets: 25 tickets total (3.1–3.8, 4.1–4.7, 5.1–5.10, 6.1–6.7)
Each ticket maps 1:1 to the tables above.

### Priority Order:
**Critical path**: 3.1 → 3.2 → 3.6 → 3.8 → 4.1 → 4.6 → 5.1 → 5.2 → 6.7

Everything else can be parallelized around the critical path.

---

## Files to Update in CLAUDE.md

When adopting this plan, update CLAUDE.md sections:
1. **Tech Stack table** — Gemma 4 E2B, gte-small, SpeechAnalyzer, remove OpenSMILE
2. **Model Management** — New model paths, sizes, memory budget
3. **EmotionAgent contract** — Native prosody features instead of OpenSMILE
4. **EmbeddingAgent contract** — 384-dim instead of 462-dim
5. **Performance budgets** — Revised for smaller models
6. **Data Flow diagram** — Simplified pipeline
7. **Database schema** — 384-dim embeddings default

---

## Key Risks

| Risk | Mitigation |
|------|-----------|
| Gemma 4 E2B quality may be insufficient for nuanced CBT coaching | Evaluate on 20 fixture turns; upgrade to E4B if score < 3.5 empathy |
| gte-small retrieval quality may miss relevant entries | A/B test against Qwen3-Embedding on fixture set; fallback to nomic-embed-v1.5 if needed |
| Native prosody features may be too coarse for emotion detection | Start rule-based; if accuracy < 70%, train small CoreML classifier on prosody features |
| SpeechAnalyzer API may not expose all prosody features we need | SFVoiceAnalytics (older API) still works as fallback; can use both |
| MLX Swift + Gemma 4 integration may have compatibility issues | mlx-community/gemma-4-e2b-it-4bit has 2.2K downloads, actively maintained |
