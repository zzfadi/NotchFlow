# NotchFlow

[![CI](https://github.com/zzfadi/NotchFlow/actions/workflows/ci.yml/badge.svg)](https://github.com/zzfadi/NotchFlow/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/zzfadi/NotchFlow)](https://github.com/zzfadi/NotchFlow/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> The notch was wasted pixels. NotchFlow turns it into your developer dashboard.

<!-- TODO: drop a short demo GIF here once recorded -->
<!-- ![NotchFlow demo](docs/demo.gif) -->

## The story

Apple carved a notch into every new MacBook and never gave it a purpose. On non‑notch Macs, the same strip across the top is empty too. NotchFlow claims that strip — and turns it into a tiny, always‑reachable surface for the three things I actually hit a dozen times a day while coding:

- **Quick thought capture**, before it evaporates.
- **Jumping between git worktrees** without hunting through Finder or the terminal.
- **Finding the AI config file** that's hiding in this repo (`AGENTS.md`? `CLAUDE.md`? `.cursorrules`? `mcp.json`? yes).

It lives in the notch — and floats as a pill on Macs without one — so it's always one click away without stealing real estate from whatever you're building.

## What's in it

### Fog Note
Frictionless capture. Open the notch, start typing, it's saved. Auto‑save on every keystroke, markdown rendering, pin the ones that matter. Notes live as plain files under `~/Documents/FogNotes/` so your data stays yours.

### Worktree GUI
Scans the directories you configure for git worktrees and shows them grouped by parent repo — path, branch, last modified. One click to open any worktree in Terminal, VS Code, or Finder. Handy when you've got five branches checked out at once and can't remember which one was for the migration.

### AI Config GUI
Every coding agent wants its own config file. NotchFlow finds them all — `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.cursorrules`, `mcp.json`, and friends — groups them by tool, and lets you preview or edit inline. No more "wait, which file does Cursor read again?"

## Install

Grab the signed, notarized DMG from the [latest release](https://github.com/zzfadi/NotchFlow/releases/latest), drag NotchFlow into Applications, launch it. A tiny icon appears in your menu bar — click it, or click the notch itself.

Requires **macOS 14 Sonoma or later**. MacBook with a hardware notch is ideal; on non‑notch Macs, NotchFlow renders as a floating pill in the same spot.

### Build from source

```bash
git clone https://github.com/zzfadi/NotchFlow.git
cd NotchFlow
open NotchFlow.xcodeproj   # then ⌘R
```

Xcode 16+, Swift 6.

## Quick tour

1. Click the menu bar icon (or the notch) to expand.
2. Tab between mini‑apps via the buttons on either side of the notch:
   - **WT** — Worktree browser
   - **AI** — AI config finder
   - **Note** — Fog Note
3. Click anywhere outside to collapse — or toggle **Pin** to keep it open.
4. Drag the bottom‑right corner to resize. Sizes are remembered per mini‑app.

Open **Settings** from the menu bar to tune scan directories, default app, accent color, notch size presets, and launch‑at‑login.

## Under the hood

Native SwiftUI + AppKit, Swift 6 with strict concurrency. Built on a fork of [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) with better screen utilization and safer multi‑display handling.

```
NotchFlow/
├── App/         # Entry point, NSApplicationDelegate, menu bar
├── Core/        # NotchManager, SettingsManager, rich content rendering
├── Views/       # Main notch view, settings window
├── MiniApps/
│   ├── FogNote/
│   ├── Worktree/
│   └── AIConfig/
└── Resources/   # AppIcon, Info.plist
```

Logging goes through `os.Logger` under the app's bundle identifier — stream it with:

```bash
log stream --predicate 'subsystem == "com.notchflow.app"' --level debug
```

Releases are cut by tagging `vX.Y.Z` — a GitHub Actions workflow builds, signs with Developer ID, notarizes with Apple, staples the ticket, and attaches a styled DMG to the release.

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

Conventions for this repo live in [AGENTS.md](AGENTS.md) — it's the source of truth for both humans and AI assistants.

## License

MIT — see [LICENSE](LICENSE).
# NotchFlow

[![CI](https://github.com/zzfadi/NotchFlow/actions/workflows/ci.yml/badge.svg)](https://github.com/zzfadi/NotchFlow/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A macOS notch utility with integrated developer-focused mini-apps.

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
- Xcode 15.0+ or Swift 5.9+

## Installation

### Option 1: Xcode

```bash
git clone https://github.com/zzfadi/NotchFlow.git
cd NotchFlow
open NotchFlow.xcodeproj
# Build with Cmd+B, Run with Cmd+R
```

### Option 2: Swift Package Manager

```bash
git clone https://github.com/zzfadi/NotchFlow.git
cd NotchFlow
swift build
swift run
```

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
- Notch size presets
- Scan directories for Worktree and AI Config

## Usage

1. Click the menu bar icon or use the keyboard shortcut to show the notch
2. Use the tab buttons to switch between mini-apps:
   - **WT** (left side) - Worktree browser
   - **AI** (right side, first) - AI config finder
   - **Note** (right side, second) - Quick notes
3. Click outside to collapse (or pin to keep open)
4. Drag the bottom-right corner to resize

## Dependencies

- [DynamicNotchKit](Packages/DynamicNotchKit) - Customized fork included in repo (MIT License)
  - Fork includes window sizing improvements (85% screen utilization vs original 50%) and safer screen detection

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a pull request.

See also:
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

## License

MIT License - see [LICENSE](LICENSE) for details.
