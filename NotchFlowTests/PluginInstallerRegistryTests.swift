import XCTest
@testable import NotchFlow

/// Exercises `PluginInstallerRegistry.installer(for:)` — the
/// coordinator routes every install through this call, so if the
/// routing drifts the whole install flow breaks.
@MainActor
final class PluginInstallerRegistryTests: XCTestCase {

    private func makePlugin(
        source: MetaSource,
        marketplaceId: String,
        files: [MetaPluginFile] = []
    ) -> MetaPlugin {
        MetaPlugin(
            id: "test:plugin",
            name: "p",
            displayName: nil,
            description: nil,
            version: nil,
            author: nil,
            homepage: nil,
            license: nil,
            category: nil,
            keywords: [],
            source: source,
            components: ComponentSummary(),
            files: files,
            marketplaceId: marketplaceId,
            rawSource: nil,
            isInstalled: false,
            isEnabled: false
        )
    }

    func testClaudeCodeSourceRoutesToClaudeInstaller() {
        let plugin = makePlugin(
            source: .github(repo: "anthropic/security-audit", ref: nil, path: nil),
            marketplaceId: "claude-marketplace"
        )
        let installer = PluginInstallerRegistry.installer(for: plugin)
        XCTAssertTrue(installer is ClaudeCodePluginInstaller)
    }

    func testAwesomeCopilotMarketplaceRoutesToFileInstaller() {
        let plugin = makePlugin(
            source: .github(repo: "github/awesome-copilot", ref: "main", path: nil),
            marketplaceId: "github/awesome-copilot"
        )
        let installer = PluginInstallerRegistry.installer(for: plugin)
        XCTAssertTrue(installer is AwesomeCopilotFileInstaller)
    }

    func testLocalSourceRoutesToNoOpInstaller() {
        let plugin = makePlugin(
            source: .local(URL(fileURLWithPath: "/tmp/fake")),
            marketplaceId: "local.my-machine"
        )
        let installer = PluginInstallerRegistry.installer(for: plugin)
        XCTAssertTrue(installer is NoOpPluginInstaller)
    }

    func testFileInstallerDeclinesWhenNoFilesDeclared() {
        let plugin = makePlugin(
            source: .github(repo: "github/awesome-copilot", ref: "main", path: nil),
            marketplaceId: "github/awesome-copilot",
            files: []
        )
        let installer = AwesomeCopilotFileInstaller()
        XCTAssertFalse(installer.canInstall(plugin),
                       "File installer must decline when manifest omits file inventory")
    }

    func testFileInstallerAcceptsWhenFilesDeclared() {
        let plugin = makePlugin(
            source: .github(repo: "github/awesome-copilot", ref: "main", path: nil),
            marketplaceId: "github/awesome-copilot",
            files: [
                MetaPluginFile(
                    relativePath: ".github/prompts/refactor.prompt.md",
                    remoteURL: URL(string: "https://example.com/refactor.prompt.md")!,
                    kind: .promptFiles,
                    sha256: nil
                )
            ]
        )
        let installer = AwesomeCopilotFileInstaller()
        XCTAssertTrue(installer.canInstall(plugin))
    }
}
