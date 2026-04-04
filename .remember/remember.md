# Handoff

## State
I migrated MindLoop storage from raw SQLite C API to GRDB 7.10.0 on branch `grdb-migration` (3 commits, pushed). SQLiteManager.swift deleted. New files: `AppDatabase.swift`, `Records.swift`, rewritten `VectorStore.swift` + `BM25Service.swift`. 16 storage tests pass individually. Full suite: 158/191 passing — SIGTRAP crashes eliminated, but 26 SIGABRT crashes remain when all tests run together (pass individually). 7 real assertion failures in JournalAgent normalization, SafetyAgent "end it all" keyword, CoachResponse latency rounding, date formatting. REC-260 in progress in Linear. Codex review running in background (may have completed).

## Next
1. Fix 26 SIGABRT crashes in combined test run — use `superpowers:systematic-debugging` skill. Likely remaining shared state in PersonalizationProfile or EmotionAgent tests (not storage).
2. Fix 7 assertion failures (SafetyAgent keyword, JournalAgent normalize, CoachResponse rounding, date formatting).
3. Merge `grdb-migration` → main, mark REC-260 done, start Phase 3 agents (REC-229–232) on parallel worktree branches.

## Context
- ALWAYS use skills (`ios`, `swift`, `testing`, `crash-debugging`), MCPs (`mcp__xcode__*`, `mcp__linear-server__*`), and plugins (`codex:rescue` for review). Brian is emphatic about this.
- Use `-disable-concurrent-destination-testing` (not `-disable-concurrent-testing`, deprecated).
- GRDB stores `Date` as datetime — use `Date` type in Row subscripts, not `Double`.
- Embedding dimension is 384 (gte-small), not 462 (old Qwen3).
- `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` in project settings.
