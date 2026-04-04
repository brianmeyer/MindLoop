# MindLoop MVP Roadmap

**Last Updated**: 2026-04-04
**Linear Project**: [MindLoop MVP](https://linear.app/recallforge/project/mindloop-mvp-f8599b349137)
**Target**: TestFlight internal beta

---

## Current State

**185/185 tests passing. Zero crashes. Build green.**

| Layer | Status | Tech |
|-------|--------|------|
| Storage | Done | GRDB 7.x, Accelerate vector search |
| Data Models | Done | All Sendable, no duplicates |
| Agents (4/8) | Done | AgentProtocol conformance, tests |
| Agents (4/8) | Stub | RetrievalAgent, CoachAgent, LearningLoopAgent, Orchestrator |
| Services | Done | EmotionService, BM25, TTSService, AudioRecorder, ChunkingService |
| ML Runtime | Partial | Gemma 4 E2B + bge-small-en-v1.5 paths set, placeholder embeddings |
| UI | Partial | HomeScreen, JournalCaptureScreen working; 5 component stubs |

---

## Phase 3: Core Agents (4 remaining)

**These can run in parallel on separate worktree branches.**

| Ticket | Agent | Depends On | Status |
|--------|-------|------------|--------|
| REC-229 | RetrievalAgent | VectorStore (done) | Todo |
| REC-230 | CoachAgent | Gemma 4 E2B model (REC-238) | Todo |
| REC-231 | LearningLoopAgent | AppDatabase (done) | Todo |
| REC-232 | Orchestrator | All agents above | Todo |

**REC-229 (RetrievalAgent)**: Vector search via VectorStore.findSimilarChunks + BM25 fallback. Top-5 entries + 1 CBTCard. Can build now — storage layer is ready.

**REC-230 (CoachAgent)**: Gemma 4 E2B prompt + streaming. Needs the model bundled (REC-238) for real inference, but can build with placeholder generation for structure/tests.

**REC-231 (LearningLoopAgent)**: Track feedback, update PersonalizationProfile. Uses AppDatabase directly. Can build now.

**REC-232 (Orchestrator)**: CBT state machine, agent pipeline coordination, timeout handling. Depends on 229-231 being at least structurally complete.

---

## Phase 4: Model Migration (3 remaining of 7)

| Ticket | What | Status |
|--------|------|--------|
| REC-233 | ModelRuntime Gemma 4 E2B | **Done** |
| REC-234 | bge-small-en-v1.5 embedding | **Done** |
| REC-235 | VectorStore 384-dim | **Done** |
| REC-236 | EmotionService SFVoiceAnalytics | **Done** |
| REC-237 | STTService removal | **Done** |
| REC-238 | Download + bundle model weights | Todo |
| REC-239 | Integration test: full pipeline | Todo (after Phase 3) |

**REC-238**: Download bge-small-en-v1.5 via MLXEmbedders (auto-download on first launch). Bundle Gemma 4 E2B weights (~1GB) for offline use. Option 1 (download on first launch) for bge-small.

---

## Phase 5: UI Completion (10 tickets)

| Ticket | What | Priority |
|--------|------|----------|
| REC-240 | Wire JournalCaptureScreen -> Orchestrator | Urgent |
| REC-241 | Build CoachScreen (streaming response) | Urgent |
| REC-242 | EmotionBadge component | Medium |
| REC-243 | CBTCardView component | Medium |
| REC-244 | FeedbackButtons component | Medium |
| REC-245 | LoadingSpinner component | Low |
| REC-246 | TimelineScreen | Medium |
| REC-247 | SettingsScreen | Low |
| REC-248 | ContentView navigation | High |
| REC-249 | Accessibility pass | High |

**MVP minimum**: REC-240, 241, 242, 248 (4 tickets for a working flow)

---

## Phase 6: Polish & TestFlight (7 tickets)

| Ticket | What | Priority |
|--------|------|----------|
| REC-250 | E2E integration tests | High |
| REC-251 | Performance profiling | High |
| REC-252 | Memory profiling | High |
| REC-253 | Safety edge case testing | Urgent |
| REC-254 | Empathy rubric evaluation | High |
| REC-255 | Dark mode + Dynamic Type QA | Medium |
| REC-256 | TestFlight build | Urgent |

---

## Cleanup Tickets (from audit)

| Ticket | What | Priority |
|--------|------|----------|
| REC-265 | Fix hardcoded colors | Medium |
| REC-268 | CLAUDE.md rewrite | High (in progress) |
| REC-270 | Expand safety keywords | High |

---

## MVP Critical Path

The shortest path to a working TestFlight build:

```
Phase 3 (parallel):
  REC-229 RetrievalAgent ──┐
  REC-230 CoachAgent ───────┼──> REC-232 Orchestrator
  REC-231 LearningLoopAgent─┘

Phase 4:
  REC-238 Bundle models (Gemma 4 E2B)

Phase 5 (minimum):
  REC-240 Wire JournalCapture -> Orchestrator
  REC-241 CoachScreen
  REC-248 ContentView navigation

Phase 6 (must-have):
  REC-253 Safety testing (zero false negatives)
  REC-256 TestFlight build
```

**10 tickets to MVP TestFlight.** Everything else is polish.

---

## Tech Stack (Current)

| Component | Technology | Status |
|-----------|-----------|--------|
| LLM | Gemma 4 E2B-it (MLX 4-bit) | Paths set, model not bundled |
| Embeddings | bge-small-en-v1.5 (384-dim, MTEB 58.6) | Via MLXEmbedders, auto-download |
| Storage | GRDB 7.x (DatabaseQueue) | Done, 185 tests |
| Vector Search | Accelerate SIMD cosine similarity | Done |
| Audio Input | Gemma 4 E2B native multimodal | Planned (was STTService) |
| Prosody | SFVoiceAnalytics + SpeechRecognitionMetadata | Done |
| TTS | AVSpeechSynthesizer | Done |
| UI | SwiftUI + NavigationStack | Partial |

---

## Done This Session (2026-04-04)

| Ticket | What |
|--------|------|
| REC-225-228 | Phase 3 agents (prior session, merged) |
| REC-233-237 | Phase 4 model migration (5/7 done) |
| REC-257 | Dusk/Dawn theme (prior session) |
| REC-258 | All tests passing (185/185) |
| REC-259 | Storage architecture decision |
| REC-260 | GRDB migration |
| REC-261 | STTService removed |
| REC-262 | ModelRuntime Gemma4 + bge-small |
| REC-263 | AgentProtocol conformance |
| REC-264 | Dead code cleanup |
| REC-266 | CBTState dedup |
| REC-267 | Force unwraps fixed |
| REC-269 | Sendable conformance |
