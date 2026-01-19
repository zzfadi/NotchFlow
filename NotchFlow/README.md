# NotchFlow

A macOS notch app with three integrated developer-focused mini-apps.

## Features

### 1. Fog Note
Ultra-fast note capture that lives in the notch.
- Single text area, always ready
- Auto-save on every keystroke
- Simple note list with search
- Markdown support
- Stored in `~/Documents/FogNotes/`

### 2. Worktree GUI
Git worktree discovery and management.
- Scans configured directories for git worktrees
- Displays worktree path, branch name, last modified
- Quick actions: Open in Terminal, VS Code, or Finder
- Grouped by parent repository

### 3. AI Config GUI
Find and manage AI configuration files across your system.
- Discovers: `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.cursorrules`, `mcp.json`, and more
- Groups by AI tool (Claude, Copilot, Cursor, MCP)
- Quick preview and edit functionality
- Filter by tool type

## Requirements

- macOS 14.0 (Sonoma) or later
- MacBook with notch (or runs in floating pill mode on non-notch Macs)

## Installation

### Option 1: Xcode

1. Open `NotchFlow.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Build and run (⌘R)

### Option 2: Swift Package Manager

```bash
cd NotchFlow
swift build
swift run
```

## Dependencies

- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) - MIT License

## Architecture

```
NotchFlow/
├── App/                    # App entry point and delegate
├── Core/                   # Shared managers and state
├── Views/                  # Main UI views
├── MiniApps/
│   ├── FogNote/           # Note-taking mini-app
│   ├── Worktree/          # Git worktree browser
│   └── AIConfig/          # AI config file finder
└── Resources/              # Assets and configuration
```

## Configuration

Access Settings from the menu bar icon to configure:
- Launch at login
- Default mini-app
- Accent color
- Scan directories for Worktree and AI Config

## Usage

1. Click the menu bar icon or use the keyboard shortcut to show the notch
2. Use the tab buttons to switch between mini-apps:
   - **WT** (left side) - Worktree browser
   - **AI** (right side, first) - AI config finder
   - **Note** (right side, second) - Quick notes
3. Click outside to collapse

## License

MIT License - see LICENSE file for details.
