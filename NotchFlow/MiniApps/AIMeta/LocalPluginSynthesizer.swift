import Foundation
import SwiftUI
import os.log

private let log = Logger(
    subsystem: "com.notchflow.app",
    category: "LocalPluginSynthesizer"
)

// MARK: - SyntheticMarketplace

/// The "My Machine" virtual marketplace — a marketplace that isn't hosted
/// anywhere. NotchFlow synthesizes it locally so the AI Meta grid populates
/// immediately with whatever's already on disk, without needing a network
/// fetch or a marketplace.json.
struct SyntheticMarketplace: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

// MARK: - LocalPluginSynthesizer

/// Wraps `AIConfigScanner` results into `MetaPlugin` cards grouped by project
/// folder. Each project with AI components becomes one plugin entry under the
/// "My Machine" marketplace.
///
/// In later PRs this will be extended to understand plugin directories
/// (`.claude-plugin/`, `.github/plugin/`) explicitly, so a single project's
/// plugin shows up as a plugin rather than just a grab-bag of its files. For
/// the PR-2 scaffold, the "one project = one card" rollup is enough.
@MainActor
final class LocalPluginSynthesizer {
    static let shared = LocalPluginSynthesizer()

    let marketplaceId = "local.my-machine"
    private let scanner = AIConfigScanner()

    private init() {}

    func synthesize() -> (SyntheticMarketplace, [MetaPlugin]) {
        let items = scanner.allItems
        let byProject = Dictionary(grouping: items) { $0.projectPath }

        let plugins: [MetaPlugin] = byProject
            .sorted { $0.key.lastPathComponent < $1.key.lastPathComponent }
            .map { projectPath, items in
                let summary = components(from: items)
                let name = projectPath.lastPathComponent
                return MetaPlugin(
                    id: "\(marketplaceId):\(projectPath.path)",
                    name: name,
                    displayName: name,
                    description: "On-disk AI components in \(shortPath(projectPath))",
                    version: nil,
                    author: nil,
                    homepage: nil,
                    license: nil,
                    category: "Local",
                    keywords: [],
                    source: .local(projectPath),
                    components: summary,
                    marketplaceId: marketplaceId,
                    rawSource: projectPath.path,
                    isInstalled: true,
                    isEnabled: true
                )
            }

        let marketplace = SyntheticMarketplace(
            id: marketplaceId,
            name: "My Machine",
            description: "AI components already on this Mac"
        )

        log.debug("Synthesized \(plugins.count, privacy: .public) local plugins")
        return (marketplace, plugins)
    }

    /// Kick off a fresh on-disk scan. The scanner runs the work on its own
    /// Task and publishes results through `allItems`; callers that want the
    /// post-scan snapshot should observe `scanner.allItems` or call
    /// `synthesize()` after `isScanning` flips back to false.
    func refresh() {
        scanner.scan()
    }

    private func components(from items: [AIConfigItem]) -> ComponentSummary {
        var summary = ComponentSummary()
        for item in items {
            switch item.category {
            case .rules: summary.rules += 1
            case .skills: summary.skills += 1
            case .promptFiles: summary.prompts += 1
            case .customAgents: summary.agents += 1
            case .mcpConfigs: summary.mcpServers += 1
            case .hooks: summary.hooks += 1
            case .settings: break
            }
        }
        return summary
    }

    private func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let p = url.path
        if p.hasPrefix(home) { return "~" + p.dropFirst(home.count) }
        return p
    }
}
