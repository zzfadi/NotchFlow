import Foundation
import Combine

/// Shared owner of AI Config scan state. Holds the most recent snapshot,
/// drives scan lifecycle (cancellation + token pattern), and is the
/// single place the rest of the app reads from.
///
/// Before this type existed, `AIConfigView` built its own
/// `@StateObject AIConfigScanner` and `LocalPluginSynthesizer.shared`
/// built a different one — two scanners, two scan passes, divergent
/// state. Phase 2 (plugin provenance) and Phase 3 (install actions) rely
/// on a single source of truth about what's on disk, so state lives
/// here.
///
/// The store owns the scan-token pattern. `AIConfigScanner` is stateless
/// and just returns a `ScanResult`; the store guards publication behind
/// the token so a cancelled-then-restarted scan can't clobber state.
@MainActor
final class AIConfigStore: ObservableObject {
    static let shared = AIConfigStore()

    @Published private(set) var snapshot: AIConfigSnapshot = .empty
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var errorMessage: String?

    private let scanner: AIConfigScanner
    private let settings: SettingsProviding
    private let permissions: PermissionsProviding
    private var scanTask: Task<Void, Never>?
    /// Monotonic id for the most recent scan. Only the task owning the
    /// latest token can publish / flip `isScanning`, so a cancelled scan
    /// can never leak `isScanning = false` on top of a newer scan that
    /// just set it to `true`.
    private var latestScanToken: Int = 0

    init(
        scanner: AIConfigScanner = AIConfigScanner(),
        settings: SettingsProviding = SettingsManager.shared,
        permissions: PermissionsProviding = PermissionManager.shared
    ) {
        self.scanner = scanner
        self.settings = settings
        self.permissions = permissions
    }

    // MARK: - Public

    /// Fire a fresh scan. Cancels any in-flight scan and advances the
    /// token. The detached task collects paths on the main actor first
    /// (so `permissions` / `settings` access is legal), then walks disk
    /// on a background executor, then publishes back on the main actor
    /// behind the token guard.
    func scan() {
        scanTask?.cancel()
        latestScanToken &+= 1
        let myToken = latestScanToken

        let grantedPaths = permissions.grantedFolders.map { $0.url.path }
        let legacyPaths = settings.aiConfigScanPaths
        let combinedPaths = Array(Set(grantedPaths + legacyPaths))

        isScanning = true
        errorMessage = nil

        scanTask = Task.detached(priority: .userInitiated) { [scanner] in
            let result = await scanner.performScan(projectPaths: combinedPaths)

            await MainActor.run { [weak self] in
                guard let self, self.latestScanToken == myToken else { return }
                self.snapshot = AIConfigSnapshot(
                    items: result.items,
                    categoryGroups: result.categoryGroups,
                    lastScanDate: result.lastScanDate,
                    enabledIdentities: result.enabledIdentities,
                    installedIdentities: Set(
                        result.provenanceByPath.values.map { $0.identity }
                    )
                )
                self.isScanning = false
            }
        }
    }

    /// No-op if we already have data and aren't actively scanning. Views
    /// call this on `.onAppear` / tab activation; the first call fires a
    /// real scan, subsequent calls short-circuit.
    func scanIfNeeded() {
        guard snapshot.items.isEmpty, !isScanning else { return }
        scan()
    }

    /// Force cancel the in-flight scan. `isScanning` flips false
    /// immediately for UI responsiveness; the background task will
    /// observe cancellation and exit when it next checks.
    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }
}

// MARK: - Snapshot

/// Immutable payload the view layer reads. Phase 0 shape; Phase 2 will
/// extend with `provenanceByPath` and `enabledIdentities` without
/// breaking this public surface.
struct AIConfigSnapshot {
    let items: [AIConfigItem]
    let categoryGroups: [AIConfigCategoryGroup]
    let lastScanDate: Date?
    /// P2: the set of plugin identities the user has enabled in Claude
    /// Code's `~/.claude/settings.json`. Used by the marketplace view to
    /// render per-plugin enabled state without a second file read.
    let enabledIdentities: Set<PluginIdentity>
    /// P2: the set of plugin identities that have at least one file
    /// currently installed on disk. Fast lookup target for
    /// `MetaPlugin.isInstalled(given:)` — avoids scanning
    /// `provenanceByPath` on every card render.
    let installedIdentities: Set<PluginIdentity>

    init(
        items: [AIConfigItem],
        categoryGroups: [AIConfigCategoryGroup],
        lastScanDate: Date?,
        enabledIdentities: Set<PluginIdentity> = [],
        installedIdentities: Set<PluginIdentity> = []
    ) {
        self.items = items
        self.categoryGroups = categoryGroups
        self.lastScanDate = lastScanDate
        self.enabledIdentities = enabledIdentities
        self.installedIdentities = installedIdentities
    }

    static let empty = AIConfigSnapshot(items: [], categoryGroups: [], lastScanDate: nil)
}
