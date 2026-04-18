import Foundation

// MARK: - MetaMarketplace (manifest)

/// Decodes `.claude-plugin/marketplace.json` per the Anthropic plugin
/// marketplace schema. awesome-copilot's `.github/plugin/marketplace.json`
/// uses the same structure, so this type targets both.
///
/// Schema summary (trimmed to fields we actually use):
/// - `name`: marketplace identifier
/// - `owner`: contact info
/// - `metadata`: version + description for the marketplace itself
/// - `plugins[]`: plugin entries, each with a polymorphic `source`
/// - `strict`: when true, unknown fields error out at parse time; we ignore it
struct MetaMarketplace: Decodable {
    let name: String
    let owner: Owner?
    let metadata: Metadata?
    let plugins: [PluginEntry]

    struct Owner: Decodable, Hashable {
        let name: String
        let email: String?
        let url: String?
    }

    struct Metadata: Decodable, Hashable {
        let version: String?
        let description: String?
    }

    struct PluginEntry: Decodable {
        let name: String
        let displayName: String?
        let description: String?
        let version: String?
        let author: Author?
        let homepage: String?
        let license: String?
        let category: String?
        let keywords: [String]?
        let source: SourceValue
    }

    struct Author: Decodable, Hashable {
        let name: String?
        let email: String?
        let url: String?
    }
}

// MARK: - Polymorphic source

/// `source` can be either a string shorthand (`"owner/repo"`, `"./path"`,
/// `"https://…"`) or an object with a `type` discriminator. We decode into
/// one of these two cases and resolve the concrete `MetaSource` later.
enum SourceValue: Decodable {
    case string(String)
    case object([String: AnyJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }
        if let d = try? container.decode([String: AnyJSONValue].self) {
            self = .object(d)
            return
        }
        throw DecodingError.typeMismatch(
            SourceValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "source must be a string or an object"
            )
        )
    }
}

/// Scalar catch-all for the polymorphic `source` object. We only reach for
/// strings in practice, but keeping the other cases means a field typed as
/// bool/int/null doesn't crash the decoder.
enum AnyJSONValue: Decodable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        self = .null
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}

// MARK: - Decoding helpers

extension MetaMarketplace {
    /// Parse a raw marketplace payload and return both the decoded manifest and
    /// a ready-to-render list of `MetaPlugin` cards. `baseURL` is used to
    /// resolve relative source paths.
    static func decode(
        _ data: Data,
        baseURL: URL,
        marketplaceId: String? = nil
    ) throws -> (MetaMarketplace, [MetaPlugin]) {
        let marketplace = try JSONDecoder().decode(MetaMarketplace.self, from: data)
        let id = marketplaceId ?? marketplace.name
        let plugins = marketplace.plugins.map { entry in
            entry.toMetaPlugin(marketplaceId: id, baseURL: baseURL)
        }
        return (marketplace, plugins)
    }
}

extension MetaMarketplace.PluginEntry {
    func toMetaPlugin(marketplaceId: String, baseURL: URL) -> MetaPlugin {
        let resolved = resolveSource(baseURL: baseURL)
        let metaAuthor = author.map {
            MetaAuthor(
                name: $0.name ?? "",
                email: $0.email,
                url: $0.url.flatMap(URL.init(string:))
            )
        }
        return MetaPlugin(
            id: "\(marketplaceId):\(name)",
            name: name,
            displayName: displayName,
            description: description,
            version: version,
            author: metaAuthor,
            homepage: homepage.flatMap(URL.init(string:)),
            license: license,
            category: category,
            keywords: keywords ?? [],
            source: resolved,
            components: ComponentSummary(),
            files: [],
            marketplaceId: marketplaceId,
            rawSource: rawSourceString(),
            isInstalled: false,
            isEnabled: false
        )
    }

    private func rawSourceString() -> String? {
        if case .string(let s) = source { return s }
        return nil
    }

    private func resolveSource(baseURL: URL) -> MetaSource {
        switch source {
        case .string(let s):
            if s.hasPrefix("./") || s.hasPrefix("../") {
                return .relative(path: s, base: baseURL)
            }
            if s.hasPrefix("http://") || s.hasPrefix("https://") {
                if let url = URL(string: s) { return .url(url) }
                return .unknown(type: "url")
            }
            if s.contains("/") && !s.hasPrefix("/") {
                return .github(repo: s, ref: nil, path: nil)
            }
            return .unknown(type: "string")

        case .object(let dict):
            let type = dict["source"]?.stringValue
                ?? dict["type"]?.stringValue
                ?? "unknown"

            switch type {
            case "github":
                return .github(
                    repo: dict["repo"]?.stringValue ?? "",
                    ref: dict["ref"]?.stringValue,
                    path: dict["path"]?.stringValue
                )
            case "git", "git-subdir":
                return .git(
                    url: dict["url"]?.stringValue ?? "",
                    ref: dict["ref"]?.stringValue,
                    path: dict["path"]?.stringValue
                )
            case "npm":
                return .npm(
                    package: dict["package"]?.stringValue ?? "",
                    version: dict["version"]?.stringValue
                )
            case "url":
                if let s = dict["url"]?.stringValue, let url = URL(string: s) {
                    return .url(url)
                }
                return .unknown(type: "url")
            default:
                return .unknown(type: type)
            }
        }
    }
}
