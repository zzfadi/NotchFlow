import Foundation
import SwiftUI
import Combine
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

    /// Fetch errors keyed by marketplace id. Per-marketplace so concurrent
    /// refreshes don't clobber each other's state — a previous PR iteration
    /// used a single `lastFetchError: String?` which was nondeterministic
    /// once more than one remote was subscribed.
    @Published private(set) var fetchErrors: [String: String] = [:]

    /// Marketplace ids currently being fetched. Lets a section show a
    /// loading row instead of the "empty marketplace" copy while a fresh
    /// add or per-marketplace refresh is in flight.
    @Published private(set) var fetchingMarketplaces: Set<String> = []

    private let urlDefaultsKey = "metaMarketplaceURLs"
    private let synthesizer = LocalPluginSynthesizer.shared
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        loadSubscribedURLs()
        bindLocalSynthesizer()
    }

    // MARK: - Marketplace ordering

    /// Rendering order: local marketplace first, then subscribed remotes in
    /// the order they were added. Views should iterate this, not the
    /// dictionary, so the UI is stable across re-renders.
    var orderedMarketplaceIds: [String] {
        var ids: [String] = []
        if let local = localMarketplace { ids.append(local.id) }
        ids.append(contentsOf: subscribedURLs.map { $0.absoluteString })
        return ids
    }

    func displayName(forMarketplaceId id: String) -> String {
        if id == localMarketplace?.id {
            return localMarketplace?.name ?? id
        }
        if let url = URL(string: id) {
            return url.host ?? url.absoluteString
        }
        return id
    }

    func description(forMarketplaceId id: String) -> String? {
        if id == localMarketplace?.id {
            return localMarketplace?.description
        }
        return nil
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
        fetchErrors.removeValue(forKey: url.absoluteString)
        persistURLs()
    }

    func fetchError(forMarketplaceId id: String) -> String? {
        fetchErrors[id]
    }

    func isFetching(marketplaceId id: String) -> Bool {
        fetchingMarketplaces.contains(id)
    }

    func isSubscribed(to url: URL) -> Bool {
        subscribedURLs.contains(url)
    }

    // MARK: - Refresh

    /// Refreshes both the synthesized local marketplace (by triggering a
    /// fresh disk scan) and every subscribed remote manifest in parallel.
    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        synthesizer.refresh()

        await withTaskGroup(of: Void.self) { group in
            for url in subscribedURLs {
                group.addTask { await self.refreshMarketplace(url) }
            }
        }
    }

    func refreshMarketplace(_ url: URL) async {
        let marketplaceId = url.absoluteString
        fetchingMarketplaces.insert(marketplaceId)
        defer { fetchingMarketplaces.remove(marketplaceId) }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let baseURL = url.deletingLastPathComponent()
            let (_, plugins) = try MetaMarketplace.decode(
                data,
                baseURL: baseURL,
                marketplaceId: marketplaceId
            )
            pluginsByMarketplace[marketplaceId] = plugins
            fetchErrors.removeValue(forKey: marketplaceId)
        } catch {
            log.error("Failed to refresh \(marketplaceId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            fetchErrors[marketplaceId] = error.localizedDescription
        }
    }

    // MARK: - Private

    private func bindLocalSynthesizer() {
        localMarketplace = synthesizer.marketplace

        synthesizer.$plugins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plugins in
                guard let self else { return }
                self.pluginsByMarketplace[self.synthesizer.marketplace.id] = plugins
            }
            .store(in: &cancellables)
    }

    private func loadSubscribedURLs() {
        let raw = UserDefaults.standard.stringArray(forKey: urlDefaultsKey) ?? []
        subscribedURLs = raw.compactMap(URL.init(string:))
    }

    private func persistURLs() {
        let strings = subscribedURLs.map { $0.absoluteString }
        UserDefaults.standard.set(strings, forKey: urlDefaultsKey)
    }
}
