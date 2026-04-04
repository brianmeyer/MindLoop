# Handoff

## State
Main branch pushed. 267/267 tests, zero crashes. Phase 3 complete (all 8 agents + Orchestrator). Phase 5 MVP UI done (CoachScreen, navigation, 4 components). Models: bge-small-en-v1.5 downloaded (383MB fp32), Gemma 4 E2B downloading (~1GB). 22 tickets done this session. App has working Home → JournalCapture → CoachScreen flow.

## Next
1. REC-238: Finish Gemma download, update ModelRuntime to load from bundle dirs, verify on device
2. REC-239: Integration test (full pipeline with real agents)
3. REC-253: Safety edge case testing (zero false negatives)
4. REC-256: TestFlight build
5. Remaining polish: REC-265 (hardcoded colors), REC-270 (safety keywords)

## Context
- Embedding model: bge-small-en-v1.5 (BAAI, 384-dim, MTEB 58.6, full precision 383MB — no need to quantize, fits in memory budget)
- LLM: mlx-community/gemma-4-e2b-it-4bit (~1GB)
- Models not in git — download via `hf download` (see Models/README.md)
- ALWAYS use skills, MCPs, plugins, codex for review. Parallel agents for independent work.
- GRDB stores Date as datetime. Embedding dim is 384.
- SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated
- Gemma4 handles audio natively — no STTService
- fetchProfile() uses read-first pattern to avoid exclusive locks
