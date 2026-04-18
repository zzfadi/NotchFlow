import Foundation

// MARK: - MetaPlugin

/// A plugin entry surfaced in the AI Meta tab. Schema-compatible with the
/// Anthropic `.claude-plugin/marketplace.json` and the awesome-copilot
/// `.github/plugin/marketplace.json` formats, with a couple of extra fields
/// (`components`, `isInstalled`, `isEnabled`) that the NotchFlow UI synthesizes
/// from either scanning disk or inspecting a remote manifest.
struct MetaPlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String?
    let description: String?
    let version: String?
    let author: MetaAuthor?
    let homepage: URL?
    let license: String?
    let category: String?
    let keywords: [String]
    let source: MetaSource
    let components: ComponentSummary
    /// P3: file inventory for file-copy installs (awesome-copilot style).
    /// Populated by `MetaMarketplace.decode(_:)` when the manifest
    /// includes a file listing; empty for marketplaces that hand
    /// installs off to a CLI or deep-link. When empty, the file
    /// installer's `canInstall(_:)` returns `false`.
    let files: [MetaPluginFile]
    let marketplaceId: String
    let rawSource: String?
    /// Local-only state — `LocalPluginSynthesizer` sets this to `true`
    /// for synthesized "My Machine" cards. Remote cards keep
    /// `isInstalled == false` here and resolve the actual installed
    /// status dynamically via `isInstalled(given:)` against the scan
    /// snapshot's `installedIdentities`.
    var isInstalled: Bool
    var isEnabled: Bool

    var title: String { displayName ?? name }

    /// Canonical identity used by provenance matching. Derived from the
    /// resolved `MetaSource` through `PluginIdentityFactory` so a remote
    /// card and an on-disk plugin from the same source resolve to the
    /// same identity.
    var identity: PluginIdentity {
        PluginIdentity(
            canonicalSource: PluginIdentityFactory.canonicalSource(from: source),
            marketplaceId: marketplaceId,
            pluginName: name
        )
    }

    /// Whether this plugin appears in the live on-disk scan. Prefer
    /// this over reading `isInstalled` directly on remote cards —
    /// `isInstalled` is only authoritative for local synthesized cards.
    func isInstalledInScan(_ installed: Set<PluginIdentity>) -> Bool {
        if isInstalled { return true }
        return installed.contains(identity)
    }
}

// MARK: - MetaAuthor

struct MetaAuthor: Hashable {
    let name: String
    let email: String?
    let url: URL?
}

// MARK: - MetaPluginFile

/// One file a plugin contributes, resolved to an absolute remote URL
/// and tagged with its target category (e.g. a `.prompt.md` file lands
/// under `.github/prompts/`). Populated at manifest-decode time so the
/// `AwesomeCopilotFileInstaller` can stream downloads without a second
/// round-trip to the marketplace.
struct MetaPluginFile: Codable, Hashable {
    let relativePath: String
    let remoteURL: URL
    let kind: AIConfigCategory
    let sha256: String?
}

// MARK: - MetaSource

/// Where a plugin comes from. Mirrors the `source.type` values Anthropic
/// documents (`github`, `url`, `git-subdir`, `npm`, and relative-path strings),
/// plus a `.local` variant for items the synthesizer pulled off the user's own
/// disk.
enum MetaSource: Hashable {
    case github(repo: String, ref: String?, path: String?)
    case git(url: String, ref: String?, path: String?)
    case npm(package: String, version: String?)
    case url(URL)
    case relative(path: String, base: URL)
    case local(URL)
    case unknown(type: String)

    /// A one-line install command suitable for copy-to-clipboard. The
    /// first-class install-adapter layer comes in a later PR; for now the
    /// marketplace view copies this string so users can paste it into the
    /// tool they're using.
    var installCommand: String? {
        switch self {
        case .github(let repo, let ref, _):
            let suffix = ref.map { "@\($0)" } ?? ""
            return "/plugin install \(repo)\(suffix)"
        case .url(let url):
            return "/plugin install \(url.absoluteString)"
        case .npm(let pkg, let version):
            let v = version.map { "@\($0)" } ?? ""
            return "npm install \(pkg)\(v)"
        case .git(let url, let ref, _):
            let suffix = ref.map { "#\($0)" } ?? ""
            return "/plugin install \(url)\(suffix)"
        case .relative, .local, .unknown:
            return nil
        }
    }

    var label: String {
        switch self {
        case .github(let repo, _, _): return "github.com/\(repo)"
        case .git(let url, _, _): return url
        case .npm(let pkg, _): return "npm:\(pkg)"
        case .url(let url): return url.host ?? url.absoluteString
        case .relative(let path, _): return path
        case .local(let url): return url.path
        case .unknown(let type): return type
        }
    }

    /// A deep-link URL that hands the plugin off to a local client for
    /// install (Claude Code CLI / Cursor app). When no applicable scheme
    /// exists, the card falls back to copy-to-clipboard install commands.
    ///
    /// Today we emit `claude://plugin/install?source=…` for github/url
    /// sources — the Claude Code CLI registers that handler. The Cursor
    /// scheme is conditionally emitted only when the source points at
    /// Cursor's marketplace (we can't safely assume every github source
    /// belongs to Cursor), so for now this path is reserved for future
    /// wiring inside `PluginInstallerRegistry` in Phase 3.
    var deepLinkInstallURL: URL? {
        switch self {
        case .github(let repo, let ref, _):
            var components = URLComponents()
            components.scheme = "claude"
            components.host = "plugin"
            components.path = "/install"
            var items = [URLQueryItem(name: "source", value: repo)]
            if let ref { items.append(URLQueryItem(name: "ref", value: ref)) }
            components.queryItems = items
            return components.url
        case .url(let url):
            var components = URLComponents()
            components.scheme = "claude"
            components.host = "plugin"
            components.path = "/install"
            components.queryItems = [URLQueryItem(name: "source", value: url.absoluteString)]
            return components.url
        case .git, .npm, .relative, .local, .unknown:
            return nil
        }
    }
}

// MARK: - ComponentSummary

/// Rollup of what a plugin contributes. For installed/local plugins this is
/// derived by scanning the plugin directory; for remote marketplace entries
/// it's inferred from the manifest when the schema declares it, and stays
/// zero otherwise.
struct ComponentSummary: Hashable {
    var rules: Int = 0
    var skills: Int = 0
    var prompts: Int = 0
    var agents: Int = 0
    var mcpServers: Int = 0
    var hooks: Int = 0
    var commands: Int = 0

    var total: Int {
        rules + skills + prompts + agents + mcpServers + hooks + commands
    }

    var isEmpty: Bool { total == 0 }

    var chips: [ComponentChip] {
        var out: [ComponentChip] = []
        if rules > 0 { out.append(ComponentChip(label: "Rules", count: rules, systemImage: "doc.text.fill", colorHex: "FF6B35")) }
        if skills > 0 { out.append(ComponentChip(label: "Skills", count: skills, systemImage: "star.fill", colorHex: "FFD700")) }
        if prompts > 0 { out.append(ComponentChip(label: "Prompts", count: prompts, systemImage: "text.bubble.fill", colorHex: "7C3AED")) }
        if agents > 0 { out.append(ComponentChip(label: "Agents", count: agents, systemImage: "person.2.fill", colorHex: "EC4899")) }
        if mcpServers > 0 { out.append(ComponentChip(label: "MCP", count: mcpServers, systemImage: "server.rack", colorHex: "06B6D4")) }
        if hooks > 0 { out.append(ComponentChip(label: "Hooks", count: hooks, systemImage: "link.circle.fill", colorHex: "10B981")) }
        if commands > 0 { out.append(ComponentChip(label: "Commands", count: commands, systemImage: "terminal.fill", colorHex: "8B5CF6")) }
        return out
    }
}

struct ComponentChip: Hashable, Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let systemImage: String
    let colorHex: String
}
