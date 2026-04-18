import Foundation

/// Directories we never descend into during a scanner walk.
///
/// Two reasons to skip a folder:
///
/// 1. **Pure noise** — build outputs, package caches, VCS internals. Walking
///    them wastes time and clutters nothing useful will be found there.
///
/// 2. **macOS TCC-protected user-media folders** — `~/Music`, `~/Movies`,
///    `~/Pictures`, `~/Downloads`. These are gated by per-folder privacy
///    prompts on non-sandboxed apps. Walking into them from a broader grant
///    (e.g. the user granted `~` or `~/Library/Application Support`) fires a
///    separate TCC dialog for each. We never expect AI configs or git repos
///    inside these media folders, so skipping them by name is a safe way to
///    keep the scanners out of TCC's way while still honouring any grant the
///    user made at a parent level.
///
/// The list is intentionally a single source of truth so `WorktreeScanner`
/// and `AIConfigScanner` can't drift apart — if we ever add a new noisy or
/// privacy-sensitive folder, we add it once here.
enum ScannerSkipList {
    static let names: Set<String> = [
        // Build output / package caches
        "node_modules",
        "build",
        "dist",
        "DerivedData",
        ".build",
        "Pods",
        "Carthage",
        ".npm",
        ".cargo",
        ".rustup",

        // VCS + Finder internals
        ".git",
        ".Trash",

        // Library-wide — we surface app configs via explicit grants to
        // `Library/Application Support/<tool>/`, not by walking the whole
        // Library tree.
        "Library",
        "Applications",

        // macOS TCC-protected user-media folders. Walking these from a
        // broader grant triggers a privacy prompt per folder — they never
        // contain git worktrees or AI configs, so skip by name.
        "Music",
        "Movies",
        "Pictures",
        "Downloads"
    ]

    static func shouldSkip(directoryName: String) -> Bool {
        names.contains(directoryName)
    }
}
