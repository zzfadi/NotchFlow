import Foundation
import Subprocess

/// Utility for running git commands and parsing their output
actor GitCommandRunner {
    static let shared = GitCommandRunner()

    private init() {}

    // MARK: - Command Execution

    func run(_ arguments: [String], in directory: URL) async -> Result<String, GitError> {
        // Check for cancellation before starting
        if Task.isCancelled {
            return .failure(.commandFailed("Task cancelled"))
        }

        do {
            let result = try await Subprocess.run(
                .path("/usr/bin/git"),
                arguments: Arguments(arguments),
                workingDirectory: .init(directory.path),
                output: .string(limit: 1024 * 1024),  // 1MB limit
                error: .string(limit: 64 * 1024)      // 64KB for errors
            )

            if result.terminationStatus.isSuccess {
                let output = result.standardOutput ?? ""
                return .success(output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            } else {
                let errorMessage = result.standardError ?? "Unknown error"
                return .failure(.commandFailed(errorMessage.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)))
            }
        } catch {
            return .failure(.executionFailed(error.localizedDescription))
        }
    }

    // MARK: - Git Status

    func getStatus(for worktreePath: URL) async -> Result<GitStatusSummary, GitError> {
        let result = await run(["status", "--porcelain=v1"], in: worktreePath)

        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            var summary = GitStatusSummary()

            for line in output.components(separatedBy: "\n") where line.count >= 2 {
                let index = line.index(line.startIndex, offsetBy: 2)
                let statusCode = String(line.prefix(upTo: index))

                // Parse status codes (XY format where X=staging, Y=working tree)
                let x = statusCode.first ?? " "
                let y = statusCode.dropFirst().first ?? " "

                // Count conflicts
                if x == "U" || y == "U" || (x == "A" && y == "A") || (x == "D" && y == "D") {
                    summary.conflicted += 1
                    continue
                }

                // Staged changes (index)
                if x != " " && x != "?" {
                    summary.staged += 1
                }

                // Working tree changes
                switch y {
                case "M": summary.modified += 1
                case "D": summary.deleted += 1
                case "?": summary.untracked += 1
                default: break
                }
            }

            return .success(summary)
        }
    }

    // MARK: - Remote Tracking

    func getRemoteTracking(for worktreePath: URL, branch: String) async -> RemoteTrackingInfo? {
        // Get upstream branch
        let upstreamResult = await run(
            ["rev-parse", "--abbrev-ref", "\(branch)@{upstream}"],
            in: worktreePath
        )

        guard case .success(let upstream) = upstreamResult else {
            return nil
        }

        let parts = upstream.split(separator: "/", maxSplits: 1)
        let remoteName = parts.first.map(String.init) ?? "origin"
        let remoteBranch = parts.dropFirst().first.map(String.init) ?? branch

        // Get ahead/behind counts
        let countResult = await run(
            ["rev-list", "--left-right", "--count", "\(branch)...\(upstream)"],
            in: worktreePath
        )

        var ahead = 0
        var behind = 0

        if case .success(let counts) = countResult {
            let countParts = counts.split(separator: "\t")
            ahead = Int(countParts.first ?? "0") ?? 0
            behind = Int(countParts.dropFirst().first ?? "0") ?? 0
        }

        // Get last fetch time - handle both regular repos and worktrees
        let lastFetch: Date?
        let gitPath = worktreePath.appendingPathComponent(".git")
        var fetchHeadPath: URL

        // Check if .git is a file (worktree) or directory (main repo)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            // This is a worktree - read the gitdir path from .git file
            if let gitFileContents = try? String(contentsOf: gitPath, encoding: .utf8) {
                let gitdirPath = gitFileContents
                    .replacingOccurrences(of: "gitdir:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Go up from worktrees/<name> to the main repo's .git directory
                let gitdir = URL(fileURLWithPath: gitdirPath)
                fetchHeadPath = gitdir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("FETCH_HEAD")
            } else {
                fetchHeadPath = gitPath.appendingPathComponent("FETCH_HEAD")
            }
        } else {
            fetchHeadPath = gitPath.appendingPathComponent("FETCH_HEAD")
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: fetchHeadPath.path) {
            lastFetch = attrs[.modificationDate] as? Date
        } else {
            lastFetch = nil
        }

        return RemoteTrackingInfo(
            remoteName: remoteName,
            remoteBranch: remoteBranch,
            ahead: ahead,
            behind: behind,
            lastFetch: lastFetch
        )
    }

    // MARK: - Recent Commits

    func getRecentCommits(in worktreePath: URL, count: Int = 5) async -> Result<[CommitInfo], GitError> {
        let format = "%H|%h|%s|%an|%aI"
        let result = await run(
            ["log", "-\(count)", "--format=\(format)"],
            in: worktreePath
        )

        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            // Get current HEAD
            let headResult = await run(["rev-parse", "HEAD"], in: worktreePath)
            let headHash = (try? headResult.get()) ?? ""

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]

            let commits = output.components(separatedBy: "\n").compactMap { line -> CommitInfo? in
                let parts = line.split(separator: "|", maxSplits: 4).map(String.init)
                guard parts.count >= 5 else { return nil }

                let fullHash = parts[0]
                let shortHash = parts[1]
                let message = parts[2]
                let author = parts[3]
                let dateString = parts[4]

                let date = dateFormatter.date(from: dateString) ?? Date()

                return CommitInfo(
                    id: fullHash,
                    shortHash: shortHash,
                    message: message,
                    author: author,
                    date: date,
                    isHead: fullHash == headHash
                )
            }

            return .success(commits)
        }
    }

    // MARK: - Stash Count

    func getStashCount(in worktreePath: URL) async -> Result<Int, GitError> {
        let result = await run(["stash", "list"], in: worktreePath)

        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            return .success(output.components(separatedBy: "\n").filter { !$0.isEmpty }.count)
        }
    }

    // MARK: - Worktree Management

    func listWorktrees(in repoPath: URL) async -> Result<String, GitError> {
        await run(["worktree", "list", "--porcelain"], in: repoPath)
    }

    func addWorktree(at path: URL, branch: String, in repoPath: URL) async -> Result<Void, GitError> {
        let result = await run(["worktree", "add", path.path, branch], in: repoPath)
        return result.map { _ in () }
    }

    func addWorktreeNewBranch(at path: URL, newBranch: String, baseBranch: String?, in repoPath: URL) async -> Result<Void, GitError> {
        var args = ["worktree", "add", "-b", newBranch, path.path]
        if let base = baseBranch {
            args.append(base)
        }
        let result = await run(args, in: repoPath)
        return result.map { _ in () }
    }

    func removeWorktree(at path: URL, force: Bool = false, in repoPath: URL) async -> Result<Void, GitError> {
        var args = ["worktree", "remove"]
        if force { args.append("--force") }
        args.append(path.path)
        let result = await run(args, in: repoPath)
        return result.map { _ in () }
    }

    func pruneWorktrees(in repoPath: URL) async -> Result<Void, GitError> {
        let result = await run(["worktree", "prune"], in: repoPath)
        return result.map { _ in () }
    }

    // MARK: - Branch Information

    func getAllBranches(in repoPath: URL) async -> Result<[String], GitError> {
        let result = await run(["branch", "-a", "--format=%(refname:short)"], in: repoPath)

        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            return .success(output.components(separatedBy: "\n").filter { !$0.isEmpty })
        }
    }

    func getMergeBase(branch1: String, branch2: String, in repoPath: URL) async -> String? {
        let result = await run(["merge-base", branch1, branch2], in: repoPath)
        return try? result.get()
    }

    // MARK: - Merge Detection (for cleanup)

    /// Detects the main branch name (main or master)
    func getMainBranch(in repoPath: URL) async -> String? {
        // Try 'main' first, then 'master'
        for branch in ["main", "master"] {
            let result = await run(["rev-parse", "--verify", branch], in: repoPath)
            if case .success = result {
                return branch
            }
        }
        return nil
    }

    /// Checks if a branch is fully merged into another branch
    func isBranchMerged(branch: String, into targetBranch: String, in repoPath: URL) async -> Bool {
        // Use merge-base --is-ancestor: returns 0 if branch is ancestor of target
        // The "--" separator prevents branch names from being interpreted as options
        let result = await run(["merge-base", "--is-ancestor", "--", branch, targetBranch], in: repoPath)
        return result.isSuccess
    }

    /// Gets the number of commits in branch that are not in targetBranch
    func getUnmergedCommitCount(branch: String, relativeTo targetBranch: String, in repoPath: URL) async -> Result<Int, GitError> {
        // The "--" separator prevents branch names from being interpreted as options
        let result = await run(["rev-list", "--count", "--", "\(targetBranch)..\(branch)"], in: repoPath)
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            return .success(Int(output) ?? 0)
        }
    }

    /// Checks if a remote branch exists
    func remoteBranchExists(branch: String, remote: String = "origin", in repoPath: URL) async -> Bool {
        // The "--" separator prevents branch names from being interpreted as options
        let result = await run(["ls-remote", "--heads", "--", remote, branch], in: repoPath)
        guard case .success(let output) = result else {
            return false
        }
        return !output.isEmpty
    }

    /// Gets the date of the last commit on a branch
    func getLastCommitDate(branch: String, in repoPath: URL) async -> Date? {
        // The "--" separator prevents branch names from being interpreted as options
        let result = await run(["log", "-1", "--format=%aI", "--", branch], in: repoPath)
        guard case .success(let output) = result else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: output)
    }

    /// Gets comprehensive merge info for a branch
    func getMergeInfo(for branch: String, in repoPath: URL) async -> MergeInfo? {
        guard let mainBranch = await getMainBranch(in: repoPath) else {
            return nil
        }

        async let isMerged = isBranchMerged(branch: branch, into: mainBranch, in: repoPath)
        async let commitsAheadResult = getUnmergedCommitCount(branch: branch, relativeTo: mainBranch, in: repoPath)
        async let remoteBranchExists = remoteBranchExists(branch: branch, in: repoPath)
        async let lastCommitDate = getLastCommitDate(branch: branch, in: repoPath)

        // Extract value from Result, defaulting to 0 on failure
        let commitsAhead = (try? await commitsAheadResult.get()) ?? 0

        return MergeInfo(
            isMergedToMain: await isMerged,
            mainBranch: mainBranch,
            commitsAheadOfMain: commitsAhead,
            remoteBranchExists: await remoteBranchExists,
            lastCommitDate: await lastCommitDate,
            mergedAt: nil // Could be determined via reflog but adds complexity
        )
    }

    /// Calculates the disk size of a directory (non-isolated to avoid async iterator warning)
    nonisolated func getDirectorySize(at path: URL) -> UInt64? {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += UInt64(fileSize)
        }

        return totalSize
    }

    /// Deletes a local branch
    func deleteBranch(_ branch: String, force: Bool = false, in repoPath: URL) async -> Result<Void, GitError> {
        let flag = force ? "-D" : "-d"
        let result = await run(["branch", flag, branch], in: repoPath)
        return result.map { _ in () }
    }

    // MARK: - Commit Graph (for visualization)

    func getCommitGraph(in repoPath: URL, maxCommits: Int = 20) async -> Result<[GraphCommit], GitError> {
        let format = "%H|%P|%s|%D"
        let result = await run(
            ["log", "--all", "-\(maxCommits)", "--format=\(format)"],
            in: repoPath
        )

        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let output):
            let commits = output.components(separatedBy: "\n").compactMap { line -> GraphCommit? in
                let parts = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 3 else { return nil }

                let hash = parts[0]
                let parents = parts[1].split(separator: " ").map(String.init)
                let message = parts[2]
                let refs = parts.count > 3 ? parts[3] : ""

                return GraphCommit(
                    hash: hash,
                    parents: parents,
                    message: message,
                    refs: refs.components(separatedBy: ", ").filter { !$0.isEmpty }
                )
            }
            return .success(commits)
        }
    }
}

// MARK: - Git Error

enum GitError: Error, LocalizedError {
    case commandFailed(String)
    case executionFailed(String)
    case notAGitRepository

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .executionFailed(let message):
            return "Failed to execute git: \(message)"
        case .notAGitRepository:
            return "Not a git repository"
        }
    }
}

// MARK: - Graph Commit (for visualization)

struct GraphCommit: Identifiable {
    let hash: String
    let parents: [String]
    let message: String
    let refs: [String]

    // Computed properties to avoid data duplication
    var id: String { hash }
    var shortHash: String { String(hash.prefix(7)) }

    var isMergeCommit: Bool {
        parents.count > 1
    }

    var branchRefs: [String] {
        refs.filter { !$0.hasPrefix("tag:") }
    }

    var tagRefs: [String] {
        refs.filter { $0.hasPrefix("tag:") }.map { $0.replacingOccurrences(of: "tag: ", with: "") }
    }
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
