import Foundation
import Combine

@MainActor
class AIConfigScanner: ObservableObject {
    @Published var toolGroups: [AIToolGroup] = []
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
                toolGroups = groupItemsByTool(items)
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

    private func scanDirectory(_ directory: URL) async -> [AIConfigItem] {
        var items: [AIConfigItem] = []
        let fileManager = FileManager.default

        // Check for AI config files in this directory
        for fileType in AIConfigFileType.allCases {
            for pattern in fileType.patterns {
                let targetPath = directory.appendingPathComponent(pattern)

                if fileManager.fileExists(atPath: targetPath.path) {
                    if let item = createConfigItem(at: targetPath, fileType: fileType, projectPath: directory) {
                        items.append(item)
                    }
                }
            }
        }

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

            // Check for AI config files in this directory
            for fileType in AIConfigFileType.allCases {
                for pattern in fileType.patterns {
                    let targetPath = item.appendingPathComponent(pattern)

                    if fileManager.fileExists(atPath: targetPath.path) {
                        if let configItem = createConfigItem(at: targetPath, fileType: fileType, projectPath: item) {
                            items.append(configItem)
                        }
                    }
                }
            }

            // Recurse into subdirectory
            await scanSubdirectories(item, depth: depth + 1, maxDepth: maxDepth, items: &items)
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

    private func createConfigItem(at path: URL, fileType: AIConfigFileType, projectPath: URL) -> AIConfigItem? {
        let fileManager = FileManager.default

        guard let attrs = try? fileManager.attributesOfItem(atPath: path.path) else {
            return nil
        }

        let lastModified = attrs[.modificationDate] as? Date ?? Date()
        let fileSize = attrs[.size] as? Int64

        return AIConfigItem(
            path: path,
            fileType: fileType,
            projectPath: projectPath,
            lastModified: lastModified,
            fileSize: fileSize
        )
    }

    private func groupItemsByTool(_ items: [AIConfigItem]) -> [AIToolGroup] {
        var groups: [AIToolType: AIToolGroup] = [:]

        for item in items {
            let toolType = item.toolType
            if var group = groups[toolType] {
                group.items.append(item)
                groups[toolType] = group
            } else {
                groups[toolType] = AIToolGroup(toolType: toolType, items: [item])
            }
        }

        // Sort groups and items
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
