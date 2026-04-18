import Foundation
import SwiftUI

/// A mini-app is one tab of the notch — its identifier, display metadata,
/// root view, and optional prewarm hook.
///
/// Before this refactor, adding a new tab meant editing three places:
///   1. creating the view file
///   2. adding a case to an `enum MiniApp`
///   3. adding the case into a switch in `ExpandedView`
///
/// Now a mini-app is a type that conforms to `MiniApp` and lives in
/// `MiniAppRegistry.all`. The tab bar, tab content, settings UI, and
/// prewarm loop all iterate the registry — so adding a new tab is one
/// new struct + one line in the registry.
@MainActor
protocol MiniApp: Identifiable {
    /// Stable identifier used as the key for size persistence, default-app
    /// selection, and `NavigationState.activeApp`. Previously this was the
    /// enum's `rawValue`; the same string values are reused so existing
    /// on-disk `UserDefaults` entries keep working across the migration.
    var id: String { get }

    /// Label shown in the active-tab pill.
    var title: String { get }

    /// SF Symbol for the tab-bar button.
    var icon: String { get }

    /// Long-form description used for tooltips and settings rows.
    var description: String { get }

    /// Construct the tab's root view. Type-erased because the registry is a
    /// heterogeneous array and we don't need Swift's generic plumbing here.
    @MainActor func makeView() -> AnyView

    /// Kick off any background work the mini-app wants done ahead of its
    /// first render (disk scans, network fetches, loading persisted state).
    /// Called from `AppDelegate.applicationDidFinishLaunching`.
    @MainActor func prewarm()
}

extension MiniApp {
    /// Default: no prewarm. Most mini-apps rely on their singleton stores
    /// loading lazily on first observation; only the ones that need to kick
    /// off scans/fetches at launch override this.
    func prewarm() {}
}

// MARK: - Concrete mini-apps

// MARK: - Prewarm policy
//
// Prewarm no longer fires disk-walking scanners at launch. Each walk of
// a user-granted folder risks a separate macOS TCC prompt (Music, Movies,
// Pictures, Downloads, etc. are individually gated); on first launch that
// produced a chain of "Allow" dialogs with no context about which tab
// triggered them. Scanners now run from each view's `.onAppear`, which
// ties the prompts to the deliberate act of opening a tab.
//
// The singletons (`*Scanner.shared`, `NoteStorage.shared`,
// `MetaMarketplaceStore.shared`) keep state across tab switches, so the
// scan only actually runs on FIRST visit — the UX win from Wave 1 ("tab
// switches don't refetch") is preserved.

struct WorktreeMiniApp: MiniApp {
    let id = "Worktree"
    let title = "Worktree"
    let icon = "arrow.triangle.branch"
    let description = "Git worktree discovery and management"

    func makeView() -> AnyView { AnyView(WorktreeView()) }
    // No prewarm — WorktreeView.onAppear fires the scan.
}

struct AIMetaMiniApp: MiniApp {
    let id = "AI Meta"
    let title = "AI Config"
    let icon = "brain"
    let description = "AI configs on this machine — rules, skills, prompts, agents, MCP servers"

    /// Uses the rich, categorized `AIConfigView` (filter by type → filter
    /// by provider → preview file contents). The marketplace-style
    /// `AIMetaView` with plugin cards wasn't the right primary UI for
    /// browsing what's already on the user's machine — those files aren't
    /// discrete "packages" you install, they're configs you edit.
    /// Marketplace code is kept in the tree behind this view in case we
    /// bring it back as a secondary mode.
    func makeView() -> AnyView { AnyView(AIConfigView()) }
    // No prewarm — AIConfigView.onAppear fires the scan.
}

struct FogNoteMiniApp: MiniApp {
    let id = "Fog Note"
    let title = "Fog Note"
    let icon = "note.text"
    let description = "Quick capture and note management"

    func makeView() -> AnyView { AnyView(FogNoteView()) }

    /// Fog Note's storage reads ONLY the app's own notes directory (under
    /// `~/Documents/FogNotes` by default), not any user-granted folder, so
    /// prewarming it doesn't trigger TCC prompts. Keeping it hot avoids a
    /// visible load flash on first tab open.
    func prewarm() {
        _ = NoteStorage.shared
    }
}

// MARK: - Registry

/// Single source of truth for which mini-apps the notch exposes. Order here
/// is the order tabs render in the tab bar and in Settings selection lists.
@MainActor
enum MiniAppRegistry {
    static let worktree = WorktreeMiniApp()
    static let aiMeta = AIMetaMiniApp()
    static let fogNote = FogNoteMiniApp()

    static let all: [any MiniApp] = [worktree, aiMeta, fogNote]

    /// Look up a mini-app by its persisted ID. Returns `nil` if the ID was
    /// written by a previous build that had a tab that's since been removed.
    static func app(forId id: String) -> (any MiniApp)? {
        all.first { $0.id == id }
    }

    /// Fallback for when a persisted ID is missing or unknown. Matches the
    /// historical default-tab behavior.
    static var defaultApp: any MiniApp { fogNote }
}
