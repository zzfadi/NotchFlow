import Foundation

// MARK: - PluginIdentity

/// A normalized identifier for a plugin across marketplaces and on-disk
/// installs. The `canonicalSource` carries the true origin (e.g.
/// `github:anthropic/security-audit`) so matching is stable even when a
/// plugin appears with slightly different naming in two places.
///
/// Why not just name-match? Two plugins named "security-audit" from
/// different authors would collide. `canonicalSource` disambiguates.
///
/// Why include `marketplaceId`? It's the tie-breaker for the rare case
/// where two marketplaces redistribute the same canonical source — they
/// still produce distinct identities, so the UI doesn't merge them.
struct PluginIdentity: Hashable, Codable {
    let canonicalSource: String
    let marketplaceId: String?
    let pluginName: String
}

// MARK: - PluginProvenance

/// Links an on-disk AI-config file to the plugin that installed it.
/// Attached to `AIConfigItem` during scanning; drives the provenance
/// badge in the AI Config row and the "Installed" state in the
/// marketplace sheet.
///
/// `scope` disambiguates user-level vs project-level vs team-level
/// installs — in P3 this shapes the uninstall target when the user
/// clicks the uninstall button.
struct PluginProvenance: Hashable, Codable {
    let identity: PluginIdentity
    let version: String?
    let scope: Scope
    let isEnabled: Bool

    enum Scope: String, Codable {
        case user
        case project
        case team
        case managed
        case sidecar
    }
}

// MARK: - PluginIdentityFactory

/// Single source of truth for canonicalizing plugin sources. Both
/// `MetaPlugin` (remote marketplace cards) and `AIConfigScanner`
/// (on-disk plugin dirs) call in here, so two sources that represent
/// the same plugin produce the same `canonicalSource` string.
enum PluginIdentityFactory {
    /// From a marketplace manifest's resolved `MetaSource`. Mirrors the
    /// scheme used by the Claude Code CLI when it records plugin
    /// metadata, so an on-disk `plugin.json` parsed by
    /// `canonicalSource(fromPluginJson:fallbackName:)` matches.
    static func canonicalSource(from source: MetaSource) -> String {
        switch source {
        case .github(let repo, _, let path):
            if let path, !path.isEmpty {
                return "github:\(repo)/\(path)"
            }
            return "github:\(repo)"
        case .git(let url, _, let path):
            if let path, !path.isEmpty {
                return "git:\(url)#\(path)"
            }
            return "git:\(url)"
        case .npm(let pkg, _):
            return "npm:\(pkg)"
        case .url(let url):
            return "url:\(url.absoluteString)"
        case .relative(let path, _):
            return "relative:\(path)"
        case .local(let url):
            return "local:\(url.resolvingSymlinksInPath().path)"
        case .unknown(let type):
            return "unknown:\(type)"
        }
    }

    /// From the `source` field of an installed plugin's `plugin.json`.
    /// Falls back to `fallbackName` when the plugin.json doesn't record
    /// a source (some plugins are installed from a local path). The
    /// fallback produces a stable-but-coarse identity keyed on name —
    /// good enough for provenance, not good enough for cross-marketplace
    /// matching.
    static func canonicalSource(fromPluginJson json: [String: Any], fallbackName: String) -> String {
        if let source = json["source"] as? String, !source.isEmpty {
            if source.contains("://") {
                return "url:\(source)"
            }
            if source.hasPrefix("github:") || source.hasPrefix("git:") ||
               source.hasPrefix("npm:") || source.hasPrefix("url:") {
                return source
            }
            if source.contains("/") && !source.hasPrefix("/") {
                return "github:\(source)"
            }
            return "name:\(source)"
        }
        if let sourceObj = json["source"] as? [String: Any] {
            if let type = sourceObj["type"] as? String {
                switch type {
                case "github":
                    if let repo = sourceObj["repo"] as? String {
                        if let path = sourceObj["path"] as? String, !path.isEmpty {
                            return "github:\(repo)/\(path)"
                        }
                        return "github:\(repo)"
                    }
                case "git", "git-subdir":
                    if let url = sourceObj["url"] as? String {
                        if let path = sourceObj["path"] as? String, !path.isEmpty {
                            return "git:\(url)#\(path)"
                        }
                        return "git:\(url)"
                    }
                case "npm":
                    if let pkg = sourceObj["package"] as? String {
                        return "npm:\(pkg)"
                    }
                case "url":
                    if let url = sourceObj["url"] as? String {
                        return "url:\(url)"
                    }
                default:
                    break
                }
            }
        }
        return "name:\(fallbackName)"
    }
}
