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
    let marketplaceId: String
    let rawSource: String?
    var isInstalled: Bool
    var isEnabled: Bool

    var title: String { displayName ?? name }
}

// MARK: - MetaAuthor

struct MetaAuthor: Hashable {
    let name: String
    let email: String?
    let url: URL?
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
