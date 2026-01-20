import Foundation
import Combine

class WorktreeScanner: ObservableObject {
    @Published var repositoryGroups: [RepositoryGroup] = []
    @Published var isScanning: Bool = false
    @Published var isFetchingStatus: Bool = false
    @Published var lastScanDate: Date?
    @Published var errorMessage: String?
    @Published var scanProgress: Double = 0

    private let settings = SettingsManager.shared
    private let gitRunner = GitCommandRunner.shared
    private var scanTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    // MARK: - Public Methods

    func scan() {
        scanTask?.cancel()

        scanTask = Task { @MainActor in
            isScanning = true
            errorMessage = nil
            scanProgress = 0

            let groups = await performScan()

            if !Task.isCancelled {
                repositoryGroups = groups
                lastScanDate = Date()
                isScanning = false

                // Fetch rich status for all worktrees
                await fetchAllStatus()
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        statusTask?.cancel()
        // Note: We set these immediately for UI responsiveness.
        // The tasks check Task.isCancelled and will stop processing.
        // This is intentional - we prioritize UI feedback over waiting for task completion.
        isScanning = false
        isFetchingStatus = false
    }

    func refreshStatus() {
        statusTask?.cancel()
        statusTask = Task { @MainActor in
            await fetchAllStatus()
        }
    }

    func refreshWorktree(_ worktree: Worktree) {
        Task { @MainActor in
            await fetchStatusForWorktree(worktree)
        }
    }

    // MARK: - Status Fetching

    private func fetchAllStatus() async {
        isFetchingStatus = true

        // Take a snapshot to avoid mutating while iterating
        let currentGroups = repositoryGroups
        var updatedGroups: [RepositoryGroup] = []

        for group in currentGroups {
            if Task.isCancelled { break }

            var updatedWorktrees: [Worktree] = []
            for worktree in group.worktrees {
                if Task.isCancelled { break }

                let updatedWorktree = await fetchStatusData(for: worktree)
                updatedWorktrees.append(updatedWorktree)
            }

            var updatedGroup = group
            updatedGroup.worktrees = updatedWorktrees
            updatedGroups.append(updatedGroup)
        }

        // Capture the final result before crossing actor boundary
        let finalGroups = updatedGroups
        await MainActor.run {
            if !Task.isCancelled {
                repositoryGroups = finalGroups
            }
            isFetchingStatus = false
        }
    }

    private func fetchStatusForWorktree(_ worktree: Worktree) async {
        // Fetch status data first (expensive operation)
        let updatedWorktree = await fetchStatusData(for: worktree)

        // Then update the UI atomically, re-checking indices since they may have changed
        await MainActor.run {
            guard let groupIndex = repositoryGroups.firstIndex(where: { $0.worktrees.contains(worktree) }),
                  let worktreeIndex = repositoryGroups[groupIndex].worktrees.firstIndex(of: worktree) else {
                return
            }
            repositoryGroups[groupIndex].worktrees[worktreeIndex] = updatedWorktree
        }
    }

    private func fetchStatusData(for worktree: Worktree) async -> Worktree {
        async let statusResult = gitRunner.getStatus(for: worktree.path)
        async let remoteTracking = worktree.isDetached ? nil : gitRunner.getRemoteTracking(for: worktree.path, branch: worktree.branch)
        async let stashCountResult = gitRunner.getStashCount(in: worktree.path)
        async let recentCommitsResult = gitRunner.getRecentCommits(in: worktree.path, count: 3)

        // Extract values from Result types, using nil/default on failure
        let status = try? await statusResult.get()
        let stashCount = try? await stashCountResult.get()
        let recentCommits = try? await recentCommitsResult.get()

        return Worktree(
            id: worktree.id,
            path: worktree.path,
            branch: worktree.branch,
            lastModified: worktree.lastModified,
            parentRepo: worktree.parentRepo,
            isMainWorktree: worktree.isMainWorktree,
            commitHash: worktree.commitHash,
            isDetached: worktree.isDetached,
            status: status,
            remoteTracking: await remoteTracking,
            recentCommits: recentCommits,
            stashCount: stashCount
        )
    }

    // MARK: - Private Scanning Methods

    private func performScan() async -> [RepositoryGroup] {
        var allWorktrees: [Worktree] = []
        let totalPaths = settings.worktreeScanPaths.count

        // Guard against division by zero
        guard totalPaths > 0 else {
            return []
        }

        for (index, pathString) in settings.worktreeScanPaths.enumerated() {
            if Task.isCancelled { break }

            let path = URL(fileURLWithPath: pathString)

            guard FileManager.default.fileExists(atPath: path.path) else {
                continue
            }

            let worktrees = await scanDirectory(path)
            allWorktrees.append(contentsOf: worktrees)

            await MainActor.run {
                scanProgress = Double(index + 1) / Double(totalPaths)
            }
        }

        // Remove duplicates (same worktree can be discovered via parent repo and direct scan)
        var seen = Set<String>()
        let uniqueWorktrees = allWorktrees.filter { worktree in
            let key = worktree.path.standardizedFileURL.path
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Group worktrees by parent repository
        return groupWorktreesByRepo(uniqueWorktrees)
    }

    private func scanDirectory(_ directory: URL) async -> [Worktree] {
        var worktrees: [Worktree] = []
        let fileManager = FileManager.default

        // Check if this directory is a git repo
        let gitDir = directory.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitDir.path) {
            // Check for worktrees
            let worktreesDir = gitDir.appendingPathComponent("worktrees")
            if fileManager.fileExists(atPath: worktreesDir.path) {
                let linkedWorktrees = scanWorktreesDirectory(worktreesDir, parentRepo: directory)
                worktrees.append(contentsOf: linkedWorktrees)
            }

            // Add main worktree
            if let mainWorktree = parseMainWorktree(directory) {
                worktrees.append(mainWorktree)
            }
        }

        // Recursively scan subdirectories (up to 3 levels deep)
        await scanSubdirectories(directory, depth: 0, maxDepth: 3, worktrees: &worktrees)

        return worktrees
    }

    private func scanSubdirectories(_ directory: URL, depth: Int, maxDepth: Int, worktrees: inout [Worktree]) async {
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

            // Check if this is a git repo
            let gitDir = item.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                // Check for worktrees
                let worktreesDir = gitDir.appendingPathComponent("worktrees")
                if fileManager.fileExists(atPath: worktreesDir.path) {
                    let linkedWorktrees = scanWorktreesDirectory(worktreesDir, parentRepo: item)
                    worktrees.append(contentsOf: linkedWorktrees)
                }

                // Add main worktree
                if let mainWorktree = parseMainWorktree(item) {
                    worktrees.append(mainWorktree)
                }
            } else {
                // Check if it's a linked worktree (has .git file pointing to gitdir)
                let gitFile = item.appendingPathComponent(".git")
                if let gitFileContents = try? String(contentsOf: gitFile, encoding: .utf8),
                   gitFileContents.hasPrefix("gitdir:") {
                    if let worktree = parseLinkedWorktree(item, gitFileContents: gitFileContents) {
                        worktrees.append(worktree)
                    }
                } else {
                    // Recurse into subdirectory
                    await scanSubdirectories(item, depth: depth + 1, maxDepth: maxDepth, worktrees: &worktrees)
                }
            }
        }
    }

    private func scanWorktreesDirectory(_ worktreesDir: URL, parentRepo: URL) -> [Worktree] {
        var worktrees: [Worktree] = []
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: worktreesDir,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return worktrees }

        for worktreeInfo in contents {
            let gitdirFile = worktreeInfo.appendingPathComponent("gitdir")

            guard let gitdirPath = try? String(contentsOf: gitdirFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            let worktreePath = URL(fileURLWithPath: gitdirPath).deletingLastPathComponent()

            guard fileManager.fileExists(atPath: worktreePath.path) else { continue }

            // Get branch info
            let headFile = worktreeInfo.appendingPathComponent("HEAD")
            let (branch, isDetached, commitHash) = parseHEAD(headFile)

            // Get last modified date
            let attrs = try? fileManager.attributesOfItem(atPath: worktreePath.path)
            let lastModified = attrs?[.modificationDate] as? Date ?? Date()

            let worktree = Worktree(
                path: worktreePath,
                branch: branch,
                lastModified: lastModified,
                parentRepo: parentRepo,
                isMainWorktree: false,
                commitHash: commitHash,
                isDetached: isDetached
            )
            worktrees.append(worktree)
        }

        return worktrees
    }

    private func parseMainWorktree(_ repoPath: URL) -> Worktree? {
        let fileManager = FileManager.default
        let headFile = repoPath.appendingPathComponent(".git/HEAD")

        guard fileManager.fileExists(atPath: headFile.path) else { return nil }

        let (branch, isDetached, commitHash) = parseHEAD(headFile)

        let attrs = try? fileManager.attributesOfItem(atPath: repoPath.path)
        let lastModified = attrs?[.modificationDate] as? Date ?? Date()

        return Worktree(
            path: repoPath,
            branch: branch,
            lastModified: lastModified,
            parentRepo: repoPath,
            isMainWorktree: true,
            commitHash: commitHash,
            isDetached: isDetached
        )
    }

    private func parseLinkedWorktree(_ worktreePath: URL, gitFileContents: String) -> Worktree? {
        let gitdirPath = gitFileContents
            .replacingOccurrences(of: "gitdir:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let gitdir = URL(fileURLWithPath: gitdirPath, relativeTo: worktreePath)

        // Find parent repo
        var parentRepo = gitdir
        while parentRepo.lastPathComponent != "worktrees" && parentRepo.path != "/" {
            parentRepo = parentRepo.deletingLastPathComponent()
        }
        if parentRepo.lastPathComponent == "worktrees" {
            parentRepo = parentRepo.deletingLastPathComponent().deletingLastPathComponent()
        }

        let headFile = gitdir.appendingPathComponent("HEAD")
        let (branch, isDetached, commitHash) = parseHEAD(headFile)

        let attrs = try? FileManager.default.attributesOfItem(atPath: worktreePath.path)
        let lastModified = attrs?[.modificationDate] as? Date ?? Date()

        return Worktree(
            path: worktreePath,
            branch: branch,
            lastModified: lastModified,
            parentRepo: parentRepo,
            isMainWorktree: false,
            commitHash: commitHash,
            isDetached: isDetached
        )
    }

    private func parseHEAD(_ headFile: URL) -> (branch: String, isDetached: Bool, commitHash: String?) {
        guard let contents = try? String(contentsOf: headFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return ("unknown", false, nil)
        }

        if contents.hasPrefix("ref: refs/heads/") {
            let branch = String(contents.dropFirst("ref: refs/heads/".count))
            return (branch, false, nil)
        } else {
            // Detached HEAD
            return ("HEAD", true, contents)
        }
    }

    private func groupWorktreesByRepo(_ worktrees: [Worktree]) -> [RepositoryGroup] {
        var groups: [URL: RepositoryGroup] = [:]

        for worktree in worktrees {
            if var group = groups[worktree.parentRepo] {
                group.worktrees.append(worktree)
                groups[worktree.parentRepo] = group
            } else {
                groups[worktree.parentRepo] = RepositoryGroup(
                    repoPath: worktree.parentRepo,
                    worktrees: [worktree]
                )
            }
        }

        // Sort worktrees within each group
        return groups.values.map { group in
            var sortedGroup = group
            sortedGroup.worktrees.sort { $0.lastModified > $1.lastModified }
            return sortedGroup
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
