import Foundation

// MARK: - InstallTarget

/// Where a plugin install should land. Maps to the target-selection UI
/// and to installer-specific flags (`claude plugin install --scope user`
/// vs `--scope project`, file-copy target dir for awesome-copilot, etc.).
enum InstallTarget: Hashable {
    case userScope
    case projectScope(URL)
    case teamScope
}

// MARK: - PluginInstalling

/// Every ecosystem (Claude Code, Cursor, awesome-copilot file-copy)
/// speaks its own install dialect. This protocol is the abstraction the
/// `PluginInstallCoordinator` reaches through — each adapter handles
/// one dialect, and the registry picks the right adapter for a given
/// `MetaPlugin`.
protocol PluginInstalling: Sendable {
    /// Whether this installer can handle the given plugin. Used by the
    /// registry to pick an adapter and by the UI to decide whether to
    /// enable the install button.
    func canInstall(_ plugin: MetaPlugin) -> Bool

    /// Install the plugin. Returns provenance describing what was
    /// written — the coordinator uses this to seed the next scan so
    /// the UI reflects the new plugin without waiting for a full
    /// refresh.
    func install(_ plugin: MetaPlugin, target: InstallTarget) async throws -> PluginProvenance

    /// Remove the plugin files this installer is responsible for.
    /// Idempotent: uninstalling an already-removed plugin is not an
    /// error.
    func uninstall(_ provenance: PluginProvenance) async throws

    /// Replace the installed version with the marketplace's current
    /// version. Returns the new provenance.
    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) async throws -> PluginProvenance
}

// MARK: - PluginInstallerRegistry

/// Picks the right adapter for a plugin. Today's dispatch is coarse —
/// any `MetaSource.github` plugin under a marketplace whose id contains
/// "awesome-copilot" uses the file installer; everything else goes to
/// the Claude Code installer (with deep-link fallback) for
/// `.github`/`.url`, and Cursor for the rare `cursor://` schemes.
@MainActor
enum PluginInstallerRegistry {
    static var claudeCode: PluginInstalling = ClaudeCodePluginInstaller()
    static var cursor: PluginInstalling = CursorPluginInstaller()
    static var fileInstaller: PluginInstalling = AwesomeCopilotFileInstaller()
    static var noOp: PluginInstalling = NoOpPluginInstaller()

    static func installer(for plugin: MetaPlugin) -> PluginInstalling {
        if plugin.marketplaceId.localizedCaseInsensitiveContains("awesome-copilot")
            || plugin.marketplaceId.localizedCaseInsensitiveContains("copilot") {
            return fileInstaller
        }
        switch plugin.source {
        case .github, .url:
            return claudeCode
        case .git, .npm:
            return claudeCode
        case .relative, .local, .unknown:
            return noOp
        }
    }
}

// MARK: - PluginInstallerError

enum PluginInstallerError: LocalizedError {
    case unsupported(String)
    case subprocessFailure(exitCode: Int32, stderr: String)
    case manifestMissingFiles
    case networkFailure(String)
    case filesystemFailure(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let reason):
            return "Install not supported: \(reason)"
        case .subprocessFailure(let exitCode, let stderr):
            if stderr.isEmpty {
                return "Install command failed (exit \(exitCode))"
            }
            return "Install command failed: \(stderr)"
        case .manifestMissingFiles:
            return "Marketplace manifest does not declare which files to install"
        case .networkFailure(let msg):
            return "Network error while installing: \(msg)"
        case .filesystemFailure(let msg):
            return "Filesystem error while installing: \(msg)"
        }
    }
}
