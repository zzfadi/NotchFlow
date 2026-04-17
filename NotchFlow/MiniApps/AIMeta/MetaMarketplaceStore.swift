import Foundation
import SwiftUI
import os.log

private let log = Logger(
    subsystem: "com.notchflow.app",
    category: "MetaMarketplaceStore"
)

/// Holds the set of user-added marketplace manifest URLs plus the plugins
/// they expose. One always-present entry is the synthesized "My Machine"
/// marketplace — everything already on disk, surfaced as virtual plugins so
/// the AI Meta grid has something to show even before the user adds a
/// marketplace URL.
///
/// This is the glue between `MetaMarketplace` (the parser) and
/// `LocalPluginSynthesizer` (the local virtual source). The view layer
/// observes `pluginsByMarketplace` and re-renders.
@MainActor
final class MetaMarketplaceStore: ObservableObject {
    static let shared = MetaMarketplaceStore()

    @Published private(set) var subscribedURLs: [URL] = []
    @Published private(set) var pluginsByMarketplace: [String: [MetaPlugin]] = [:]
    @Published private(set) var localMarketplace: SyntheticMarketplace?
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastFetchError: String?

    private let urlDefaultsKey = "metaMarketplaceURLs"
    private let synthesizer = LocalPluginSynthesizer.shared

    private init() {
        loadSubscribedURLs()
    }

    // MARK: - Subscriptions

    func addMarketplace(_ url: URL) {
        guard !subscribedURLs.contains(url) else { return }
        subscribedURLs.append(url)
        persistURLs()
        Task { await refreshMarketplace(url) }
    }

    func removeMarketplace(_ url: URL) {
        subscribedURLs.removeAll { $0 == url }
        pluginsByMarketplace.removeValue(forKey: url.absoluteString)
        persistURLs()
    }

    // MARK: - Refresh

    /// Refreshes both the synthesized local marketplace and every subscribed
    /// remote manifest in parallel.
    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        refreshLocalMarketplace()

        await withTaskGroup(of: Void.self) { group in
            for url in subscribedURLs {
                group.addTask { await self.refreshMarketplace(url) }
            }
        }
    }

    func refreshLocalMarketplace() {
        let (marketplace, plugins) = synthesizer.synthesize()
        localMarketplace = marketplace
        pluginsByMarketplace[marketplace.id] = plugins
    }

    func refreshMarketplace(_ url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let baseURL = url.deletingLastPathComponent()
            let (_, plugins) = try MetaMarketplace.decode(
                data,
                baseURL: baseURL,
                marketplaceId: url.absoluteString
            )
            pluginsByMarketplace[url.absoluteString] = plugins
            lastFetchError = nil
        } catch {
            log.error("Failed to refresh \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            lastFetchError = "\(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    // MARK: - Persistence

    private func loadSubscribedURLs() {
        let raw = UserDefaults.standard.stringArray(forKey: urlDefaultsKey) ?? []
        subscribedURLs = raw.compactMap(URL.init(string:))
    }

    private func persistURLs() {
        let strings = subscribedURLs.map { $0.absoluteString }
        UserDefaults.standard.set(strings, forKey: urlDefaultsKey)
    }
}
