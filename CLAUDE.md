# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MindLoop is an iOS application built with SwiftUI and Swift 5.0. It targets iOS 26.0+ and supports both iPhone and iPad (device families 1,2).

**Bundle Identifier**: `Lycan.MindLoop`

## Project Structure

```
MindLoop/
├── MindLoop/              # Main application code
│   ├── MindLoopApp.swift  # App entry point (@main)
│   ├── ContentView.swift  # Root view
│   └── Assets.xcassets/   # Images and color assets
├── MindLoopTests/         # Unit tests (Swift Testing framework)
└── MindLoopUITests/       # UI tests (XCTest framework)
```

## Building and Running

This is an Xcode project. Use Xcode to build and run:

**Open the project:**
```bash
open MindLoop/MindLoop.xcodeproj
```

**Build from command line:**
```bash
xcodebuild -project MindLoop/MindLoop.xcodeproj -scheme MindLoop -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**Run tests from command line:**
```bash
# Unit tests (Swift Testing)
xcodebuild test -project MindLoop/MindLoop.xcodeproj -scheme MindLoop -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MindLoopTests

# UI tests (XCTest)
xcodebuild test -project MindLoop/MindLoop.xcodeproj -scheme MindLoop -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MindLoopUITests
```

## Testing

The project uses two testing frameworks:

- **Unit Tests** (`MindLoopTests/`): Uses the new Swift Testing framework with `@Test` attribute and `#expect()` assertions
- **UI Tests** (`MindLoopUITests/`): Uses XCTest framework with `XCUIApplication()` for UI automation testing

## Architecture

This is a standard SwiftUI application:
- `MindLoopApp.swift` contains the `@main` entry point with a `WindowGroup` scene
- `ContentView.swift` serves as the root view
- Currently a minimal "Hello, world!" template application
