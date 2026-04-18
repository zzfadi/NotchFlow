import Foundation
import AppKit
import os

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.notchflow.app",
    category: "permissions"
)

/// Owns the set of folders the user has explicitly granted NotchFlow access to.
///
/// NotchFlow is non-sandboxed. macOS TCC still gates reads of the protected
/// subfolders (Desktop, Documents, Downloads) — and the grant it remembers
/// is keyed on the app's bundle ID + the specific folder the user picked via
/// `NSOpenPanel`. We persist those picked URLs ourselves so we can re-use them
/// across launches without re-prompting the user, and so Settings can render
/// a clear list of "what NotchFlow can see."
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published private(set) var grantedFolders: [GrantedFolder] = []

    private init() {
        loadGrantedFolders()
    }

    // MARK: - Requesting access

    /// Present `NSOpenPanel` and add each chosen folder to the granted set.
    /// Returns only folders that are newly added (dedupes against existing grants).
    @discardableResult
    func requestAccessViaPanel(
        multiSelect: Bool = false,
        message: String? = nil
    ) -> [GrantedFolder] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = multiSelect
        panel.canCreateDirectories = false
        panel.message = message
            ?? "Choose folder\(multiSelect ? "s" : "") NotchFlow may scan"
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK else { return [] }

        var added: [GrantedFolder] = []
        for url in panel.urls {
            if let granted = addGrant(for: url) {
                added.append(granted)
            }
        }
        return added
    }

    /// Add a grant for a programmatically-known URL (e.g. a default). No panel.
    /// Returns the grant (existing or new), or nil if the folder doesn't exist.
    @discardableResult
    func addGrant(for url: URL) -> GrantedFolder? {
        let standardized = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardized.path) else {
            log.warning("Refusing grant for missing folder: \(standardized.path, privacy: .private)")
            return nil
        }
        if let existing = grantedFolders.first(where: {
            $0.url.standardizedFileURL == standardized
        }) {
            return existing
        }
        let grant = GrantedFolder(url: standardized)
        grantedFolders.append(grant)
        persist()
        return grant
    }

    func revoke(_ folder: GrantedFolder) {
        grantedFolders.removeAll { $0.id == folder.id }
        persist()
    }

    func hasAccess(to url: URL) -> Bool {
        let targetPath = url.standardizedFileURL.path
        return grantedFolders.contains { grant in
            targetPath == grant.url.path
                || targetPath.hasPrefix(grant.url.path + "/")
        }
    }

    /// Auto-grant access to well-known locations that never trigger a TCC
    /// prompt (everything under `~/Library/Application Support` and dotfile
    /// dirs like `~/.claude`). Safe to call on every launch.
    func seedToolConfigDefaults() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent(".claude"),
            home.appendingPathComponent(".cursor"),
            home.appendingPathComponent(".codex"),
            home.appendingPathComponent("Library/Application Support/Claude"),
            home.appendingPathComponent("Library/Application Support/Code/User"),
            home.appendingPathComponent("Library/Application Support/Code - Insiders/User"),
            home.appendingPathComponent("Library/Application Support/Cursor/User")
        ]
        for url in candidates {
            _ = addGrant(for: url)
        }
    }

    /// One-time migration for pre-onboarding users who already customized
    /// `SettingsManager.aiConfigScanPaths` / `worktreeScanPaths`. Those paths
    /// already have TCC grants (the user successfully scanned with them at
    /// least once), so we can promote them into `grantedFolders` silently.
    func migrateLegacyPaths(_ paths: [String]) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            _ = addGrant(for: url)
        }
    }

    // MARK: - Persistence

    private func loadGrantedFolders() {
        guard let paths = Defaults.stringArray(DefaultsKeys.grantedFolderPaths) else {
            return
        }
        grantedFolders = paths.compactMap { path in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                log.info("Pruning granted folder that no longer exists: \(path, privacy: .private)")
                return nil
            }
            return GrantedFolder(url: url)
        }
        // If we pruned anything, rewrite the defaults so the stale entry doesn't
        // resurrect on a future launch where the folder is missing again.
        if grantedFolders.count != paths.count {
            persist()
        }
    }

    private func persist() {
        let paths = grantedFolders.map { $0.url.path }
        Defaults.setStringArray(DefaultsKeys.grantedFolderPaths, paths)
    }
}

// MARK: - GrantedFolder

struct GrantedFolder: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let addedAt: Date

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date()) {
        self.id = id
        self.url = url.standardizedFileURL
        self.addedAt = addedAt
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }

    var displayName: String { url.lastPathComponent }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GrantedFolder, rhs: GrantedFolder) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
