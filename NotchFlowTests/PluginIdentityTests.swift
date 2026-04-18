import XCTest
@testable import NotchFlow

/// Tests that two ways of constructing a `PluginIdentity` for the same
/// plugin produce the same canonical source — essential so a remote
/// marketplace card and an on-disk plugin walk don't register as two
/// different plugins.
final class PluginIdentityTests: XCTestCase {

    // MARK: - Canonical source: MetaSource

    func testGithubSourceProducesCanonicalGithubForm() {
        let source = MetaSource.github(repo: "anthropic/security-audit", ref: "main", path: nil)
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(from: source),
            "github:anthropic/security-audit"
        )
    }

    func testGithubSourceWithSubpathIncludesPath() {
        let source = MetaSource.github(repo: "anthropic/starter-pack", ref: nil, path: "plugins/security")
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(from: source),
            "github:anthropic/starter-pack/plugins/security"
        )
    }

    func testNpmSourceDropsVersion() {
        // Version shouldn't change identity — the same package at v1 and
        // v2 is still the same plugin for matching purposes.
        let v1 = MetaSource.npm(package: "@anthropic/foo", version: "1.0.0")
        let v2 = MetaSource.npm(package: "@anthropic/foo", version: "2.0.0")
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(from: v1),
            PluginIdentityFactory.canonicalSource(from: v2)
        )
    }

    // MARK: - Canonical source: plugin.json

    func testPluginJsonStringSourceMatchesGithubForm() {
        let json: [String: Any] = ["source": "anthropic/security-audit"]
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(fromPluginJson: json, fallbackName: "security-audit"),
            "github:anthropic/security-audit"
        )
    }

    func testPluginJsonObjectSourceForGithubMatchesMetaSource() {
        let json: [String: Any] = [
            "source": [
                "type": "github",
                "repo": "anthropic/security-audit"
            ]
        ]
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(fromPluginJson: json, fallbackName: "sa"),
            PluginIdentityFactory.canonicalSource(from: .github(repo: "anthropic/security-audit", ref: nil, path: nil))
        )
    }

    func testPluginJsonMissingSourceFallsBackToName() {
        XCTAssertEqual(
            PluginIdentityFactory.canonicalSource(fromPluginJson: [:], fallbackName: "my-plugin"),
            "name:my-plugin"
        )
    }

    // MARK: - Identity equality

    func testSameCanonicalSourceDifferentMarketplacesAreDistinct() {
        // Two marketplaces redistributing the same source should still
        // produce distinct identities so the UI doesn't merge them.
        let a = PluginIdentity(canonicalSource: "github:a/b", marketplaceId: "mk-1", pluginName: "p")
        let b = PluginIdentity(canonicalSource: "github:a/b", marketplaceId: "mk-2", pluginName: "p")
        XCTAssertNotEqual(a, b)
    }

    func testSameCanonicalSourceAndMarketplaceAreEqual() {
        let a = PluginIdentity(canonicalSource: "github:a/b", marketplaceId: "mk-1", pluginName: "p")
        let b = PluginIdentity(canonicalSource: "github:a/b", marketplaceId: "mk-1", pluginName: "p")
        XCTAssertEqual(a, b)
    }
}
