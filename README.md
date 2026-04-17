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
