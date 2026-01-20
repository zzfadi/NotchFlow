import Foundation

// MARK: - AI Tool Type

enum AIToolType: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case copilot = "GitHub Copilot"
    case cursor = "Cursor"
    case mcp = "MCP"
    case generic = "Generic AI"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claude: return "c.circle.fill"
        case .copilot: return "airplane"
        case .cursor: return "cursorarrow.rays"
        case .mcp: return "server.rack"
        case .generic: return "brain"
        }
    }

    var color: String {
        switch self {
        case .claude: return "FF6B35"
        case .copilot: return "238636"
        case .cursor: return "7C3AED"
        case .mcp: return "06B6D4"
        case .generic: return "EC4899"
        }
    }
}

// MARK: - AI Config File Type

enum AIConfigFileType: String, CaseIterable, Identifiable {
    case agentsMd = "AGENTS.md"
    case claudeMd = "CLAUDE.md"
    case claudeDir = ".claude"
    case copilotPrompts = ".github/prompts"
    case cursorDir = ".cursor"
    case cursorRules = ".cursorrules"
    case mcpJson = "mcp.json"
    case mcpDir = ".mcp"
    case promptsDir = ".prompts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agentsMd: return "AGENTS.md"
        case .claudeMd: return "CLAUDE.md"
        case .claudeDir: return ".claude directory"
        case .copilotPrompts: return "Copilot Prompts"
        case .cursorDir: return ".cursor directory"
        case .cursorRules: return ".cursorrules"
        case .mcpJson: return "MCP Config"
        case .mcpDir: return ".mcp directory"
        case .promptsDir: return "Prompts directory"
        }
    }

    var toolType: AIToolType {
        switch self {
        case .agentsMd: return .generic
        case .claudeMd, .claudeDir: return .claude
        case .copilotPrompts: return .copilot
        case .cursorDir, .cursorRules: return .cursor
        case .mcpJson, .mcpDir: return .mcp
        case .promptsDir: return .generic
        }
    }

    var patterns: [String] {
        switch self {
        case .agentsMd: return ["AGENTS.md"]
        case .claudeMd: return ["CLAUDE.md"]
        case .claudeDir: return [".claude"]
        case .copilotPrompts: return [".github/prompts"]
        case .cursorDir: return [".cursor"]
        case .cursorRules: return [".cursorrules"]
        case .mcpJson: return ["mcp.json", ".mcp.json"]
        case .mcpDir: return [".mcp"]
        case .promptsDir: return [".prompts", "prompts"]
        }
    }

    var isDirectory: Bool {
        switch self {
        case .claudeDir, .copilotPrompts, .cursorDir, .mcpDir, .promptsDir:
            return true
        default:
            return false
        }
    }
}

// MARK: - AI Config Item

struct AIConfigItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let path: URL
    let fileType: AIConfigFileType
    let projectPath: URL
    let lastModified: Date
    let fileSize: Int64?

    init(
        id: UUID = UUID(),
        path: URL,
        fileType: AIConfigFileType,
        projectPath: URL,
        lastModified: Date = Date(),
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.path = path
        self.fileType = fileType
        self.projectPath = projectPath
        self.lastModified = lastModified
        self.fileSize = fileSize
    }

    var displayName: String {
        fileType.displayName
    }

    var toolType: AIToolType {
        fileType.toolType
    }

    var projectName: String {
        projectPath.lastPathComponent
    }

    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathString = path.path
        if pathString.hasPrefix(home) {
            return "~" + pathString.dropFirst(home.count)
        }
        return pathString
    }

    var shortProjectPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathString = projectPath.path
        if pathString.hasPrefix(home) {
            return "~" + pathString.dropFirst(home.count)
        }
        return pathString
    }

    var isDirectory: Bool {
        fileType.isDirectory
    }

    var fileSizeFormatted: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tool Group

struct AIToolGroup: Identifiable {
    let id: UUID
    let toolType: AIToolType
    var items: [AIConfigItem]

    init(id: UUID = UUID(), toolType: AIToolType, items: [AIConfigItem] = []) {
        self.id = id
        self.toolType = toolType
        self.items = items
    }

    var name: String {
        toolType.rawValue
    }
}
