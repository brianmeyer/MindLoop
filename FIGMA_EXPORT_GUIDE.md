# Figma Design Token Export Guide

**For**: MindLoop iOS App
**Date**: 2025-10-26

---

## What We Need From Figma

To populate our SwiftUI design system, we need to extract the following design tokens from your Figma file:

### 1. **Colors** (For `Resources/Assets.xcassets/Colors/`)

Extract all color variables/styles:
- Primary color (main brand color)
- Surface colors (backgrounds, cards)
- Text colors (primary, secondary, tertiary)
- Semantic colors (success, error, warning, info)
- Light & Dark mode variants

**Format needed**: Hex values + names

### 2. **Typography** (For `UI/Typography.swift`)

Extract all text styles:
- Font families (likely SF Pro for iOS)
- Font sizes (titleXL, titleL, body, caption, etc.)
- Font weights (regular, medium, semibold, bold)
- Line heights
- Letter spacing

**Format needed**: Text style names + properties

### 3. **Spacing** (For `UI/Spacing.swift`)

Extract spacing scale:
- xs (extra small, likely 4px)
- s (small, likely 8px)
- m (medium, likely 12px)
- l (large, likely 16px)
- xl (extra large, likely 24px)
- Any custom spacing values

**Format needed**: Spacing names + pixel values

### 4. **UI Components** (For `UI/Components/` and `UI/Screens/`)

Full SwiftUI code for:
- Audio waveform component
- Emotion badge component
- CBT card component
- Loading spinner
- Feedback buttons (👍/👎)
- Journal screen layout
- Coach screen layout
- Timeline screen layout
- Settings screen layout

---

## Recommended Export Method

### Option A: Tokens Studio + Style Dictionary (Best for Design Systems)

**Step 1**: Install Tokens Studio Plugin
- Open your Figma file
- Go to Plugins → Browse plugins
- Install "Tokens Studio for Figma"

**Step 2**: Export Tokens
- Open Tokens Studio plugin
- Go to Settings → Export
- Export as JSON (all tokens)
- Save as `design-tokens.json`

**Step 3**: Convert to Swift (We'll do this)
- We'll use Style Dictionary to convert JSON → Swift
- Generates SwiftUI Color extensions, Font utilities, etc.

### Option B: Swift Package Exporter (Direct Figma → Swift)

**Step 1**: Go to https://figmatoswift.com/
- Sign up (free tier available)
- Connect your Figma account

**Step 2**: Select Your File
- Choose the MindLoop Figma file
- Select which frames/components to export

**Step 3**: Export
- Exports directly to Swift code
- Downloads as a .swift file or Swift Package

### Option C: Manual Export (Quick & Simple)

**Colors**:
1. In Figma, select each color style
2. Copy hex value + name
3. We'll create `.colorset` files manually

**Typography**:
1. Select each text style
2. Note: font family, size, weight, line height
3. We'll create Swift enum manually

**Components**:
1. Use a Figma-to-SwiftUI plugin (e.g., "Figma to Code")
2. Select each component
3. Generate SwiftUI code
4. Copy into our project

---

## What to Send Me

Once you've exported, send me:

### If using Tokens Studio:
- [ ] `design-tokens.json` file

### If using Swift Package Exporter:
- [ ] Exported `.swift` files (colors, typography, components)

### If manual export:
- [ ] Screenshot or list of color styles with hex values
- [ ] Screenshot or list of text styles with properties
- [ ] Spacing scale values
- [ ] SwiftUI code for key components (or Figma link with access)

---

## Current Folder Structure (Ready to Receive)

```
MindLoop/
├─ App/
│  └─ MindLoopApp.swift          # ✅ Already created
├─ UI/
│  ├─ Screens/
│  │  └─ ContentView.swift       # ✅ Already created (will rename/replace)
│  ├─ Components/
│  │  └─ [Waiting for Figma export]
│  ├─ Typography.swift           # ⏳ Will create from your tokens
│  └─ Spacing.swift              # ⏳ Will create from your tokens
├─ Resources/
│  └─ Assets.xcassets/
│     └─ Colors/                 # ⏳ Will create from your tokens
└─ [Other folders ready]
```

---

## Questions for You

1. **Which export method do you prefer?**
   - A) Tokens Studio + JSON (most scalable)
   - B) Swift Package Exporter (fastest)
   - C) Manual export (simplest)

2. **Can you share the Figma file link?** (with edit or view access)
   - This allows me to see the design system structure
   - I can help guide the export process

3. **Do you already have design tokens defined in Figma?**
   - If yes: using Figma Variables or Styles?
   - If no: I can help set them up first

4. **What screens are fully designed in Figma?**
   - Journal screen (audio recording)?
   - Coach screen (chat view)?
   - Timeline screen?
   - Settings screen?

---

## Next Steps

1. You: Export design tokens from Figma (choose method above)
2. You: Send me the exported files or Figma link
3. Me: Create SwiftUI design token files
4. Me: Integrate into project structure
5. Me: Create data models with tests
6. Ready for Phase 1! ✅

---

**Need Help?** Let me know which export method you want to use and I can provide step-by-step instructions!
