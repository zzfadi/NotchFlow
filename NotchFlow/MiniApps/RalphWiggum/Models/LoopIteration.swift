import Foundation

// MARK: - File Change

struct FileChange: Codable, Equatable, Identifiable {
    let id: UUID
    let path: String
    let changeType: ChangeType
    let linesAdded: Int
    let linesRemoved: Int

    init(
        id: UUID = UUID(),
        path: String,
        changeType: ChangeType,
        linesAdded: Int = 0,
        linesRemoved: Int = 0
    ) {
        self.id = id
        self.path = path
        self.changeType = changeType
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
    }

    enum ChangeType: String, Codable {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"

        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .deleted: return "minus.circle.fill"
            case .renamed: return "arrow.right.circle.fill"
            case .copied: return "doc.on.doc.fill"
            }
        }

        var colorName: String {
            switch self {
            case .added: return "green"
            case .modified: return "orange"
            case .deleted: return "red"
            case .renamed: return "purple"
            case .copied: return "blue"
            }
        }
    }

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }
}

// MARK: - Loop Iteration

struct LoopIteration: Identifiable, Codable, Equatable {
    let id: UUID
    let loopId: UUID
    let iterationNumber: Int
    let startedAt: Date
    var completedAt: Date?
    var exitCode: Int?
    var filesChanged: [FileChange]
    var semanticSummary: String?
    var gitCommitHash: String?
    var tokensUsed: Int?
    var estimatedCost: Double?
    var outputSnippet: String?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        loopId: UUID,
        iterationNumber: Int,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        exitCode: Int? = nil,
        filesChanged: [FileChange] = [],
        semanticSummary: String? = nil,
        gitCommitHash: String? = nil,
        tokensUsed: Int? = nil,
        estimatedCost: Double? = nil,
        outputSnippet: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.loopId = loopId
        self.iterationNumber = iterationNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exitCode = exitCode
        self.filesChanged = filesChanged
        self.semanticSummary = semanticSummary
        self.gitCommitHash = gitCommitHash
        self.tokensUsed = tokensUsed
        self.estimatedCost = estimatedCost
        self.outputSnippet = outputSnippet
        self.errorMessage = errorMessage
    }

    var isSuccess: Bool {
        exitCode == 0
    }

    var duration: TimeInterval? {
        guard let end = completedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "—" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "—"
    }

    var shortCommitHash: String? {
        gitCommitHash.map { String($0.prefix(7)) }
    }

    var formattedCost: String {
        guard let cost = estimatedCost else { return "—" }
        return String(format: "$%.3f", cost)
    }

    var totalLinesChanged: Int {
        filesChanged.reduce(0) { $0 + $1.linesAdded + $1.linesRemoved }
    }
}

// MARK: - Loop Event (for streaming updates)

enum LoopEvent {
    case iterationStarted(number: Int)
    case iterationCompleted(iteration: LoopIteration)
    case outputLine(String)
    case errorLine(String)
    case loopCompleted(reason: CompletionReason)
    case loopFailed(error: String)

    enum CompletionReason {
        case success
        case maxIterationsReached
        case userStopped
        case budgetExceeded
    }
}
