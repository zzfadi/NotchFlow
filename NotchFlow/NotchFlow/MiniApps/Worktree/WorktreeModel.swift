import Foundation

// MARK: - Git Status

enum GitFileStatus: String, CaseIterable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"

    var icon: String {
        switch self {
        case .modified: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        }
    }

    /// Returns the semantic color name for this status.
    /// Use with SwiftUI's Color initializer: Color(colorName)
    var colorName: String {
        switch self {
        case .modified: return "orange"
        case .added: return "green"
        case .deleted: return "red"
        case .renamed: return "purple"
        case .copied: return "blue"
        case .untracked: return "gray"
        case .ignored: return "gray"
        }
    }
}

struct GitStatusSummary: Equatable {
    var staged: Int = 0
    var modified: Int = 0
    var untracked: Int = 0
    var deleted: Int = 0
    var conflicted: Int = 0

    var isClean: Bool {
        staged == 0 && modified == 0 && untracked == 0 && deleted == 0 && conflicted == 0
    }

    var totalChanges: Int {
        staged + modified + untracked + deleted + conflicted
    }

    var summary: String {
        if isClean { return "Clean" }
        var parts: [String] = []
        if staged > 0 { parts.append("+\(staged)") }
        if modified > 0 { parts.append("~\(modified)") }
        if deleted > 0 { parts.append("-\(deleted)") }
        if untracked > 0 { parts.append("?\(untracked)") }
        if conflicted > 0 { parts.append("!\(conflicted)") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Remote Tracking

struct RemoteTrackingInfo: Equatable {
    let remoteName: String
    let remoteBranch: String
    let ahead: Int
    let behind: Int
    let lastFetch: Date?

    var needsPush: Bool { ahead > 0 }
    var needsPull: Bool { behind > 0 }
    var isSynced: Bool { ahead == 0 && behind == 0 }

    var summary: String {
        if isSynced { return "Synced" }
        var parts: [String] = []
        if ahead > 0 { parts.append("↑\(ahead)") }
        if behind > 0 { parts.append("↓\(behind)") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Worktree

struct Worktree: Identifiable, Equatable, Hashable {
    let id: UUID
    let path: URL
    let branch: String
    let lastModified: Date
    let parentRepo: URL
    let isMainWorktree: Bool
    let commitHash: String?
    let isDetached: Bool

    // Rich git status (populated async)
    var status: GitStatusSummary?
    var remoteTracking: RemoteTrackingInfo?
    var recentCommits: [CommitInfo]?
    var stashCount: Int?

    init(
        id: UUID = UUID(),
        path: URL,
        branch: String,
        lastModified: Date,
        parentRepo: URL,
        isMainWorktree: Bool = false,
        commitHash: String? = nil,
        isDetached: Bool = false,
        status: GitStatusSummary? = nil,
        remoteTracking: RemoteTrackingInfo? = nil,
        recentCommits: [CommitInfo]? = nil,
        stashCount: Int? = nil
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.lastModified = lastModified
        self.parentRepo = parentRepo
        self.isMainWorktree = isMainWorktree
        self.commitHash = commitHash
        self.isDetached = isDetached
        self.status = status
        self.remoteTracking = remoteTracking
        self.recentCommits = recentCommits
        self.stashCount = stashCount
    }

    var displayName: String {
        path.lastPathComponent
    }

    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathString = path.path
        if pathString.hasPrefix(home) {
            return "~" + pathString.dropFirst(home.count)
        }
        return pathString
    }

    var parentRepoName: String {
        parentRepo.lastPathComponent
    }

    var branchDisplayName: String {
        if isDetached {
            return "HEAD detached at \(commitHash?.prefix(7) ?? "unknown")"
        }
        return branch
    }

    var shortCommitHash: String? {
        commitHash.map { String($0.prefix(7)) }
    }

    /// SF Symbol name representing the current status.
    /// Returns appropriate symbol for unknown, clean, conflicted, or dirty states.
    var statusIndicatorSymbol: String {
        guard let status = status else { return "circle" }
        if status.isClean { return "checkmark.circle.fill" }
        if status.conflicted > 0 { return "exclamationmark.triangle.fill" }
        return "pencil.circle.fill"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equality is based solely on id for performance and to support collection operations.
    /// The rich status fields (status, remoteTracking, etc.) are populated asynchronously
    /// and change frequently, but the worktree identity remains the same.
    /// This allows SwiftUI to efficiently diff collections without re-fetching status.
    static func == (lhs: Worktree, rhs: Worktree) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Commit Info

struct CommitInfo: Identifiable, Equatable {
    let id: String // commit hash
    let shortHash: String
    let message: String
    let author: String
    let date: Date
    let isHead: Bool

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Repository Group

struct RepositoryGroup: Identifiable {
    let id: UUID
    let repoPath: URL
    var worktrees: [Worktree]

    init(id: UUID = UUID(), repoPath: URL, worktrees: [Worktree] = []) {
        self.id = id
        self.repoPath = repoPath
        self.worktrees = worktrees
    }

    var name: String {
        repoPath.lastPathComponent
    }

    var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathString = repoPath.path
        if pathString.hasPrefix(home) {
            return "~" + pathString.dropFirst(home.count)
        }
        return pathString
    }

    var mainWorktree: Worktree? {
        worktrees.first { $0.isMainWorktree }
    }

    var linkedWorktrees: [Worktree] {
        worktrees.filter { !$0.isMainWorktree }
    }

    var totalChanges: Int {
        worktrees.compactMap { $0.status?.totalChanges }.reduce(0, +)
    }

    var hasUnpushedChanges: Bool {
        worktrees.contains { $0.remoteTracking?.needsPush == true }
    }
}

// MARK: - Worktree Relationship (for visualization)

struct WorktreeRelationship: Identifiable {
    let id = UUID()
    let mainWorktree: Worktree
    let linkedWorktrees: [Worktree]
    let commonAncestor: String? // commit hash where branches diverged

    var branchNames: [String] {
        [mainWorktree.branch] + linkedWorktrees.map { $0.branch }
    }
}
