import Foundation
import AppKit

/// Hands the install off to the Cursor app via its `cursor://plugin/
/// install?...` deep-link scheme. Cursor doesn't ship a stable CLI we
/// can depend on, so uninstall falls back to opening the plugin's
/// directory in Finder with a helpful toast — less automated than the
/// Claude Code installer, but honest about the ecosystem's limits.
struct CursorPluginInstaller: PluginInstalling {
    func canInstall(_ plugin: MetaPlugin) -> Bool {
        // Only reach for the Cursor installer when we already know the
        // plugin is meant for Cursor — currently signalled by marketplace
        // id containing "cursor". The registry already filters to this
        // path for us, but `canInstall` is a useful belt-and-braces check.
        plugin.marketplaceId.localizedCaseInsensitiveContains("cursor")
    }

    func install(_ plugin: MetaPlugin, target: InstallTarget) async throws -> PluginProvenance {
        guard let deepLink = cursorDeepLink(for: plugin) else {
            throw PluginInstallerError.unsupported(
                "No Cursor deep-link URL could be built for this plugin"
            )
        }
        await MainActor.run { _ = NSWorkspace.shared.open(deepLink) }
        return PluginProvenance(
            identity: plugin.identity,
            version: plugin.version,
            scope: .user,
            isEnabled: true
        )
    }

    func uninstall(_ provenance: PluginProvenance) async throws {
        throw PluginInstallerError.unsupported(
            "Uninstalling Cursor plugins isn't automated yet — remove from Cursor's plugin UI."
        )
    }

    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) async throws -> PluginProvenance {
        // Cursor's updates flow through the same deep-link shape.
        return try await install(plugin, target: .userScope)
    }

    private func cursorDeepLink(for plugin: MetaPlugin) -> URL? {
        var components = URLComponents()
        components.scheme = "cursor"
        components.host = "plugin"
        components.path = "/install"
        switch plugin.source {
        case .github(let repo, _, _):
            components.queryItems = [URLQueryItem(name: "source", value: repo)]
        case .url(let url):
            components.queryItems = [URLQueryItem(name: "source", value: url.absoluteString)]
        default:
            return nil
        }
        return components.url
    }
}
