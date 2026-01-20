import Foundation

// MARK: - Loop Status

enum LoopStatus: String, Codable, CaseIterable {
    case idle
    case running
    case paused
    case completed
    case failed

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var isActive: Bool {
        self == .running || self == .paused
    }
}

// MARK: - Ralph Loop

struct RalphLoop: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var projectPath: URL
    var promptPath: URL
    var cliTool: String
    var cliArguments: [String]
    var maxIterations: Int?
    var status: LoopStatus
    var currentIteration: Int
    var createdAt: Date
    var lastRunAt: Date?
    var completedAt: Date?
    var totalTokensUsed: Int
    var totalEstimatedCost: Double

    init(
        id: UUID = UUID(),
        name: String,
        projectPath: URL,
        promptPath: URL,
        cliTool: String = "claude",
        cliArguments: [String] = [],
        maxIterations: Int? = 50,
        status: LoopStatus = .idle,
        currentIteration: Int = 0,
        createdAt: Date = Date(),
        lastRunAt: Date? = nil,
        completedAt: Date? = nil,
        totalTokensUsed: Int = 0,
        totalEstimatedCost: Double = 0
    ) {
        self.id = id
        self.name = name
        self.projectPath = projectPath
        self.promptPath = promptPath
        self.cliTool = cliTool
        self.cliArguments = cliArguments
        self.maxIterations = maxIterations
        self.status = status
        self.currentIteration = currentIteration
        self.createdAt = createdAt
        self.lastRunAt = lastRunAt
        self.completedAt = completedAt
        self.totalTokensUsed = totalTokensUsed
        self.totalEstimatedCost = totalEstimatedCost
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathString = projectPath.path
        if pathString.hasPrefix(home) {
            return "~" + pathString.dropFirst(home.count)
        }
        return pathString
    }

    var progressPercentage: Double? {
        guard let max = maxIterations, max > 0 else { return nil }
        return Double(currentIteration) / Double(max)
    }

    var formattedCost: String {
        String(format: "$%.2f", totalEstimatedCost)
    }

    var duration: TimeInterval? {
        guard let start = lastRunAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }
}

// MARK: - Copilot CLI Configuration

struct CopilotConfig: Codable, Equatable {
    var model: CopilotModel = .gpt52Codex
    var allowAllTools: Bool = true
    var allowAllPaths: Bool = true
    var noAskUser: Bool = true  // Agent works autonomously
    var additionalArgs: [String] = []

    var commandArguments: [String] {
        var args: [String] = []

        args.append("--model")
        args.append(model.rawValue)

        if allowAllTools {
            args.append("--allow-all-tools")
        }

        if allowAllPaths {
            args.append("--allow-all-paths")
        }

        if noAskUser {
            args.append("--no-ask-user")
        }

        args.append(contentsOf: additionalArgs)

        return args
    }

    enum CopilotModel: String, Codable, CaseIterable, Identifiable {
        case claudeSonnet45 = "claude-sonnet-4.5"
        case claudeHaiku45 = "claude-haiku-4.5"
        case claudeOpus45 = "claude-opus-4.5"
        case claudeSonnet4 = "claude-sonnet-4"
        case gpt52Codex = "gpt-5.2-codex"
        case gpt51CodexMax = "gpt-5.1-codex-max"
        case gpt51Codex = "gpt-5.1-codex"
        case gpt52 = "gpt-5.2"
        case gpt51 = "gpt-5.1"
        case gpt5 = "gpt-5"
        case gpt51CodexMini = "gpt-5.1-codex-mini"
        case gpt5Mini = "gpt-5-mini"
        case gpt41 = "gpt-4.1"
        case gemini3Pro = "gemini-3-pro-preview"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .claudeSonnet45: return "Claude Sonnet 4.5"
            case .claudeHaiku45: return "Claude Haiku 4.5"
            case .claudeOpus45: return "Claude Opus 4.5"
            case .claudeSonnet4: return "Claude Sonnet 4"
            case .gpt52Codex: return "GPT-5.2 Codex"
            case .gpt51CodexMax: return "GPT-5.1 Codex Max"
            case .gpt51Codex: return "GPT-5.1 Codex"
            case .gpt52: return "GPT-5.2"
            case .gpt51: return "GPT-5.1"
            case .gpt5: return "GPT-5"
            case .gpt51CodexMini: return "GPT-5.1 Codex Mini"
            case .gpt5Mini: return "GPT-5 Mini"
            case .gpt41: return "GPT-4.1"
            case .gemini3Pro: return "Gemini 3 Pro"
            }
        }

        var isCodex: Bool {
            rawValue.contains("codex")
        }
    }

    static let `default` = CopilotConfig()
}

// MARK: - CLI Tool (simplified for now - Copilot focused)

enum CLITool: String, CaseIterable, Identifiable {
    case copilot = "copilot"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .copilot: return "GitHub Copilot CLI"
        }
    }

    var command: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .copilot: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
