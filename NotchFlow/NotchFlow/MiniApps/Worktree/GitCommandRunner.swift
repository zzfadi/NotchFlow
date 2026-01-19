import Foundation

/// Utility for running git commands and parsing their output
actor GitCommandRunner {
    static let shared = GitCommandRunner()

    private init() {}

    // MARK: - Command Execution

    func run(_ arguments: [String], in directory: URL) async -> Result<String, GitError> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = arguments
        task.currentDirectoryURL = directory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if task.terminationStatus == 0 {
                let output = String(data: outputData, encoding: .utf8) ?? ""
                return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.commandFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        } catch {
            return .failure(.executionFailed(error.localizedDescription))
        }
    }

    // MARK: - Git Status

    func getStatus(for worktreePath: URL) async -> GitStatusSummary {
        let result = await run(["status", "--porcelain=v1"], in: worktreePath)

        guard case .success(let output) = result else {
            return GitStatusSummary()
        }

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

        return summary
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

    func getRecentCommits(in worktreePath: URL, count: Int = 5) async -> [CommitInfo] {
        let format = "%H|%h|%s|%an|%aI"
        let result = await run(
            ["log", "-\(count)", "--format=\(format)"],
            in: worktreePath
        )

        guard case .success(let output) = result else {
            return []
        }

        // Get current HEAD
        let headResult = await run(["rev-parse", "HEAD"], in: worktreePath)
        let headHash = (try? headResult.get()) ?? ""

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return output.components(separatedBy: "\n").compactMap { line -> CommitInfo? in
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
    }

    // MARK: - Stash Count

    func getStashCount(in worktreePath: URL) async -> Int {
        let result = await run(["stash", "list"], in: worktreePath)

        guard case .success(let output) = result else {
            return 0
        }

        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
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

    func getAllBranches(in repoPath: URL) async -> [String] {
        let result = await run(["branch", "-a", "--format=%(refname:short)"], in: repoPath)

        guard case .success(let output) = result else {
            return []
        }

        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func getMergeBase(branch1: String, branch2: String, in repoPath: URL) async -> String? {
        let result = await run(["merge-base", branch1, branch2], in: repoPath)
        return try? result.get()
    }

    // MARK: - Commit Graph (for visualization)

    func getCommitGraph(in repoPath: URL, maxCommits: Int = 20) async -> [GraphCommit] {
        let format = "%H|%P|%s|%D"
        let result = await run(
            ["log", "--all", "-\(maxCommits)", "--format=\(format)"],
            in: repoPath
        )

        guard case .success(let output) = result else {
            return []
        }

        return output.components(separatedBy: "\n").compactMap { line -> GraphCommit? in
            let parts = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { return nil }

            let hash = parts[0]
            let parents = parts[1].split(separator: " ").map(String.init)
            let message = parts[2]
            let refs = parts.count > 3 ? parts[3] : ""

            return GraphCommit(
                hash: hash,
                shortHash: String(hash.prefix(7)),
                parents: parents,
                message: message,
                refs: refs.components(separatedBy: ", ").filter { !$0.isEmpty }
            )
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
    let id: String
    let hash: String
    let shortHash: String
    let parents: [String]
    let message: String
    let refs: [String]

    init(hash: String, shortHash: String, parents: [String], message: String, refs: [String]) {
        self.id = hash
        self.hash = hash
        self.shortHash = shortHash
        self.parents = parents
        self.message = message
        self.refs = refs
    }

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
