import Foundation
import SwiftUI

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

// MARK: - Cleanup Types

/// Indicates how safe a worktree is to clean up
enum CleanupStatus: Equatable {
    /// Branch merged, clean working tree, no stashes - safe to remove
    case safe
    /// Branch merged but has warnings (uncommitted changes, stashes, unpushed commits, recent activity, etc.)
    case merged
    /// Branch not merged to main - may have unmerged work
    case unmerged
    /// Main worktree or protected branch - cannot be removed
    case protected
    /// Status not yet determined or git commands failed
    case unknown

    var displayName: String {
        switch self {
        case .safe: return "Safe to Remove"
        case .merged: return "Merged"
        case .unmerged: return "Unmerged"
        case .protected: return "Protected"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .merged: return "arrow.triangle.merge"
        case .unmerged: return "arrow.triangle.branch"
        case .protected: return "lock.shield.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .merged: return .orange
        case .unmerged: return .gray
        case .protected: return .blue
        case .unknown: return .gray
        }
    }
}

extension CleanupStatus: Comparable {
    private var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .merged: return 1
        case .unmerged: return 2
        case .unknown: return 3
        case .protected: return 4
        }
    }

    static func < (lhs: CleanupStatus, rhs: CleanupStatus) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Information about branch merge status relative to main
struct MergeInfo: Equatable {
    let isMergedToMain: Bool
    let mainBranch: String
    let commitsAheadOfMain: Int
    let remoteBranchExists: Bool
    let lastCommitDate: Date?
    let mergedAt: Date?

    var mergeStatusDescription: String {
        if isMergedToMain {
            if let mergedAt = mergedAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Merged \(formatter.localizedString(for: mergedAt, relativeTo: Date()))"
            }
            return "Merged to \(mainBranch)"
        } else {
            if commitsAheadOfMain > 0 {
                return "\(commitsAheadOfMain) commit\(commitsAheadOfMain == 1 ? "" : "s") ahead of \(mainBranch)"
            }
            return "Not merged to \(mainBranch)"
        }
    }
}

/// Warnings that should be shown before cleaning up a worktree
enum CleanupWarning: Equatable, Identifiable {
    case uncommittedChanges(count: Int)
    case unpushedCommits(count: Int)
    case stashesPresent(count: Int)
    case recentActivity(days: Int)
    case remoteBranchStillExists

    var id: String {
        switch self {
        case .uncommittedChanges: return "uncommitted"
        case .unpushedCommits: return "unpushed"
        case .stashesPresent: return "stashes"
        case .recentActivity: return "recent"
        case .remoteBranchStillExists: return "remote"
        }
    }

    var icon: String {
        switch self {
        case .uncommittedChanges: return "pencil.circle.fill"
        case .unpushedCommits: return "arrow.up.circle.fill"
        case .stashesPresent: return "tray.full.fill"
        case .recentActivity: return "clock.fill"
        case .remoteBranchStillExists: return "cloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .uncommittedChanges: return .orange
        case .unpushedCommits: return .red
        case .stashesPresent: return .purple
        case .recentActivity: return .blue
        case .remoteBranchStillExists: return .cyan
        }
    }

    var message: String {
        switch self {
        case .uncommittedChanges(let count):
            return "\(count) uncommitted change\(count == 1 ? "" : "s")"
        case .unpushedCommits(let count):
            return "\(count) unpushed commit\(count == 1 ? "" : "s")"
        case .stashesPresent(let count):
            return "\(count) stash\(count == 1 ? "" : "es") present"
        case .recentActivity(let days):
            return days == 0 ? "Active today" : "Active \(days) day\(days == 1 ? "" : "s") ago"
        case .remoteBranchStillExists:
            return "Remote branch still exists"
        }
    }

    var severity: Int {
        switch self {
        case .uncommittedChanges: return 3
        case .unpushedCommits: return 4
        case .stashesPresent: return 2
        case .recentActivity: return 1
        case .remoteBranchStillExists: return 1
        }
    }
}

/// A worktree that is a candidate for cleanup
struct CleanupCandidate: Identifiable, Equatable {
    let id: UUID
    let worktree: Worktree
    let cleanupStatus: CleanupStatus
    let mergeInfo: MergeInfo?
    let diskSize: UInt64?
    let warnings: [CleanupWarning]

    init(
        id: UUID = UUID(),
        worktree: Worktree,
        cleanupStatus: CleanupStatus,
        mergeInfo: MergeInfo? = nil,
        diskSize: UInt64? = nil,
        warnings: [CleanupWarning] = []
    ) {
        self.id = id
        self.worktree = worktree
        self.cleanupStatus = cleanupStatus
        self.mergeInfo = mergeInfo
        self.diskSize = diskSize
        self.warnings = warnings
    }

    var isSafeToRemove: Bool {
        cleanupStatus == .safe
    }

    var hasWarnings: Bool {
        !warnings.isEmpty
    }

    var highestSeverityWarning: CleanupWarning? {
        warnings.max(by: { $0.severity < $1.severity })
    }

    var formattedDiskSize: String {
        guard let size = diskSize else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        // Use clamping to prevent overflow for sizes > Int64.max
        return formatter.string(fromByteCount: Int64(clamping: size))
    }

    static func == (lhs: CleanupCandidate, rhs: CleanupCandidate) -> Bool {
        lhs.id == rhs.id &&
        lhs.worktree.id == rhs.worktree.id &&
        lhs.cleanupStatus == rhs.cleanupStatus &&
        lhs.mergeInfo == rhs.mergeInfo &&
        lhs.diskSize == rhs.diskSize &&
        lhs.warnings == rhs.warnings
    }
}

/// Result of a cleanup operation for a single worktree
struct CleanupResult: Identifiable, Equatable {
    let id: UUID
    let worktree: Worktree
    let outcome: Outcome

    /// Outcome of the cleanup operation - either success or failure
    enum Outcome: Equatable {
        case success(deletedBranch: Bool, branchDeletionError: String?)
        case failure(error: String)
    }

    // Computed properties for backward compatibility
    var success: Bool {
        if case .success = outcome { return true }
        return false
    }

    var error: String? {
        if case .failure(let error) = outcome { return error }
        return nil
    }

    var deletedBranch: Bool {
        if case .success(let deleted, _) = outcome { return deleted }
        return false
    }

    var branchDeletionError: String? {
        if case .success(_, let error) = outcome { return error }
        return nil
    }

    init(
        id: UUID = UUID(),
        worktree: Worktree,
        success: Bool,
        error: String? = nil,
        deletedBranch: Bool = false,
        branchDeletionError: String? = nil
    ) {
        self.id = id
        self.worktree = worktree
        if success {
            self.outcome = .success(deletedBranch: deletedBranch, branchDeletionError: branchDeletionError)
        } else {
            self.outcome = .failure(error: error ?? "Unknown error")
        }
    }
}
