import Foundation

// MARK: - AI Config Category (Primary Filter)

enum AIConfigCategory: String, CaseIterable, Identifiable, Codable {
    case rules = "Rules"
    case skills = "Skills"
    case promptFiles = "Prompts"
    case customAgents = "Agents"
    case mcpConfigs = "MCP"
    case hooks = "Hooks"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .rules: return "doc.text.fill"
        case .skills: return "star.fill"
        case .promptFiles: return "text.bubble.fill"
        case .customAgents: return "person.2.fill"
        case .mcpConfigs: return "server.rack"
        case .hooks: return "link.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: String {
        switch self {
        case .rules: return "FF6B35"       // Orange
        case .skills: return "FFD700"      // Gold
        case .promptFiles: return "7C3AED" // Purple
        case .customAgents: return "EC4899" // Pink
        case .mcpConfigs: return "06B6D4"  // Cyan
        case .hooks: return "10B981"       // Green
        case .settings: return "8B5CF6"    // Violet
        }
    }

    var description: String {
        switch self {
        case .rules: return "Project rules, instructions, and guidelines"
        case .skills: return "Reusable skill definitions"
        case .promptFiles: return "Prompt templates and directories"
        case .customAgents: return "Custom agent/subagent definitions"
        case .mcpConfigs: return "Model Context Protocol server configurations"
        case .hooks: return "Lifecycle hooks and event handlers"
        case .settings: return "Tool settings and configurations"
        }
    }
}

// MARK: - AI Provider (Secondary Detail)

enum AIProvider: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case copilot = "GitHub Copilot"
    case cursor = "Cursor"
    case vscode = "VS Code"
    case generic = "Cross-Platform"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claude: return "c.circle.fill"
        case .copilot: return "airplane"
        case .cursor: return "cursorarrow.rays"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .generic: return "globe"
        }
    }

    var compactName: String {
        switch self {
        case .claude: return "Claude"
        case .copilot: return "Copilot"
        case .cursor: return "Cursor"
        case .vscode: return "VS Code"
        case .generic: return "Generic"
        }
    }

    var color: String {
        switch self {
        case .claude: return "FF6B35"
        case .copilot: return "238636"
        case .cursor: return "7C3AED"
        case .vscode: return "007ACC"
        case .generic: return "6B7280"
        }
    }
}

// MARK: - Config Metadata

struct ConfigMetadata: Equatable, Hashable {
    let name: String?
    let description: String?
    let version: String?

    init(name: String? = nil, description: String? = nil, version: String? = nil) {
        self.name = name
        self.description = description
        self.version = version
    }
}

// MARK: - AI Config File Type
// Based on official documentation as of January 2026:
// - Claude: CLAUDE.md, .claude/, settings.json, skills
// - Cursor: .cursorrules (legacy), .cursor/*.mdc (modern), .cursor/mcp.json
// - Copilot: .github/copilot-instructions.md, .github/prompts/*.prompt.md
// - VS Code: .vscode/mcp.json
// - Cross-platform: AGENTS.md, mcp.json
// Note: This is a macOS-only app, so paths use macOS conventions.

enum AIConfigFileType: String, CaseIterable, Identifiable {
    // ═══════════════════════════════════════════════════════════════════════
    // RULES - Project instructions and guidelines
    // ═══════════════════════════════════════════════════════════════════════

    /// AGENTS.md - Cross-platform standard (Cursor, Zed, OpenCode, etc.)
    case agentsMd = "AGENTS.md"

    /// CLAUDE.md - Claude Code specific rules (project root)
    case claudeMd = "CLAUDE.md"

    /// .github/copilot-instructions.md - GitHub Copilot repo-level instructions
    case copilotInstructions = "copilot-instructions.md"

    /// .cursorrules - Cursor legacy rules (deprecated but still works)
    case cursorRules = ".cursorrules"

    /// .cursor/*.mdc - Cursor modern rules (MDC format)
    case cursorMdcFile = ".mdc"

    /// *.instructions.md - VS Code Copilot file-specific instructions
    case instructionsMd = ".instructions.md"

    // ═══════════════════════════════════════════════════════════════════════
    // SKILLS - Reusable skill definitions
    // ═══════════════════════════════════════════════════════════════════════

    /// SKILL.md - Claude skill definition with YAML frontmatter
    case skillMd = "SKILL.md"

    // ═══════════════════════════════════════════════════════════════════════
    // PROMPTS - Prompt templates and files
    // ═══════════════════════════════════════════════════════════════════════

    /// *.prompt.md - Reusable prompt files
    case promptMd = ".prompt.md"

    /// .github/prompts/ - GitHub Copilot prompts directory
    case copilotPromptsDir = ".github/prompts"

    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOM AGENTS - Agent definitions
    // ═══════════════════════════════════════════════════════════════════════

    /// agent.yaml/agent.yml - Custom agent configuration
    case customAgentYaml = "agent.yaml"

    // ═══════════════════════════════════════════════════════════════════════
    // MCP CONFIGS - Model Context Protocol server configurations
    // ═══════════════════════════════════════════════════════════════════════

    /// claude_desktop_config.json - Claude Desktop MCP config
    /// Location: ~/Library/Application Support/Claude/claude_desktop_config.json
    case claudeDesktopMcp = "claude_desktop_config.json"

    /// .vscode/mcp.json - VS Code workspace MCP config
    case vscodeMcpJson = ".vscode/mcp.json"

    /// VS Code User MCP - ~/Library/Application Support/Code/User/mcp.json
    case vscodeUserMcp = "Code/User/mcp.json"

    /// .cursor/mcp.json - Cursor project-level MCP config
    case cursorMcpJson = ".cursor/mcp.json"

    /// ~/.cursor/mcp.json - Cursor user-level MCP config
    case cursorUserMcp = "~/.cursor/mcp.json"

    /// .mcp.json - Project root MCP config (Claude Code)
    case mcpJson = ".mcp.json"

    // ═══════════════════════════════════════════════════════════════════════
    // HOOKS - Lifecycle hooks
    // ═══════════════════════════════════════════════════════════════════════

    /// .claude/settings.json with hooks - Claude Code hooks configuration
    case claudeHooks = ".claude/settings.json"

    // ═══════════════════════════════════════════════════════════════════════
    // SETTINGS - Tool settings directories
    // ═══════════════════════════════════════════════════════════════════════

    /// .claude/ directory - Claude Code project settings
    case claudeDir = ".claude"

    /// .cursor/ directory - Cursor project settings
    case cursorDir = ".cursor"

    var id: String { rawValue }

    var category: AIConfigCategory {
        switch self {
        case .agentsMd, .claudeMd, .copilotInstructions, .cursorRules,
             .cursorMdcFile, .instructionsMd:
            return .rules
        case .skillMd:
            return .skills
        case .promptMd, .copilotPromptsDir:
            return .promptFiles
        case .customAgentYaml:
            return .customAgents
        case .claudeDesktopMcp, .vscodeMcpJson, .vscodeUserMcp,
             .cursorMcpJson, .cursorUserMcp, .mcpJson:
            return .mcpConfigs
        case .claudeHooks:
            return .hooks
        case .claudeDir, .cursorDir:
            return .settings
        }
    }

    var provider: AIProvider {
        switch self {
        case .claudeMd, .claudeDir, .claudeHooks, .skillMd, .claudeDesktopMcp, .mcpJson:
            return .claude
        case .copilotInstructions, .copilotPromptsDir:
            return .copilot
        case .cursorRules, .cursorMdcFile, .cursorDir, .cursorMcpJson, .cursorUserMcp:
            return .cursor
        case .vscodeMcpJson, .vscodeUserMcp, .instructionsMd:
            return .vscode
        case .agentsMd, .promptMd, .customAgentYaml:
            return .generic
        }
    }

    var displayName: String {
        switch self {
        case .agentsMd: return "AGENTS.md"
        case .claudeMd: return "CLAUDE.md"
        case .copilotInstructions: return "Copilot Instructions"
        case .cursorRules: return ".cursorrules"
        case .cursorMdcFile: return "Cursor Rule"
        case .instructionsMd: return "Instructions"
        case .skillMd: return "SKILL.md"
        case .promptMd: return "Prompt"
        case .copilotPromptsDir: return "Copilot Prompts"
        case .customAgentYaml: return "Agent Config"
        case .claudeDesktopMcp: return "Claude Desktop MCP"
        case .vscodeMcpJson: return "VS Code MCP"
        case .vscodeUserMcp: return "VS Code User MCP"
        case .cursorMcpJson: return "Cursor MCP"
        case .cursorUserMcp: return "Cursor User MCP"
        case .mcpJson: return "MCP Config"
        case .claudeHooks: return "Claude Hooks"
        case .claudeDir: return ".claude"
        case .cursorDir: return ".cursor"
        }
    }

    /// Patterns to match in project directories
    var patterns: [String] {
        switch self {
        case .agentsMd: return ["AGENTS.md"]
        case .claudeMd: return ["CLAUDE.md"]
        case .copilotInstructions: return [".github/copilot-instructions.md"]
        case .cursorRules: return [".cursorrules"]
        case .cursorMdcFile: return []  // Glob: .cursor/*.mdc
        case .instructionsMd: return [] // Glob: *.instructions.md
        case .skillMd: return ["SKILL.md"]
        case .promptMd: return []  // Glob: *.prompt.md
        case .copilotPromptsDir: return [".github/prompts"]
        case .customAgentYaml: return ["agent.yaml", "agent.yml"]
        case .claudeDesktopMcp: return [] // Global location only
        case .vscodeMcpJson: return [".vscode/mcp.json"]
        case .vscodeUserMcp: return [] // Global location only
        case .cursorMcpJson: return [".cursor/mcp.json"]
        case .cursorUserMcp: return [] // Global location only
        case .mcpJson: return [".mcp.json"]  // Claude Code project MCP config
        case .claudeHooks: return [".claude/settings.json"]
        case .claudeDir: return [".claude"]
        case .cursorDir: return [".cursor"]
        }
    }

    var isDirectory: Bool {
        switch self {
        case .copilotPromptsDir, .claudeDir, .cursorDir:
            return true
        default:
            return false
        }
    }

    /// Whether this type requires glob pattern matching
    var isGlobPattern: Bool {
        switch self {
        case .cursorMdcFile, .promptMd, .instructionsMd:
            return true
        default:
            return false
        }
    }

    /// Whether this is a global (user-level) config, not project-level
    var isGlobalConfig: Bool {
        switch self {
        case .claudeDesktopMcp, .vscodeUserMcp, .cursorUserMcp:
            return true
        default:
            return false
        }
    }
}

// MARK: - Global Config Locations

struct GlobalConfigLocations {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    /// Claude Desktop MCP config
    static var claudeDesktopMcp: URL {
        home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
    }

    /// VS Code User MCP config
    static var vscodeUserMcp: URL {
        home.appendingPathComponent("Library/Application Support/Code/User/mcp.json")
    }

    /// VS Code Insiders User MCP config
    static var vscodeInsidersUserMcp: URL {
        home.appendingPathComponent("Library/Application Support/Code - Insiders/User/mcp.json")
    }

    /// Cursor User MCP config
    static var cursorUserMcp: URL {
        home.appendingPathComponent(".cursor/mcp.json")
    }

    /// All global config locations to scan
    /// Note: ~/.claude/settings.json and ~/.claude/CLAUDE.md are handled via project scanning
    static var all: [(URL, AIConfigFileType)] {
        [
            (claudeDesktopMcp, .claudeDesktopMcp),
            (vscodeUserMcp, .vscodeUserMcp),
            (vscodeInsidersUserMcp, .vscodeUserMcp),
            (cursorUserMcp, .cursorUserMcp),
        ]
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
    let metadata: ConfigMetadata?
    let isGlobal: Bool
    /// P2: when a file was placed by a plugin install (Claude Code
    /// plugin, Cursor plugin, or an awesome-copilot sidecar), this
    /// captures the identity + scope. `nil` for hand-written configs.
    let sourcePlugin: PluginProvenance?

    init(
        id: UUID = UUID(),
        path: URL,
        fileType: AIConfigFileType,
        projectPath: URL,
        lastModified: Date = Date(),
        fileSize: Int64? = nil,
        metadata: ConfigMetadata? = nil,
        isGlobal: Bool = false,
        sourcePlugin: PluginProvenance? = nil
    ) {
        self.id = id
        self.path = path
        self.fileType = fileType
        self.projectPath = projectPath
        self.lastModified = lastModified
        self.fileSize = fileSize
        self.metadata = metadata
        self.isGlobal = isGlobal
        self.sourcePlugin = sourcePlugin
    }

    var category: AIConfigCategory {
        fileType.category
    }

    var provider: AIProvider {
        fileType.provider
    }

    var displayName: String {
        // For skills with metadata, show the skill name
        if let metadata = metadata, let name = metadata.name, !name.isEmpty {
            return name
        }
        // For glob-matched files, show the actual filename
        if fileType.isGlobPattern {
            return path.lastPathComponent
        }
        return fileType.displayName
    }

    var projectName: String {
        if isGlobal {
            return "Global"
        }
        return projectPath.lastPathComponent
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

// MARK: - Category Group

struct AIConfigCategoryGroup: Identifiable {
    let id: UUID
    let category: AIConfigCategory
    var items: [AIConfigItem]

    init(id: UUID = UUID(), category: AIConfigCategory, items: [AIConfigItem] = []) {
        self.id = id
        self.category = category
        self.items = items
    }

    var name: String { category.rawValue }
    var icon: String { category.icon }
    var color: String { category.color }

    /// Group items by provider for secondary filtering
    var itemsByProvider: [AIProvider: [AIConfigItem]] {
        Dictionary(grouping: items, by: { $0.provider })
    }

    /// Providers present in this category, sorted by item count (descending), then by name for consistency
    var providers: [AIProvider] {
        itemsByProvider.keys.sorted { provider1, provider2 in
            let count1 = itemsByProvider[provider1]?.count ?? 0
            let count2 = itemsByProvider[provider2]?.count ?? 0
            if count1 != count2 {
                return count1 > count2
            }
            return provider1.rawValue < provider2.rawValue
        }
    }
}

// MARK: - Legacy Compatibility (Deprecated)

@available(*, deprecated, renamed: "AIProvider")
typealias AIToolType = AIProvider

@available(*, deprecated, renamed: "AIConfigCategoryGroup")
typealias AIToolGroup = AIConfigCategoryGroup
