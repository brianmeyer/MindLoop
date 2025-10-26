# MindLoop Project Structure

**Created**: 2025-10-26
**Status**: ✅ Phase 0 Structure Complete

---

## Current Directory Structure

```
MindLoop/
├─ App/
│  ├─ MindLoopApp.swift          # ✅ Main app entry point (@main)
│  └─ Orchestrator.swift         # ⏳ Placeholder (Phase 4)
│
├─ UI/
│  ├─ Screens/
│  │  └─ ContentView.swift       # ✅ Existing (will be replaced with Figma designs)
│  ├─ Components/
│  │  ├─ AudioWaveform.swift     # ⏳ From Figma
│  │  ├─ EmotionBadge.swift      # ⏳ From Figma
│  │  ├─ CBTCard.swift           # ⏳ From Figma
│  │  ├─ LoadingSpinner.swift    # ⏳ From Figma
│  │  └─ FeedbackButtons.swift   # ⏳ From Figma
│  ├─ Typography.swift           # ⏳ Will populate from Figma tokens
│  └─ Spacing.swift              # ⏳ Will populate from Figma tokens
│
├─ Agents/ (8 files + protocol)
│  ├─ AgentProtocol.swift        # ⏳ Phase 3
│  ├─ JournalAgent.swift         # ⏳ Phase 3
│  ├─ EmbeddingAgent.swift       # ⏳ Phase 3
│  ├─ RetrievalAgent.swift       # ⏳ Phase 3
│  ├─ CoachAgent.swift           # ⏳ Phase 3
│  ├─ SafetyAgent.swift          # ⏳ Phase 3
│  ├─ LearningLoopAgent.swift    # ⏳ Phase 3 (Phase A personalization)
│  ├─ TrendsAgent.swift          # ⏳ Phase 3
│  └─ EmotionAgent.swift         # ⏳ Phase 3
│
├─ Services/ (6 files)
│  ├─ STTService.swift           # ⏳ Phase 2 (WhisperKit)
│  ├─ TTSService.swift           # ⏳ Phase 6 (AVSpeechSynthesizer)
│  ├─ EmotionService.swift       # ⏳ Phase 5 (OpenSMILE bridge)
│  ├─ VectorStore.swift          # ⏳ Phase 1
│  ├─ ModelRuntime.swift         # ⏳ Phase 2 (MLX Swift)
│  └─ BM25Service.swift          # ⏳ Phase 1
│
├─ Data/
│  ├─ Models/ (5 files)
│  │  ├─ JournalEntry.swift      # 🚧 NEXT: Create with Codable + tests
│  │  ├─ EmotionSignal.swift     # 🚧 NEXT: Create with Codable + tests
│  │  ├─ CBTCard.swift           # 🚧 NEXT: Create with Codable + tests
│  │  ├─ CoachResponse.swift     # 🚧 NEXT: Create with Codable + tests
│  │  └─ PersonalizationProfile.swift  # 🚧 NEXT: Create with Codable + tests
│  ├─ DTOs/
│  │  └─ [Empty - will add as needed]
│  └─ Storage/
│     ├─ SQLiteManager.swift     # ⏳ Phase 1
│     ├─ VectorIndex.swift       # ⏳ Phase 1
│     └─ Migrations/             # ⏳ Phase 1 (SQL migration files)
│
└─ Resources/
   ├─ Assets.xcassets/           # ✅ Xcode generated
   │  ├─ Colors/                 # ⏳ Will add from Figma tokens
   │  ├─ AppIcon.appiconset/     # ✅ Default icon (replace later)
   │  └─ AccentColor.colorset/   # ✅ Default color (replace from Figma)
   ├─ Models/                    # ⏳ Phase 2 (Qwen3, embeddings, LoRA)
   ├─ Prompts/                   # ⏳ Phase 3 (coach, journal, safety prompts)
   └─ CBTCards/                  # ⏳ Phase 1 (cards.json)
```

---

## File Count Summary

| Category | Files Created | Status |
|----------|--------------|--------|
| **App** | 2 | 1 complete, 1 placeholder |
| **UI** | 8 | 1 existing, 7 placeholders (awaiting Figma) |
| **Agents** | 9 | All placeholders |
| **Services** | 6 | All placeholders |
| **Data Models** | 5 | All placeholders (NEXT TO BUILD) |
| **Storage** | 2 | All placeholders |
| **Total Swift Files** | 33 | Structure complete ✅ |

---

## What's Missing (By Design)

The following will NOT be created as placeholder files:

### Screen Files (Waiting for Figma Export)
- `UI/Screens/JournalScreen.swift`
- `UI/Screens/CoachScreen.swift`
- `UI/Screens/TimelineScreen.swift`
- `UI/Screens/SettingsScreen.swift`

**Why**: We'll generate these directly from your Figma design using a Figma-to-SwiftUI plugin.

### Resource Files
- `Resources/Models/` - Will hold large .mlpackage files (GB-sized)
- `Resources/Prompts/` - Will add .txt and .json files in Phase 3
- `Resources/CBTCards/cards.json` - Will create in Phase 1

---

## Next Steps (Phase 0 Completion)

### Immediate (This Week)

#### 1. Get Figma Design Tokens (Required)

See `FIGMA_EXPORT_GUIDE.md` for detailed instructions.

**What I need from you**:
- [ ] Export design tokens (colors, typography, spacing) using one of these methods:
  - **Option A**: Tokens Studio plugin → JSON export
  - **Option B**: Swift Package Exporter → direct Swift code
  - **Option C**: Manual screenshots + values
- [ ] Share Figma file link (with view access) OR
- [ ] Send exported design token files

**Once received, I will**:
- Populate `Resources/Assets.xcassets/Colors/` with your color palette
- Write `UI/Typography.swift` with your text styles
- Write `UI/Spacing.swift` with your spacing scale

#### 2. Export Figma Screens (Optional but Recommended)

**What I need**:
- [ ] Export SwiftUI code for 4 main screens using a Figma-to-SwiftUI plugin:
  - Journal screen (audio recording view)
  - Coach screen (conversation/chat view)
  - Timeline screen (past entries list)
  - Settings screen

**Tools you can use**:
- Figma to Code plugin
- Trace plugin
- Codia AI

**I can also build screens manually** if you prefer. Just send screenshots/specs.

#### 3. Create Data Models with Tests (I'll do this next)

Once you send Figma tokens, I'll create:
- [ ] `JournalEntry.swift` with full Codable implementation
- [ ] `EmotionSignal.swift` with prosody feature support
- [ ] `CBTCard.swift` for technique cards
- [ ] `CoachResponse.swift` for AI responses
- [ ] `PersonalizationProfile.swift` for Phase A personalization
- [ ] Unit tests for all 5 models (encode/decode, edge cases)

**Time estimate**: 4-6 hours

---

## Testing Gate 0 Checklist

Before proceeding to Phase 1, we must pass these criteria:

- [ ] **Project builds** without errors on iOS 26 simulator (iPhone 15 Pro)
- [ ] **Design tokens** populated from Figma (colors, typography, spacing)
- [ ] **All 5 data models** created with Codable conformance
- [ ] **20+ unit tests** passing for data models
- [ ] **No hard-coded colors/fonts** anywhere in codebase
- [ ] **Folder structure** matches CLAUDE.md exactly ✅ (DONE)

**Current Status**: 1 of 6 complete (folder structure ✅)

---

## Questions for You

1. **Figma Access**: Can you share the Figma file link, or will you export tokens yourself?

2. **Export Method Preference**:
   - A) Tokens Studio + JSON (I convert to Swift)
   - B) Swift Package Exporter (direct Swift code)
   - C) Manual export (screenshots + I build)

3. **Screens Ready?**: Are all 4 screens (Journal, Coach, Timeline, Settings) designed and ready to export?

4. **Timeline**: When can you provide the Figma exports? (Ideally this week to stay on schedule)

---

## Dependencies (Not Yet Added)

The following Swift Package Manager dependencies are defined in the plan but not yet added to Xcode:

- [ ] MLX Swift (`https://github.com/ml-explore/mlx-swift`)
- [ ] WhisperKit (`https://github.com/argmaxinc/WhisperKit`)
- [ ] swift-snapshot-testing (`https://github.com/pointfreeco/swift-snapshot-testing`)

**When to add**: After we have design tokens + data models working (before Phase 2).

---

## Summary

**✅ Completed**:
- Folder structure (33 placeholder Swift files)
- Figma export guide created
- Project structure documented

**🚧 In Progress**:
- Waiting for Figma design token export

**⏳ Next**:
- Populate design tokens from Figma
- Create 5 data models with tests
- Pass Testing Gate 0
- Begin Phase 1 (Storage & Fixtures)

---

**Ready to proceed once you send Figma tokens!** 🚀
