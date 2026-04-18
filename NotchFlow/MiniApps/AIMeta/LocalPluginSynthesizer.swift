import Foundation
import SwiftUI
import Combine
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
/// Observes the underlying scanner reactively: when `scanner.allItems` or
/// `scanner.isScanning` change, `plugins` and `isScanning` republish on this
/// object, so SwiftUI views subscribing via `@ObservedObject` re-render
/// automatically as the scan completes.
@MainActor
final class LocalPluginSynthesizer: ObservableObject {
    static let shared = LocalPluginSynthesizer()

    let marketplace = SyntheticMarketplace(
        id: "local.my-machine",
        name: "My Machine",
        description: "AI components already on this Mac"
    )

    @Published private(set) var plugins: [MetaPlugin] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastScanDate: Date?

    private let store: AIConfigStore
    private var cancellables: Set<AnyCancellable> = []

    private init(store: AIConfigStore = AIConfigStore.shared) {
        self.store = store
        bindStore()
    }

    // MARK: - Public API

    /// Trigger a fresh on-disk scan through the shared store. No scan
    /// fires at init — the store decides when to scan (first visit to
    /// AI Config tab). This just forwards when the user taps refresh.
    func refresh() {
        store.scan()
    }

    // MARK: - Private

    private func bindStore() {
        store.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.synthesize(from: snapshot.items)
                self?.lastScanDate = snapshot.lastScanDate
            }
            .store(in: &cancellables)

        store.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
    }

    private func synthesize(from items: [AIConfigItem]) {
        let byProject = Dictionary(grouping: items) { $0.projectPath }

        plugins = byProject
            .sorted { $0.key.lastPathComponent < $1.key.lastPathComponent }
            .map { projectPath, items in
                let summary = components(from: items)
                let name = projectPath.lastPathComponent
                return MetaPlugin(
                    id: "\(marketplace.id):\(projectPath.path)",
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
                    files: [],
                    marketplaceId: marketplace.id,
                    rawSource: projectPath.path,
                    isInstalled: true,
                    isEnabled: true
                )
            }

        log.debug("Synthesized \(self.plugins.count, privacy: .public) local plugins")
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
