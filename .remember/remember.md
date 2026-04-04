# Handoff

## State
Branch `grdb-migration` pushed (4 commits). GRDB migration complete: AppDatabase.swift, Records.swift, VectorStore.swift, BM25Service.swift all using GRDB. SQLiteManager deleted. 179/191 tests passing, zero crashes. Full codebase audit done — 13 Linear tickets created (REC-258 through REC-270). ModelRuntime.swift is entirely wrong (Qwen3 refs, 462-dim, random embeddings) — REC-262 is the next blocker.

## Next
1. Merge `grdb-migration` → main (179/191 passing, good enough to merge — remaining 12 are pre-existing)
2. Quick wins on same branch or main: REC-264 (dead code), REC-266 (duplicate CBTState), REC-267 (force unwraps), REC-269 (Sendable)
3. REC-262: ModelRuntime Qwen3→Gemma4 E2B + 462→384 dim — BLOCKING for all Phase 3/4 work
4. After 262: REC-261 (delete STTService), REC-263 (AgentProtocol conformance), then Phase 3 agents (REC-229-232) on parallel worktree branches

## Context
- ALWAYS use skills (ios, swift, testing, crash-debugging), MCPs (mcp__xcode__*, mcp__linear-server__*), plugins (codex:rescue for review). Brian is emphatic.
- Use `-disable-concurrent-destination-testing` for tests
- GRDB stores Date as datetime — use Date type in Row subscripts, not Double
- Embedding dim is 384 (gte-small), not 462 (Qwen3)
- SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated
- Gemma4 E2B handles audio natively — STTService is redundant (REC-261)
- CoachResponse has duplicate CBTState that will break Orchestrator (REC-266)
- safety_keywords.json has "end it all" but SafetyAgent doesn't catch it — matching bug
