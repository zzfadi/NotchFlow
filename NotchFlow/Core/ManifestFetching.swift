import Foundation

/// HTTP fetcher for marketplace manifest URLs. Wraps the single
/// `URLSession.shared.data(from:)` call that `MetaMarketplaceStore` makes
/// so tests can inject a fixture without reaching the network.
///
/// The protocol is deliberately minimal: one method, a blocking result.
/// If we ever need progress or streaming we can widen it, but today every
/// caller just wants "give me the bytes or throw".
protocol ManifestFetching: Sendable {
    func fetchManifest(from url: URL) async throws -> Data
}

struct URLSessionManifestFetcher: ManifestFetching {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchManifest(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
