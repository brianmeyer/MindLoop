# Handoff

## State
Main branch pushed. 403/403 tests, zero crashes. All phases through 5 complete. App runs in simulator. 24 tickets done this session. Gemma 4 E2B 4-bit (3.3GB) + bge-small-en-v1.5 (383MB) downloaded in Models/ dir. Only REC-256 (TestFlight build) remains for MVP.

## Next
1. REC-256: TestFlight build — archive + upload to App Store Connect
2. REC-265: Add design token colorsets to Assets.xcassets (Dusk/Dawn theme)
3. Production: evaluate LiteRT-LM for Gemma 4 E2B (2-bit quant, <1.5GB vs MLX 3.3GB)
4. REC-270: Expand safety keywords

## Context
- Gemma 4 E2B 4-bit is 3.3GB (full multimodal with vision+audio). Correct model — app is audio-first. Works on Mac Mini M4 and Pro iPhones (16GB). Standard iPhones need LiteRT 2-bit quant (Phase 6 optimization).
- bge-small-en-v1.5 is 383MB fp32. No quantization needed — within budget.
- Models in project root Models/ dir (NOT Resources/ — causes Xcode bundle conflicts)
- ALWAYS use skills, MCPs, plugins, codex. Parallel agents. Brian is emphatic.
- 403 tests: 267 unit + 14 integration + 120 safety edge cases + example stub
- App has working Home → JournalCapture → CoachScreen navigation flow
- Color assets not yet defined in xcassets — screens render but design tokens resolve to defaults
