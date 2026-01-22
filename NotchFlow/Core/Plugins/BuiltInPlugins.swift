import SwiftUI

/// Built-in Worktree mini app plugin.
/// Wraps WorktreeView for the plugin system.
@MainActor
struct WorktreePlugin: MiniAppPlugin {
    let id = "worktree"
    let displayName = "Worktree"
    let icon = "arrow.triangle.branch"
    let description = "Git worktree discovery and management"

    var preferredSize: CGSize {
        CGSize(width: 700, height: 500)
    }

    func makeView() -> AnyView {
        AnyView(WorktreeView())
    }
}

/// Built-in AI Config mini app plugin.
/// Wraps AIConfigView for the plugin system.
@MainActor
struct AIConfigPlugin: MiniAppPlugin {
    let id = "aiConfig"
    let displayName = "AI Config"
    let icon = "brain"
    let description = "Find and manage AI configuration files"

    var preferredSize: CGSize {
        CGSize(width: 700, height: 500)
    }

    func makeView() -> AnyView {
        AnyView(AIConfigView())
    }
}

/// Built-in Fog Note mini app plugin.
/// Wraps FogNoteView for the plugin system.
@MainActor
struct FogNotePlugin: MiniAppPlugin {
    let id = "fogNote"
    let displayName = "Fog Note"
    let icon = "note.text"
    let description = "Quick capture and note management"

    var preferredSize: CGSize {
        CGSize(width: 600, height: 400)
    }

    func makeView() -> AnyView {
        AnyView(FogNoteView())
    }
}
