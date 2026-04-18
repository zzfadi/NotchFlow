import Foundation

/// Stateless disk-walk service for AI configuration files.
///
/// Scan lifecycle (state, tokens, cancellation, publication) lives in
/// `AIConfigStore`. This type is just the walk logic + any per-scan
/// dependencies (filesystem, home directory, settings/permissions
/// providers). It's deliberately not `ObservableObject` and carries no
/// `@Published` fields — multiple instances can exist harmlessly (tests
/// freely construct fakes).
///
/// Paths come in via `performScan(projectPaths:)`. The store collects
/// them on the main actor before handing off to a detached task that
/// calls this method. The `settings` / `permissions` deps are still held
/// on this type because Phase 2's plugin-directory walks need them
/// (per-project `.claude/settings.json` lookup), even though Phase 0
/// itself doesn't read them.
@MainActor
final class AIConfigScanner {
    private let settings: SettingsProviding
    private let permissions: PermissionsProviding
    private let home: HomeDirectoryProviding
    private let fs: FileSystemProviding

    init(
        settings: SettingsProviding = SettingsManager.shared,
        permissions: PermissionsProviding = PermissionManager.shared,
        home: HomeDirectoryProviding = DefaultHomeDirectoryProvider(),
        fs: FileSystemProviding = DefaultFileSystem()
    ) {
        self.settings = settings
        self.permissions = permissions
        self.home = home
        self.fs = fs
    }

    // MARK: - Public

    /// Scan the given project paths for AI-config files, group into
    /// category buckets, and return a `ScanResult`. Pure — no
    /// `@Published` state is mutated. Safe to call from a detached task
    /// (the disk walk delegates to `nonisolated static` helpers that
    /// don't touch this instance).
    nonisolated func performScan(projectPaths: [String]) async -> ScanResult {
        // Capture the home URL up front so all plugin walks share it.
        // `home` is Sendable, so this is safe across the await.
        let homeURL = await MainActor.run { self.home.home }

        // 1. Base project walk — unchanged from P0.
        let baseItems = await Self.performScan(projectPaths: projectPaths)

        // 2. Plugin cache walks — produce provenance + additional items
        //    whose `sourcePlugin` is stamped in place.
        let claudeProv = await Self.scanInstalledClaudeCodePlugins(home: homeURL)
        let cursorProv = await Self.scanInstalledCursorPlugins(home: homeURL)
        let sidecarProv = await Self.scanSidecarProvenance(projectPaths: projectPaths)

        // Merge provenance maps; later entries win on key collisions —
        // project-scoped sidecar provenance beats user-scoped plugin
        // directory provenance for the same file (closer to the user's
        // intent when they manually install into a project).
        var provenance = claudeProv
        for (k, v) in cursorProv { provenance[k] = v }
        for (k, v) in sidecarProv { provenance[k] = v }

        // Stamp `sourcePlugin` onto any base item whose canonicalized
        // path has a provenance entry. Items from the plugin walks
        // themselves are already stamped — but they share canonical
        // paths with possible project-walk duplicates, so dedupe again.
        var byPath: [URL: AIConfigItem] = [:]
        for item in baseItems {
            let key = item.path.resolvingSymlinksInPath()
            if let prov = provenance[key] {
                byPath[key] = AIConfigItem(
                    id: item.id,
                    path: item.path,
                    fileType: item.fileType,
                    projectPath: item.projectPath,
                    lastModified: item.lastModified,
                    fileSize: item.fileSize,
                    metadata: item.metadata,
                    isGlobal: item.isGlobal,
                    sourcePlugin: prov
                )
            } else {
                byPath[key] = item
            }
        }

        // Also surface plugin-directory items that the project walk
        // didn't see (because the plugin cache isn't a granted folder).
        let pluginCacheItems = await Self.scanPluginCacheItems(
            home: homeURL,
            provenance: provenance
        )
        for item in pluginCacheItems {
            let key = item.path.resolvingSymlinksInPath()
            if byPath[key] == nil { byPath[key] = item }
        }

        let items = Array(byPath.values).sorted { $0.lastModified > $1.lastModified }
        let groups = Self.groupItemsByCategory(items)

        let enabled = await Self.parseEnabledPlugins(home: homeURL)

        return ScanResult(
            items: items,
            categoryGroups: groups,
            lastScanDate: Date(),
            provenanceByPath: provenance,
            enabledIdentities: enabled
        )
    }

    // MARK: - Plugin-directory walks (P2)

    /// Walk `~/.claude/plugins/*`. For each plugin subdirectory, parse
    /// `plugin.json` (if present) to build a `PluginIdentity`, then
    /// enumerate AI-config files inside the plugin directory and stamp
    /// provenance entries keyed by resolved path.
    nonisolated static func scanInstalledClaudeCodePlugins(
        home: URL
    ) async -> [URL: PluginProvenance] {
        let pluginsDir = home.appendingPathComponent(".claude/plugins", isDirectory: true)
        return scanPluginDir(
            pluginsDir: pluginsDir,
            manifestFilenames: ["plugin.json", ".claude-plugin/plugin.json"],
            scope: .user
        )
    }

    /// Walk `~/.cursor/plugins/*`. Identical to the Claude variant but
    /// with Cursor's manifest filename (`.cursor-plugin/plugin.json`).
    nonisolated static func scanInstalledCursorPlugins(
        home: URL
    ) async -> [URL: PluginProvenance] {
        let pluginsDir = home.appendingPathComponent(".cursor/plugins", isDirectory: true)
        return scanPluginDir(
            pluginsDir: pluginsDir,
            manifestFilenames: ["plugin.json", ".cursor-plugin/plugin.json"],
            scope: .user
        )
    }

    /// Shared walker for a plugin cache directory. Skips silently when
    /// the directory doesn't exist (plugin system never used).
    nonisolated static func scanPluginDir(
        pluginsDir: URL,
        manifestFilenames: [String],
        scope: PluginProvenance.Scope
    ) -> [URL: PluginProvenance] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pluginsDir.path) else { return [:] }

        var out: [URL: PluginProvenance] = [:]
        guard let children = try? fm.contentsOfDirectory(
            at: pluginsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return out }

        for dir in children {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            // Locate manifest.
            var manifest: [String: Any]?
            for filename in manifestFilenames {
                let path = dir.appendingPathComponent(filename)
                if fm.fileExists(atPath: path.path),
                   let data = try? Data(contentsOf: path),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    manifest = json
                    break
                }
            }

            let pluginName = (manifest?["name"] as? String) ?? dir.lastPathComponent
            let version = manifest?["version"] as? String
            let canonical = PluginIdentityFactory.canonicalSource(
                fromPluginJson: manifest ?? [:],
                fallbackName: pluginName
            )
            let identity = PluginIdentity(
                canonicalSource: canonical,
                marketplaceId: nil,
                pluginName: pluginName
            )
            let provenance = PluginProvenance(
                identity: identity,
                version: version,
                scope: scope,
                isEnabled: true
            )

            // Stamp every AI-config-looking file inside the plugin dir.
            enumerate(dir: dir) { url in
                out[url.resolvingSymlinksInPath()] = provenance
            }
        }

        return out
    }

    /// Shallow-recursive enumeration of `dir`, invoking `handler` for
    /// each regular file. `ScannerSkipList` is intentionally NOT
    /// consulted here — plugin directories are small and we want
    /// exhaustive coverage.
    nonisolated static func enumerate(dir: URL, handler: (URL) -> Void) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return }

        for case let url as URL in enumerator {
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            if isRegular { handler(url) }
        }
    }

    /// Walk project folders for `.notchflow-provenance.json` sidecars.
    /// Written by the P3 `AwesomeCopilotFileInstaller` to remember which
    /// files it placed in a user-chosen directory (the
    /// awesome-copilot convention is pure file-copy — there's no plugin
    /// cache to walk, so the installer stores provenance locally).
    nonisolated static func scanSidecarProvenance(
        projectPaths: [String]
    ) async -> [URL: PluginProvenance] {
        var out: [URL: PluginProvenance] = [:]
        let fm = FileManager.default

        for path in projectPaths {
            let root = URL(fileURLWithPath: path)
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let anyObj = enumerator.nextObject() {
                guard let url = anyObj as? URL else { continue }
                guard url.lastPathComponent == ".notchflow-provenance.json" else { continue }
                guard let data = try? Data(contentsOf: url),
                      let rawJson = try? JSONSerialization.jsonObject(with: data),
                      let json = rawJson as? [String: [String: Any]]
                else { continue }

                let folder = url.deletingLastPathComponent()
                for (filename, entry) in json {
                    let canonical = (entry["canonicalSource"] as? String) ?? "name:\(filename)"
                    let pluginName = (entry["pluginName"] as? String) ?? filename
                    let marketplaceId = entry["marketplaceId"] as? String
                    let version = entry["version"] as? String
                    let identity = PluginIdentity(
                        canonicalSource: canonical,
                        marketplaceId: marketplaceId,
                        pluginName: pluginName
                    )
                    let provenance = PluginProvenance(
                        identity: identity,
                        version: version,
                        scope: .sidecar,
                        isEnabled: true
                    )
                    let fileURL = folder.appendingPathComponent(filename)
                    out[fileURL.resolvingSymlinksInPath()] = provenance
                }
            }
        }

        return out
    }

    /// Surface AI-config items found inside the plugin cache
    /// directories as first-class `AIConfigItem`s. The base scanner
    /// doesn't walk `~/.claude/plugins/` (it's not a granted folder);
    /// we do it here so the AI Config list shows every provenance-
    /// tagged file even when the plugin lives outside project roots.
    nonisolated static func scanPluginCacheItems(
        home: URL,
        provenance: [URL: PluginProvenance]
    ) async -> [AIConfigItem] {
        var items: [AIConfigItem] = []
        for (resolvedPath, prov) in provenance {
            // Only surface files under the plugin cache dirs; sidecars
            // already live under project paths and are caught by the
            // normal scan pass.
            guard prov.scope != .sidecar else { continue }

            // Infer a file type from the filename. Non-matching files
            // (READMEs, license files, scripts) are skipped because
            // the AI Config view only knows how to render known types.
            guard let fileType = inferFileType(for: resolvedPath) else { continue }

            let fm = FileManager.default
            let attrs = try? fm.attributesOfItem(atPath: resolvedPath.path)
            let lastModified = (attrs?[.modificationDate] as? Date) ?? Date()
            let fileSize = attrs?[.size] as? Int64

            // `projectPath` for plugin items is the plugin directory
            // itself (the nearest subdir under `~/.claude/plugins/` or
            // `~/.cursor/plugins/`). Resolved best-effort by walking
            // up from the file.
            let projectPath = pluginRoot(for: resolvedPath, home: home) ?? resolvedPath.deletingLastPathComponent()

            items.append(AIConfigItem(
                path: resolvedPath,
                fileType: fileType,
                projectPath: projectPath,
                lastModified: lastModified,
                fileSize: fileSize,
                metadata: nil,
                isGlobal: false,
                sourcePlugin: prov
            ))
        }
        return items
    }

    nonisolated static func inferFileType(for url: URL) -> AIConfigFileType? {
        let name = url.lastPathComponent
        if name == "CLAUDE.md" { return .claudeMd }
        if name == "AGENTS.md" { return .agentsMd }
        if name == "SKILL.md" { return .skillMd }
        if name == ".cursorrules" { return .cursorRules }
        if name.hasSuffix(".prompt.md") { return .promptMd }
        if name.hasSuffix(".instructions.md") && name != "copilot-instructions.md" {
            return .instructionsMd
        }
        if url.pathExtension == "mdc" { return .cursorMdcFile }
        if name == "mcp.json" || name == ".mcp.json" { return .mcpJson }
        return nil
    }

    nonisolated static func pluginRoot(for file: URL, home: URL) -> URL? {
        let claudePluginsDir = home.appendingPathComponent(".claude/plugins", isDirectory: true)
            .resolvingSymlinksInPath()
        let cursorPluginsDir = home.appendingPathComponent(".cursor/plugins", isDirectory: true)
            .resolvingSymlinksInPath()

        let filePath = file.resolvingSymlinksInPath().path

        for root in [claudePluginsDir, cursorPluginsDir] {
            let rootPath = root.path
            guard filePath.hasPrefix(rootPath + "/") else { continue }
            let tail = filePath.dropFirst(rootPath.count + 1)
            guard let firstSlash = tail.firstIndex(of: "/") else {
                return root.appendingPathComponent(String(tail))
            }
            return root.appendingPathComponent(String(tail[..<firstSlash]))
        }
        return nil
    }

    /// Read `~/.claude/settings.json` and extract enabled plugin
    /// identities. Best-effort: returns empty on any parse failure —
    /// enabled state is a UI hint, not a correctness requirement.
    nonisolated static func parseEnabledPlugins(home: URL) async -> Set<PluginIdentity> {
        let settingsURL = home.appendingPathComponent(".claude/settings.json")
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var enabled: Set<PluginIdentity> = []
        if let plugins = json["plugins"] as? [String: Any] {
            for (name, value) in plugins {
                let isOn: Bool = {
                    if let b = value as? Bool { return b }
                    if let d = value as? [String: Any], let b = d["enabled"] as? Bool { return b }
                    return true
                }()
                guard isOn else { continue }
                enabled.insert(PluginIdentity(
                    canonicalSource: "name:\(name)",
                    marketplaceId: nil,
                    pluginName: name
                ))
            }
        }
        return enabled
    }

    // MARK: - Private Scanning Methods
    //
    // All disk-walk helpers are `nonisolated static` so they run on the
    // background executor dispatched by `Task.detached` in `scan()`. They
    // take all inputs as parameters and return results; none of them touch
    // `self` or any @MainActor state, so there's no risk of priority
    // inversion or UI stalls from deep directory recursion.

    nonisolated static func performScan(projectPaths: [String]) async -> [AIConfigItem] {
        var items: [AIConfigItem] = []

        // 1. Scan global config locations (MCP configs, user settings)
        items.append(contentsOf: scanGlobalConfigs())

        // 2. Scan project directories. Dedupe on standardized path so we
        //    don't walk the same tree twice.
        for pathString in projectPaths {
            if Task.isCancelled { return [] }
            let path = URL(fileURLWithPath: pathString)

            guard FileManager.default.fileExists(atPath: path.path) else {
                continue
            }

            let foundItems = await scanDirectory(path)
            items.append(contentsOf: foundItems)
        }

        // Remove duplicates. `resolvingSymlinksInPath()` canonicalizes the
        // path string so the same on-disk file seen as `/private/var/...`
        // from one walk and `/var/...` from another collapses to a single
        // entry. `NSOpenPanel` in particular returns resolved paths, while
        // manually-added legacy paths may not be resolved — without this,
        // overlapping scan roots slip past dedupe.
        var seen = Set<String>()
        items = items.filter { item in
            let key = item.path.resolvingSymlinksInPath().path
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return items.sorted { $0.lastModified > $1.lastModified }
    }

    /// Scan global config locations (user-level configs)
    nonisolated static func scanGlobalConfigs() -> [AIConfigItem] {
        var items: [AIConfigItem] = []
        let fileManager = FileManager.default

        // Scan all known global config locations
        for (path, fileType) in GlobalConfigLocations.all where fileManager.fileExists(atPath: path.path) {
            if let item = createConfigItem(
                at: path,
                fileType: fileType,
                projectPath: path.deletingLastPathComponent(),
                isGlobal: true
            ) {
                items.append(item)
            }
        }

        return items
    }

    nonisolated static func scanDirectory(_ directory: URL) async -> [AIConfigItem] {
        var items: [AIConfigItem] = []
        let fileManager = FileManager.default

        // Check for AI config files in this directory (exact pattern matches)
        for fileType in AIConfigFileType.allCases {
            // Skip glob patterns and global-only configs
            guard !fileType.isGlobPattern && !fileType.isGlobalConfig else { continue }

            for pattern in fileType.patterns {
                let targetPath = directory.appendingPathComponent(pattern)

                if fileManager.fileExists(atPath: targetPath.path) {
                    if let item = createConfigItem(at: targetPath, fileType: fileType, projectPath: directory) {
                        items.append(item)
                    }
                }
            }
        }

        // Scan for glob patterns in this directory
        await scanGlobPatterns(directory, items: &items)

        // Recursively scan subdirectories (up to 4 levels deep)
        await scanSubdirectories(directory, depth: 0, maxDepth: 4, items: &items)

        return items
    }

    nonisolated static func scanSubdirectories(_ directory: URL, depth: Int, maxDepth: Int, items: inout [AIConfigItem]) async {
        guard depth < maxDepth else { return }

        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            // Check for cancellation to allow long scans to be interrupted
            if Task.isCancelled { return }

            guard let isDirectory = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory == true else { continue }

            // Skip certain directories
            let name = item.lastPathComponent
            if shouldSkipDirectory(name) {
                continue
            }

            // Check for AI config files in this directory (exact matches)
            for fileType in AIConfigFileType.allCases {
                guard !fileType.isGlobPattern && !fileType.isGlobalConfig else { continue }

                for pattern in fileType.patterns {
                    let targetPath = item.appendingPathComponent(pattern)

                    if fileManager.fileExists(atPath: targetPath.path) {
                        if let configItem = createConfigItem(at: targetPath, fileType: fileType, projectPath: item) {
                            items.append(configItem)
                        }
                    }
                }
            }

            // Scan for glob patterns in this directory
            await scanGlobPatterns(item, items: &items)

            // Recurse into subdirectory
            await scanSubdirectories(item, depth: depth + 1, maxDepth: maxDepth, items: &items)
        }
    }

    /// Scan for glob pattern matches (*.prompt.md, *.mdc, *.instructions.md)
    nonisolated static func scanGlobPatterns(_ directory: URL, items: inout [AIConfigItem]) async {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return }

        for file in contents {
            let filename = file.lastPathComponent

            // Check for .prompt.md files
            if filename.hasSuffix(".prompt.md") {
                if let item = createConfigItem(at: file, fileType: .promptMd, projectPath: directory) {
                    items.append(item)
                }
            }

            // Check for .instructions.md files (VS Code Copilot format)
            if filename.hasSuffix(".instructions.md") && filename != "copilot-instructions.md" {
                if let item = createConfigItem(at: file, fileType: .instructionsMd, projectPath: directory) {
                    items.append(item)
                }
            }
        }

        // Scan .cursor/ for .mdc files (modern Cursor rules)
        let cursorPath = directory.appendingPathComponent(".cursor")
        if fileManager.fileExists(atPath: cursorPath.path) {
            if let cursorContents = try? fileManager.contentsOfDirectory(
                at: cursorPath,
                includingPropertiesForKeys: nil,
                options: []
            ) {
                for file in cursorContents where file.pathExtension == "mdc" {
                    if let item = createConfigItem(at: file, fileType: .cursorMdcFile, projectPath: directory) {
                        items.append(item)
                    }
                }
            }
        }

        // Also scan .github/prompts/ for .prompt.md files
        let githubPromptsPath = directory.appendingPathComponent(".github/prompts")
        if fileManager.fileExists(atPath: githubPromptsPath.path) {
            if let promptFiles = try? fileManager.contentsOfDirectory(
                at: githubPromptsPath,
                includingPropertiesForKeys: nil,
                options: []
            ) {
                for file in promptFiles where file.lastPathComponent.hasSuffix(".prompt.md") {
                    if let item = createConfigItem(at: file, fileType: .promptMd, projectPath: directory) {
                        items.append(item)
                    }
                }
            }
        }
    }

    nonisolated static func shouldSkipDirectory(_ name: String) -> Bool {
        ScannerSkipList.shouldSkip(directoryName: name)
    }

    nonisolated static func createConfigItem(
        at path: URL,
        fileType: AIConfigFileType,
        projectPath: URL,
        isGlobal: Bool = false
    ) -> AIConfigItem? {
        let fileManager = FileManager.default

        guard let attrs = try? fileManager.attributesOfItem(atPath: path.path) else {
            return nil
        }

        let lastModified = attrs[.modificationDate] as? Date ?? Date()
        let fileSize = attrs[.size] as? Int64

        // Extract metadata for skill files and agent configs
        var metadata: ConfigMetadata?
        if fileType == .skillMd || fileType == .customAgentYaml {
            metadata = extractYAMLFrontmatter(from: path)
        }

        return AIConfigItem(
            path: path,
            fileType: fileType,
            projectPath: projectPath,
            lastModified: lastModified,
            fileSize: fileSize,
            metadata: metadata,
            isGlobal: isGlobal
        )
    }

    /// Extract YAML frontmatter metadata from a file (for SKILL.md, agent.yaml, etc.)
    nonisolated static func extractYAMLFrontmatter(from path: URL) -> ConfigMetadata? {
        // Ensure the path points to a regular file before attempting to read
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }

        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return nil
        }

        // Check for YAML frontmatter (starts with ---)
        guard content.hasPrefix("---") else { return nil }

        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var name: String?
        var description: String?
        var version: String?

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine == "---" {
                if inFrontmatter { break }
                inFrontmatter = true
                continue
            }

            if inFrontmatter {
                if trimmedLine.hasPrefix("name:") {
                    name = extractYAMLValue(from: trimmedLine, key: "name")
                } else if trimmedLine.hasPrefix("description:") {
                    description = extractYAMLValue(from: trimmedLine, key: "description")
                } else if trimmedLine.hasPrefix("version:") {
                    version = extractYAMLValue(from: trimmedLine, key: "version")
                }
            }
        }

        if name != nil || description != nil || version != nil {
            return ConfigMetadata(name: name, description: description, version: version)
        }
        return nil
    }

    nonisolated static func extractYAMLValue(from line: String, key: String) -> String? {
        let value = line
            .replacingOccurrences(of: "\(key):", with: "")
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        return value.isEmpty ? nil : value
    }

    nonisolated static func groupItemsByCategory(_ items: [AIConfigItem]) -> [AIConfigCategoryGroup] {
        var groups: [AIConfigCategory: AIConfigCategoryGroup] = [:]

        for item in items {
            let category = item.category
            if var group = groups[category] {
                group.items.append(item)
                groups[category] = group
            } else {
                groups[category] = AIConfigCategoryGroup(category: category, items: [item])
            }
        }

        // Sort groups by item count, items by lastModified
        return groups.values.map { group in
            var sortedGroup = group
            sortedGroup.items.sort { $0.lastModified > $1.lastModified }
            return sortedGroup
        }.sorted { $0.items.count > $1.items.count }
    }

    // MARK: - Preview Content
    //
    // Preview is a pure read operation — no scanner state involved.
    // Exposed as static so consumers (view layer) don't need a scanner
    // instance to show a file preview.

    nonisolated static func previewContent(for item: AIConfigItem, maxLines: Int = 20) -> String? {
        if item.isDirectory {
            return previewDirectoryContent(item.path)
        }

        guard let content = try? String(contentsOf: item.path, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        if lines.count <= maxLines {
            return content
        }

        return lines.prefix(maxLines).joined(separator: "\n") + "\n..."
    }

    nonisolated private static func previewDirectoryContent(_ path: URL) -> String? {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: []) else {
            return nil
        }

        let items = contents.map { $0.lastPathComponent }.sorted()
        return "Directory contents:\n" + items.map { "  - \($0)" }.joined(separator: "\n")
    }
}

// MARK: - ScanResult

/// Everything one scan pass produces. Extended in P2 with
/// `provenanceByPath` (items attributed to a plugin, keyed by resolved
/// path) and `enabledIdentities` (set of plugin identities the user has
/// enabled in Claude Code's settings.json). The first two fields remain
/// the P0 shape for view-layer consumers.
struct ScanResult {
    let items: [AIConfigItem]
    let categoryGroups: [AIConfigCategoryGroup]
    let lastScanDate: Date
    let provenanceByPath: [URL: PluginProvenance]
    let enabledIdentities: Set<PluginIdentity>

    init(
        items: [AIConfigItem],
        categoryGroups: [AIConfigCategoryGroup],
        lastScanDate: Date,
        provenanceByPath: [URL: PluginProvenance] = [:],
        enabledIdentities: Set<PluginIdentity> = []
    ) {
        self.items = items
        self.categoryGroups = categoryGroups
        self.lastScanDate = lastScanDate
        self.provenanceByPath = provenanceByPath
        self.enabledIdentities = enabledIdentities
    }

    static let empty = ScanResult(items: [], categoryGroups: [], lastScanDate: .distantPast)
}
