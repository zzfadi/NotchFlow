import Foundation
import SwiftUI
import Combine
import os.log

private let log = Logger(
    subsystem: "com.notchflow.app",
    category: "PluginInstallCoordinator"
)

/// The single async orchestrator for plugin install/uninstall/update
/// operations. `MetaPluginCard` stays presentational — it calls
/// coordinator methods and observes `inFlight` to render progress.
///
/// On success, the coordinator triggers a fresh `AIConfigStore.scan()`
/// so provenance badges and marketplace "Installed" state catch up
/// without needing a manual refresh. On failure, it surfaces the
/// error through `ErrorCenter` and clears the in-flight state.
@MainActor
final class PluginInstallCoordinator: ObservableObject {
    static let shared = PluginInstallCoordinator()

    enum InstallPhase {
        case installing
        case updating
        case uninstalling
    }

    @Published private(set) var inFlight: [PluginIdentity: InstallPhase] = [:]

    private let configStore: AIConfigStore

    init(configStore: AIConfigStore = AIConfigStore.shared) {
        self.configStore = configStore
    }

    // MARK: - Actions

    func install(_ plugin: MetaPlugin, target: InstallTarget = .userScope) {
        let installer = PluginInstallerRegistry.installer(for: plugin)
        guard installer.canInstall(plugin) else {
            ErrorCenter.shared.surface(
                "No installer is available for \(plugin.title).",
                source: "Plugin install"
            )
            return
        }
        let identity = plugin.identity
        inFlight[identity] = .installing

        Task { [weak self] in
            do {
                _ = try await installer.install(plugin, target: target)
                self?.handleSuccess(identity)
            } catch {
                self?.handleFailure(identity, error: error, phase: .installing, pluginTitle: plugin.title)
            }
        }
    }

    func uninstall(_ provenance: PluginProvenance, pluginTitle: String) {
        let installer = pickInstallerForUninstall(provenance)
        inFlight[provenance.identity] = .uninstalling

        Task { [weak self] in
            do {
                try await installer.uninstall(provenance)
                self?.handleSuccess(provenance.identity)
            } catch {
                self?.handleFailure(
                    provenance.identity,
                    error: error,
                    phase: .uninstalling,
                    pluginTitle: pluginTitle
                )
            }
        }
    }

    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) {
        let installer = PluginInstallerRegistry.installer(for: plugin)
        inFlight[plugin.identity] = .updating

        Task { [weak self] in
            do {
                _ = try await installer.update(provenance, to: plugin)
                self?.handleSuccess(plugin.identity)
            } catch {
                self?.handleFailure(
                    plugin.identity,
                    error: error,
                    phase: .updating,
                    pluginTitle: plugin.title
                )
            }
        }
    }

    // MARK: - Private

    private func pickInstallerForUninstall(_ provenance: PluginProvenance) -> PluginInstalling {
        switch provenance.scope {
        case .user, .project, .team, .managed:
            return PluginInstallerRegistry.claudeCode
        case .sidecar:
            return PluginInstallerRegistry.fileInstaller
        }
    }

    private func handleSuccess(_ identity: PluginIdentity) {
        inFlight.removeValue(forKey: identity)
        // Rescan so badges / installed state refresh.
        configStore.scan()
    }

    private func handleFailure(
        _ identity: PluginIdentity,
        error: Error,
        phase: InstallPhase,
        pluginTitle: String
    ) {
        inFlight.removeValue(forKey: identity)
        let action: String = {
            switch phase {
            case .installing: return "Install"
            case .updating: return "Update"
            case .uninstalling: return "Uninstall"
            }
        }()
        log.error("\(action, privacy: .public) failed for \(pluginTitle, privacy: .public): \(error.localizedDescription, privacy: .public)")
        ErrorCenter.shared.surface(
            "\(action) failed for \(pluginTitle): \(error.localizedDescription)",
            source: "Plugin install"
        )
    }
}
