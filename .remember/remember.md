# Handoff

## State
Main branch pushed. 181/189 tests passing, zero crashes. GRDB migration complete. ModelRuntime updated to Gemma4 E2B + bge-small-en-v1.5 (384-dim). 7 tickets done (REC-258 partial, 259, 260, 262, 264, 266, 267, 269). Full codebase audit done — 13 tickets created (REC-258–270). Embedding model changed from gte-small to bge-small-en-v1.5 (already in MLXEmbedders registry, MTEB 58.6, zero integration work).

## Next
1. REC-263: Make all agents implement AgentProtocol + Sendable (unblocks Phase 3)
2. REC-261: Delete STTService (fixes 4 of remaining 8 test failures)
3. Fix last 4 minor test failures: JournalAgent normalization (2), date formatting (1), latency rounding (1)
4. REC-268: CLAUDE.md comprehensive rewrite
5. Phase 3 remaining: REC-229 RetrievalAgent, REC-230 CoachAgent, REC-231 LearningLoopAgent, REC-232 Orchestrator — run as parallel worktree agents

## Context
- Embedding model is bge-small-en-v1.5 (NOT gte-small). Already in MLXEmbedders registry as `.bge_small`. 384-dim, ~35MB, MTEB 58.6.
- ALWAYS use skills, MCPs, plugins. Brian is emphatic. Run parallel background agents for independent work.
- Use `-disable-concurrent-destination-testing` for tests
- GRDB stores Date as datetime — use Date type in Row subscripts
- SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated
- Gemma4 E2B handles audio natively — STTService is redundant (REC-261)
- CoachResponse.CBTState removed — uses AgentProtocol.CBTState directly
- JournalEntry.embeddings field removed — embeddings live on SemanticChunk
- safety_keywords.json needs "ending it all" variant (already added to SafetyAgent.swift)
