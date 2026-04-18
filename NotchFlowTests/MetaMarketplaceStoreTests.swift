import XCTest
@testable import NotchFlow

/// Tests exercise `MetaMarketplaceStore` through its DI seams:
/// - `ManifestFetching` fake records call sites and returns canned data.
/// - `DefaultsStoring` fake holds an in-memory dictionary, so
///   persistence round-trips don't touch `UserDefaults.standard`.
///
/// Every test constructs a fresh store instance (via the internal init)
/// so state from the shared singleton can't leak in.
@MainActor
final class MetaMarketplaceStoreTests: XCTestCase {

    // MARK: - Fakes

    final class FakeManifestFetcher: ManifestFetching, @unchecked Sendable {
        var responses: [URL: Result<Data, Error>] = [:]
        private(set) var requestedURLs: [URL] = []

        func fetchManifest(from url: URL) async throws -> Data {
            requestedURLs.append(url)
            if let result = responses[url] {
                return try result.get()
            }
            // Default: an empty-but-valid manifest so refresh succeeds.
            return Self.emptyManifest
        }

        static let emptyManifest: Data = """
        { "name": "test", "plugins": [] }
        """.data(using: .utf8)!
    }

    final class FakeDefaultsStore: DefaultsStoring {
        var storage: [String: [String]] = [:]

        func stringArray(forKey key: String) -> [String]? {
            storage[key]
        }

        func setStringArray(_ value: [String], forKey key: String) {
            storage[key] = value
        }
    }

    // MARK: - Refresh gate

    func testInitDoesNotFetch() {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        _ = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)

        XCTAssertTrue(fetcher.requestedURLs.isEmpty,
                      "Store should not fetch on init — the first-open gate fires refresh lazily.")
    }

    func testHasEverRefreshedFlipsAfterFirstRefresh() async {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)

        XCTAssertFalse(store.hasEverRefreshed)
        await store.refreshAll()
        XCTAssertTrue(store.hasEverRefreshed)
    }

    func testRefreshIfNeededIsOneShot() async {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        let url = URL(string: "https://example.com/marketplace.json")!
        defaults.storage[DefaultsKeys.metaMarketplaceURLs] = [url.absoluteString]

        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)
        await store.refreshIfNeeded()
        await store.refreshIfNeeded()
        await store.refreshIfNeeded()

        XCTAssertEqual(fetcher.requestedURLs.filter { $0 == url }.count, 1,
                       "refreshIfNeeded should be a true first-time-only fetch")
    }

    // MARK: - Persistence round-trip

    func testLoadSubscribedURLsFromDefaults() {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        let url = URL(string: "https://example.com/marketplace.json")!
        defaults.storage[DefaultsKeys.metaMarketplaceURLs] = [url.absoluteString]

        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)
        XCTAssertEqual(store.subscribedURLs, [url])
    }

    func testAddMarketplacePersistsURL() async {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)

        let url = URL(string: "https://example.com/marketplace.json")!
        store.addMarketplace(url)

        XCTAssertEqual(
            defaults.storage[DefaultsKeys.metaMarketplaceURLs],
            [url.absoluteString]
        )
    }

    func testRemoveMarketplaceClearsPluginsAndErrors() async {
        let fetcher = FakeManifestFetcher()
        let defaults = FakeDefaultsStore()
        let url = URL(string: "https://example.com/marketplace.json")!
        defaults.storage[DefaultsKeys.metaMarketplaceURLs] = [url.absoluteString]

        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)
        await store.refreshMarketplace(url)
        store.removeMarketplace(url)

        XCTAssertFalse(store.isSubscribed(to: url))
        XCTAssertNil(store.pluginsByMarketplace[url.absoluteString])
        XCTAssertNil(store.fetchError(forMarketplaceId: url.absoluteString))
        XCTAssertEqual(defaults.storage[DefaultsKeys.metaMarketplaceURLs], [])
    }

    // MARK: - Error handling

    func testFetchFailurePopulatesErrorButDoesNotCrash() async {
        let fetcher = FakeManifestFetcher()
        let url = URL(string: "https://example.com/broken.json")!
        fetcher.responses[url] = .failure(URLError(.badServerResponse))

        let defaults = FakeDefaultsStore()
        defaults.storage[DefaultsKeys.metaMarketplaceURLs] = [url.absoluteString]

        let store = MetaMarketplaceStore(fetcher: fetcher, defaults: defaults)
        await store.refreshMarketplace(url)

        XCTAssertNotNil(store.fetchError(forMarketplaceId: url.absoluteString))
        XCTAssertNil(store.pluginsByMarketplace[url.absoluteString])
    }
}
