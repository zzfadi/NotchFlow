import Foundation
import Combine

@MainActor
class AIConfigScanner: ObservableObject {
    @Published var categoryGroups: [AIConfigCategoryGroup] = []
    @Published var allItems: [AIConfigItem] = []
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?
    @Published var errorMessage: String?

    private let settings = SettingsManager.shared
    private var scanTask: Task<Void, Never>?

    // MARK: - Public Methods

    func scan() {
        scanTask?.cancel()

        scanTask = Task {
            isScanning = true
            errorMessage = nil

            let items = await performScan()

            if !Task.isCancelled {
                allItems = items
                categoryGroups = groupItemsByCategory(items)
                lastScanDate = Date()
                isScanning = false
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    // MARK: - Private Scanning Methods

    private func performScan() async -> [AIConfigItem] {
        var items: [AIConfigItem] = []

        // 1. First scan global config locations (MCP configs, user settings)
        let globalItems = await scanGlobalConfigs()
        items.append(contentsOf: globalItems)

        // 2. Then scan project directories
        for pathString in settings.aiConfigScanPaths {
            let path = URL(fileURLWithPath: pathString)

            guard FileManager.default.fileExists(atPath: path.path) else {
                continue
            }

            let foundItems = await scanDirectory(path)
            items.append(contentsOf: foundItems)
        }

        // Remove duplicates
        var seen = Set<String>()
        items = items.filter { item in
            let key = item.path.path
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return items.sorted { $0.lastModified > $1.lastModified }
    }

    /// Scan global config locations (user-level configs)
    private func scanGlobalConfigs() async -> [AIConfigItem] {
        var items: [AIConfigItem] = []
        let fileManager = FileManager.default

        // Scan all known global config locations
        for (path, fileType) in GlobalConfigLocations.all {
            if fileManager.fileExists(atPath: path.path) {
                if let item = createConfigItem(
                    at: path,
                    fileType: fileType,
                    projectPath: path.deletingLastPathComponent(),
                    isGlobal: true
                ) {
                    items.append(item)
                }
            }
        }

        return items
    }

    private func scanDirectory(_ directory: URL) async -> [AIConfigItem] {
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

    private func scanSubdirectories(_ directory: URL, depth: Int, maxDepth: Int, items: inout [AIConfigItem]) async {
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
    private func scanGlobPatterns(_ directory: URL, items: inout [AIConfigItem]) async {
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
                for file in promptFiles where file.pathExtension == "md" && file.lastPathComponent.hasSuffix(".prompt.md") {
                    if let item = createConfigItem(at: file, fileType: .promptMd, projectPath: directory) {
                        items.append(item)
                    }
                }
            }
        }
    }

    private func shouldSkipDirectory(_ name: String) -> Bool {
        let skipDirs = [
            "node_modules",
            ".git",
            "build",
            "dist",
            "DerivedData",
            ".build",
            "Pods",
            "Carthage",
            ".Trash",
            "Library",
            "Applications",
            ".npm",
            ".cargo",
            ".rustup"
        ]
        return skipDirs.contains(name)
    }

    private func createConfigItem(
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
    private func extractYAMLFrontmatter(from path: URL) -> ConfigMetadata? {
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
            if line == "---" {
                if inFrontmatter { break }
                inFrontmatter = true
                continue
            }

            if inFrontmatter {
                if line.hasPrefix("name:") {
                    name = extractYAMLValue(from: line, key: "name")
                } else if line.hasPrefix("description:") {
                    description = extractYAMLValue(from: line, key: "description")
                } else if line.hasPrefix("version:") {
                    version = extractYAMLValue(from: line, key: "version")
                }
            }
        }

        if name != nil || description != nil || version != nil {
            return ConfigMetadata(name: name, description: description, version: version)
        }
        return nil
    }

    private func extractYAMLValue(from line: String, key: String) -> String? {
        let value = line
            .replacingOccurrences(of: "\(key):", with: "")
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        return value.isEmpty ? nil : value
    }

    private func groupItemsByCategory(_ items: [AIConfigItem]) -> [AIConfigCategoryGroup] {
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

    func previewContent(for item: AIConfigItem, maxLines: Int = 20) -> String? {
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

    private func previewDirectoryContent(_ path: URL) -> String? {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: []) else {
            return nil
        }

        let items = contents.map { $0.lastPathComponent }.sorted()
        return "Directory contents:\n" + items.map { "  - \($0)" }.joined(separator: "\n")
    }
}
