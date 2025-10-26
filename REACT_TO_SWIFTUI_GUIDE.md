# React to SwiftUI Conversion Guide

**For**: MindLoop iOS App (from Figma Make React code)
**Date**: 2025-10-26

---

## Great News! 🎉

Since you already have React code from Figma Make, we can:
1. **Extract design tokens** directly from your CSS/styled-components
2. **Convert component structure** from React → SwiftUI (straightforward mapping)
3. **Skip Figma export** entirely!

This is actually FASTER than extracting from Figma files.

---

## What I Need From You

### 1. Share Your React Code

Please provide your Figma Make generated code in one of these ways:

**Option A** (Preferred): Share the entire project folder
- Zip the React project folder
- Upload to Google Drive/Dropbox/GitHub
- Share link with me

**Option B**: Share key files directly
- Main component files (Journal, Coach, Timeline, Settings screens)
- CSS files or styled-components
- Any design token files (colors.js, theme.js, etc.)

**Option C**: Paste code here
- If it's not too large, paste the code directly
- I can work with partial code and request more as needed

---

## What I'll Extract & Convert

### 1. Design Tokens (Colors, Typography, Spacing)

From your React code, I'll find and extract:

#### Colors
React code will have something like:
```jsx
// In CSS or styled-components
const colors = {
  primary: '#6366F1',
  surface: '#FFFFFF',
  textPrimary: '#1F2937',
  textSecondary: '#6B7280',
  // etc.
}

// Or in CSS
.primary-color { background: #6366F1; }
```

I'll convert to SwiftUI:
```swift
// Resources/Assets.xcassets/Colors/Primary.colorset
{
  "colors": [
    {
      "color": { "color-space": "srgb", "components": { "red": "0.388", "green": "0.400", "blue": "0.945", "alpha": "1.000" } },
      "idiom": "universal"
    }
  ]
}

// Or Swift code extension
extension Color {
    static let primary = Color(hex: "6366F1")
    static let surface = Color.white
    // etc.
}
```

#### Typography
React code:
```jsx
const typography = {
  titleXL: { fontSize: '32px', fontWeight: '700', lineHeight: '40px' },
  titleL: { fontSize: '24px', fontWeight: '600', lineHeight: '32px' },
  body: { fontSize: '17px', fontWeight: '400', lineHeight: '24px' },
  // etc.
}
```

I'll convert to SwiftUI:
```swift
// UI/Typography.swift
enum Typography {
    case titleXL
    case titleL
    case body

    var font: Font {
        switch self {
        case .titleXL: return .system(size: 32, weight: .bold)
        case .titleL: return .system(size: 24, weight: .semibold)
        case .body: return .system(size: 17, weight: .regular)
        }
    }
}
```

#### Spacing
React code:
```jsx
const spacing = {
  xs: '4px',
  s: '8px',
  m: '12px',
  l: '16px',
  xl: '24px'
}
```

I'll convert to SwiftUI:
```swift
// UI/Spacing.swift
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}
```

---

### 2. Component Structure Conversion

Here's how common React patterns map to SwiftUI:

#### Flexbox → Stack Views
```jsx
// React with Flexbox
<div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
  <Text>Title</Text>
  <Text>Body</Text>
</div>
```

```swift
// SwiftUI
VStack(spacing: Spacing.m) {
    Text("Title")
    Text("Body")
}
```

#### Props → Parameters
```jsx
// React
function EmotionBadge({ emotion, confidence }) {
  return <div className="badge">{emotion}</div>
}
```

```swift
// SwiftUI
struct EmotionBadge: View {
    let emotion: String
    let confidence: Double

    var body: some View {
        Text(emotion)
            .padding()
            .background(Color.primary)
    }
}
```

#### State → @State / @Observable
```jsx
// React
const [isRecording, setIsRecording] = useState(false)
```

```swift
// SwiftUI
@State private var isRecording = false
```

#### Styling → Modifiers
```jsx
// React
<button
  style={{
    backgroundColor: '#6366F1',
    padding: '16px',
    borderRadius: '12px'
  }}
>
  Record
</button>
```

```swift
// SwiftUI
Button("Record") {
    // action
}
.padding(Spacing.l)
.background(Color.primary)
.cornerRadius(12)
```

---

## Conversion Process (What I'll Do)

### Step 1: Analyze Your React Code (1-2 hours)
- [ ] Review folder structure
- [ ] Identify design token patterns (CSS variables, styled-components theme, etc.)
- [ ] Map component hierarchy
- [ ] Note any complex interactions (audio recording, streaming, etc.)

### Step 2: Extract Design Tokens (2-3 hours)
- [ ] Create color palette in `Assets.xcassets/Colors/`
- [ ] Write `UI/Typography.swift`
- [ ] Write `UI/Spacing.swift`
- [ ] Extract any other tokens (shadows, borders, etc.)

### Step 3: Convert Components (4-6 hours per screen)
- [ ] Journal Screen (audio recording, waveform, input)
- [ ] Coach Screen (chat bubbles, context cards, feedback)
- [ ] Timeline Screen (list, search, trends)
- [ ] Settings Screen (toggles, selections, privacy)

### Step 4: Convert Shared Components (1-2 hours each)
- [ ] AudioWaveform component
- [ ] EmotionBadge component
- [ ] CBTCard component
- [ ] LoadingSpinner component
- [ ] FeedbackButtons component

### Step 5: Adapt for iOS Patterns (2-3 hours)
- [ ] Navigation (React Router → NavigationStack)
- [ ] Forms (React forms → SwiftUI Form/TextField)
- [ ] Lists (React map → SwiftUI List/ForEach)
- [ ] Gestures (onClick → SwiftUI gestures)

---

## Key Differences: React vs SwiftUI

| React | SwiftUI | Notes |
|-------|---------|-------|
| `div`, `span` | `VStack`, `HStack`, `Text` | Layout containers |
| `flexDirection: 'column'` | `VStack` | Vertical stack |
| `flexDirection: 'row'` | `HStack` | Horizontal stack |
| `position: 'absolute'` | `ZStack` | Overlapping views |
| `onClick` | `onTapGesture` or `Button` | Click handlers |
| `useState` | `@State` | Local state |
| `useEffect` | `onAppear`, `onChange` | Side effects |
| `className`, `style` | `.modifier()` | Styling |
| CSS colors (hex) | `Color(hex:)` or `.colorset` | Colors |
| `px`, `rem` | `CGFloat` (points) | Sizing |

---

## Common Patterns I'll Handle

### Audio Recording UI
React:
```jsx
const AudioRecorder = () => {
  const [isRecording, setIsRecording] = useState(false)
  return (
    <div className="recorder">
      <button onClick={() => setIsRecording(!isRecording)}>
        {isRecording ? 'Stop' : 'Record'}
      </button>
      {isRecording && <Waveform />}
    </div>
  )
}
```

SwiftUI:
```swift
struct AudioRecorder: View {
    @State private var isRecording = false

    var body: some View {
        VStack {
            Button(isRecording ? "Stop" : "Record") {
                isRecording.toggle()
            }

            if isRecording {
                Waveform()
            }
        }
    }
}
```

### Chat Bubbles
React:
```jsx
const ChatBubble = ({ message, isUser }) => (
  <div className={`bubble ${isUser ? 'user' : 'coach'}`}>
    <p>{message}</p>
  </div>
)
```

SwiftUI:
```swift
struct ChatBubble: View {
    let message: String
    let isUser: Bool

    var body: some View {
        Text(message)
            .padding()
            .background(isUser ? Color.primary : Color.surface)
            .cornerRadius(12)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
```

---

## Timeline Estimate

Once you share the React code:

| Task | Time Estimate |
|------|---------------|
| Analyze code structure | 1-2 hours |
| Extract design tokens | 2-3 hours |
| Convert 4 main screens | 16-24 hours (4-6 hrs each) |
| Convert 5 components | 5-10 hours (1-2 hrs each) |
| Testing & refinement | 4-6 hours |
| **Total** | **28-45 hours (3.5-6 days)** |

This fits within our Phase 0 timeline (4-5 days).

---

## What I Need to See

When you share your React code, ideally include:

### File Structure
- [ ] Main app entry point (`App.jsx`, `index.jsx`)
- [ ] Screen components (Journal, Coach, Timeline, Settings)
- [ ] Shared components (buttons, cards, badges, etc.)
- [ ] Styling files (CSS, styled-components, theme.js, etc.)
- [ ] Any constants/config files

### Specific Files (if organized)
- [ ] `screens/JournalScreen.jsx` (or similar)
- [ ] `screens/CoachScreen.jsx`
- [ ] `screens/TimelineScreen.jsx`
- [ ] `screens/SettingsScreen.jsx`
- [ ] `components/AudioWaveform.jsx`
- [ ] `components/EmotionBadge.jsx`
- [ ] `styles/theme.js` or `styles/colors.css`
- [ ] `styles/typography.js` or similar

### What I'll Do With It

1. **First pass** (30 minutes):
   - Quick review to understand structure
   - Identify design tokens
   - Ask any clarifying questions

2. **Extract tokens** (2-3 hours):
   - Create all color sets
   - Write Typography.swift
   - Write Spacing.swift
   - Show you the result

3. **Convert screens** (1-2 days):
   - Convert each screen to SwiftUI
   - Show you incremental progress
   - Get your feedback

4. **Refine** (4-6 hours):
   - Fix any layout issues
   - Match pixel-perfect to React version
   - Add iOS-specific polish (animations, haptics)

---

## Questions for You

1. **How is your React code organized?**
   - Single file or multiple components?
   - Using CSS, styled-components, or Tailwind?
   - Separate theme/design token files?

2. **What screens are included?**
   - All 4 (Journal, Coach, Timeline, Settings)?
   - Or just some?

3. **Can you share it now?**
   - Link to GitHub repo?
   - Zip file?
   - Paste code snippets?

4. **Any complex interactions I should know about?**
   - Audio recording logic?
   - Real-time animations?
   - WebSocket/streaming?

---

## Example: What I'll Create

If your React code has:
```jsx
// theme.js
export const colors = {
  primary: '#6366F1',
  surface: '#FFFFFF',
  textPrimary: '#1F2937',
}

export const typography = {
  titleXL: { fontSize: 32, fontWeight: 700 },
  body: { fontSize: 17, fontWeight: 400 },
}

// JournalScreen.jsx
const JournalScreen = () => (
  <div className="screen">
    <h1 style={typography.titleXL}>Journal</h1>
    <AudioRecorder />
    <textarea placeholder="Or type here..." />
  </div>
)
```

I'll create:
```swift
// Color+Extensions.swift
extension Color {
    static let primary = Color(hex: "6366F1")
    static let surface = .white
    static let textPrimary = Color(hex: "1F2937")
}

// Typography.swift
enum Typography {
    case titleXL, body
    var font: Font {
        switch self {
        case .titleXL: return .system(size: 32, weight: .bold)
        case .body: return .system(size: 17, weight: .regular)
        }
    }
}

// JournalScreen.swift
struct JournalScreen: View {
    var body: some View {
        VStack {
            Text("Journal")
                .font(Typography.titleXL.font)

            AudioRecorder()

            TextEditor(text: $journalText)
                .placeholder("Or type here...")
        }
        .padding()
    }
}
```

---

## Ready When You Are!

Just share your React code (any method above) and I'll:
1. Analyze it (30 min)
2. Extract design tokens (2-3 hours)
3. Convert to SwiftUI (3-5 days)
4. Get you to Testing Gate 0

**Let's see that React code!** 🚀
