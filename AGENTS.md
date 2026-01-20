# AGENTS.md

NotchFlow is a macOS notch utility with developer-focused mini-apps built with SwiftUI + DynamicNotchKit.

## Build Commands

```bash
# Xcode (recommended)
open NotchFlow.xcodeproj  # then Cmd+R

# Swift Package Manager
swift build && swift run
```

## Architecture

```
NotchFlowApp → AppDelegate → NotchManager → MainNotchView
                                  ↓
                   NavigationState (@EnvironmentObject)
                                  ↓
              [FogNoteView | WorktreeView | AIConfigView]
```

**Key Components:**
- `NotchManager` - Wraps DynamicNotchKit, controls expand/collapse
- `NavigationState` - Observable state for active mini-app
- `SettingsManager` - Singleton using `@AppStorage` + `UserDefaults`

## Mini-App Pattern

Each mini-app in `MiniApps/{Name}/`:
- `{Name}Model.swift` - Data models (Identifiable, Codable)
- `{Name}Scanner.swift` or `{Name}Storage.swift` - Async with @MainActor
- `{Name}View.swift` - SwiftUI view with @StateObject

## Code Conventions

### SwiftUI State
- `@StateObject` for owned observables
- `@EnvironmentObject` for shared state
- `SettingsManager.shared` accessed via @StateObject

### Concurrency (Swift 6.0)
- `@MainActor` on ObservableObject classes
- `Task` with cancellation via `scanTask?.cancel()`
- `Task.detached` for background file I/O

### UI Patterns
- Dark theme: `Color.black.opacity(0.9)` background
- Accent color stored as hex in @AppStorage
- Size presets: Compact (400x280), Default (600x400), Large (800x550), Extra Large (1000x700)

## File Patterns

- Home directory: `FileManager.default.homeDirectoryForCurrentUser`
- Display paths with `~` prefix using `shortPath` computed property
- FogNotes storage: `~/Documents/FogNotes/notes.json`

## Dependencies

- [DynamicNotchKit](Packages/DynamicNotchKit) - Local fork with window sizing improvements
- [swift-subprocess](https://github.com/swiftlang/swift-subprocess) - Git command execution
- macOS 14.0+ required
