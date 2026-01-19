import Foundation

struct Worktree: Identifiable, Equatable, Hashable {
    let id: UUID
    let path: URL
    let branch: String
    let lastModified: Date
    let parentRepo: URL
    let isMainWorktree: Bool
    let commitHash: String?
    let isDetached: Bool

    init(
        id: UUID = UUID(),
        path: URL,
        branch: String,
        lastModified: Date,
        parentRepo: URL,
        isMainWorktree: Bool = false,
        commitHash: String? = nil,
        isDetached: Bool = false
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.lastModified = lastModified
        self.parentRepo = parentRepo
        self.isMainWorktree = isMainWorktree
        self.commitHash = commitHash
        self.isDetached = isDetached
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
}
