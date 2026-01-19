# NotchFlow - AI Coding Instructions

## Architecture Overview

NotchFlow is a macOS notch-based utility app built with SwiftUI + DynamicNotchKit. It displays developer tools in the MacBook notch area via three integrated mini-apps.

### Core Architecture Pattern

```
NotchFlowApp (@main) → AppDelegate → NotchManager → MainNotchView
                                         ↓
                          NavigationState (shared via @EnvironmentObject)
                                         ↓
                    ExpandedView → [FogNoteView | WorktreeView | AIConfigView]
```

- **NotchManager**: Wraps DynamicNotchKit's `DynamicNotch` and controls expand/collapse. Located at [NotchFlow/Core/NotchManager.swift](NotchFlow/NotchFlow/Core/NotchManager.swift)
- **NavigationState**: Observable state for active mini-app (`MiniApp` enum). Passed via `@EnvironmentObject`
- **SettingsManager**: Singleton (`SettingsManager.shared`) using `@AppStorage` + `UserDefaults` for persistence

### Mini-App Pattern

Each mini-app follows this structure under `MiniApps/{Name}/`:
- `{Name}Model.swift` - Data models (structs conforming to `Identifiable`, `Codable`)
- `{Name}Scanner.swift` or `{Name}Storage.swift` - Async scanner/persistence using `@MainActor` classes with `@Published` properties
- `{Name}View.swift` - SwiftUI view with `@StateObject` for scanner/storage

**Scanner pattern example** (Worktree, AIConfig):
```swift
class WorktreeScanner: ObservableObject {
    @Published var repositoryGroups: [RepositoryGroup] = []
    @Published var isScanning: Bool = false
    private var scanTask: Task<Void, Never>?
    
    func scan() {
        scanTask?.cancel()
        scanTask = Task { @MainActor in /* ... */ }
    }
}
```

## Build Commands

```bash
# SPM build (from NotchFlow/ directory)
cd NotchFlow && swift build
swift run

# Xcode build
open NotchFlow/NotchFlow.xcodeproj  # then ⌘R
```

## Key Conventions

### SwiftUI State Management
- Use `@StateObject` for owned observables, `@EnvironmentObject` for shared state
- `SettingsManager.shared` is accessed via `@StateObject private var settings = SettingsManager.shared`

### Async/Concurrency
- Scanner classes use `Task` with cancellation support via `scanTask?.cancel()` and `Task.isCancelled` checks
- Always use `@MainActor` on classes that publish UI state
- Debounce saves: `NoteStorage` uses Combine's `debounce` to batch file writes

### File System Patterns
- Home directory: `FileManager.default.homeDirectoryForCurrentUser`
- Path display: Always convert absolute paths to `~`-prefixed format for display using `shortPath` computed properties
- Storage locations: FogNotes stores to `~/Documents/FogNotes/notes.json`

### UI Patterns
- Dark theme: Background `Color.black.opacity(0.9)`, text uses system colors
- Accent color stored as hex string in `@AppStorage`, converted via `Color(hex:)`
- Resizable notch: Per-app size stored in `SettingsManager.appSizes`, with presets (Compact 320x220, Default 400x280, Large 520x380) and custom sizing via drag handle. Size bounds: 280-600pt width, 180-450pt height

## File Discovery (AIConfig Scanner)

The AI config scanner looks for these patterns - extend `AIConfigFileType` enum when adding new file types:
- `AGENTS.md`, `CLAUDE.md`, `.claude/`
- `.github/copilot-instructions.md`, `.github/prompts/`
- `.cursorrules`, `.cursor/`
- `mcp.json`, `.mcp/`

## Dependencies

Single external dependency: [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) via SPM. Requires macOS 14.0+.
