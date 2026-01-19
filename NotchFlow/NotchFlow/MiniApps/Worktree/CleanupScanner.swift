import Foundation
import Combine

/// Scans worktrees and identifies candidates for cleanup
@MainActor
class CleanupScanner: ObservableObject {
    @Published var candidates: [CleanupCandidate] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var errorMessage: String?

    private let gitRunner = GitCommandRunner.shared
    private var scanTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var safeCandidates: [CleanupCandidate] {
        candidates.filter { $0.cleanupStatus == .safe }
    }

    var mergedCandidates: [CleanupCandidate] {
        candidates.filter { $0.cleanupStatus == .merged }
    }

    var unmergedCandidates: [CleanupCandidate] {
        candidates.filter { $0.cleanupStatus == .unmerged }
    }

    var totalReclaimableSpace: UInt64 {
        safeCandidates.compactMap { $0.diskSize }.reduce(0, +)
    }

    var formattedReclaimableSpace: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalReclaimableSpace))
    }

    // MARK: - Public Methods

    func scan(from groups: [RepositoryGroup]) {
        scanTask?.cancel()

        scanTask = Task { @MainActor in
            isScanning = true
            errorMessage = nil
            scanProgress = 0
            candidates = []

            let allWorktrees = groups.flatMap { $0.worktrees }
            let linkedWorktrees = allWorktrees.filter { !$0.isMainWorktree }

            guard !linkedWorktrees.isEmpty else {
                isScanning = false
                return
            }

            var newCandidates: [CleanupCandidate] = []
            let total = linkedWorktrees.count

            for (index, worktree) in linkedWorktrees.enumerated() {
                if Task.isCancelled { break }

                let candidate = await analyzeWorktree(worktree)
                newCandidates.append(candidate)

                scanProgress = Double(index + 1) / Double(total)
            }

            if !Task.isCancelled {
                // Sort by cleanup status: safe first, then merged, then unmerged
                candidates = newCandidates.sorted { lhs, rhs in
                    let order: [CleanupStatus] = [.safe, .merged, .unmerged, .unknown, .protected]
                    let lhsIndex = order.firstIndex(of: lhs.cleanupStatus) ?? 999
                    let rhsIndex = order.firstIndex(of: rhs.cleanupStatus) ?? 999
                    return lhsIndex < rhsIndex
                }
            }

            isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    func performCleanup(
        candidates: [CleanupCandidate],
        deleteBranches: Bool
    ) async -> [CleanupResult] {
        var results: [CleanupResult] = []

        for candidate in candidates {
            if Task.isCancelled { break }

            let worktree = candidate.worktree

            // Remove the worktree (force to handle any uncommitted changes if user confirmed)
            let removeResult = await gitRunner.removeWorktree(
                at: worktree.path,
                force: true,
                in: worktree.parentRepo
            )

            switch removeResult {
            case .success:
                var deletedBranch = false

                // Delete the branch if requested and worktree was successfully removed
                if deleteBranches && !worktree.isMainWorktree && !worktree.isDetached && worktree.branch != "main" && worktree.branch != "master" {
                    let branchResult = await gitRunner.deleteBranch(
                        worktree.branch,
                        force: true,
                        in: worktree.parentRepo
                    )
                    deletedBranch = branchResult.isSuccess
                }

                results.append(CleanupResult(
                    worktree: worktree,
                    success: true,
                    deletedBranch: deletedBranch
                ))

            case .failure(let error):
                results.append(CleanupResult(
                    worktree: worktree,
                    success: false,
                    error: error.localizedDescription
                ))
            }
        }

        // Remove cleaned up candidates from the list
        let removedIds = Set(results.filter { $0.success }.map { $0.worktree.id })
        self.candidates.removeAll { removedIds.contains($0.worktree.id) }

        return results
    }

    // MARK: - Private Methods

    private func analyzeWorktree(_ worktree: Worktree) async -> CleanupCandidate {
        // Main worktrees are always protected
        if worktree.isMainWorktree {
            return CleanupCandidate(
                worktree: worktree,
                cleanupStatus: .protected,
                warnings: []
            )
        }

        // Protected branches
        if worktree.branch == "main" || worktree.branch == "master" {
            return CleanupCandidate(
                worktree: worktree,
                cleanupStatus: .protected,
                warnings: []
            )
        }

        // Gather information in parallel (skip merge detection for detached HEAD worktrees)
        async let statusTask = gitRunner.getStatus(for: worktree.path)
        async let stashCountTask = gitRunner.getStashCount(in: worktree.path)
        async let remoteTrackingTask = worktree.isDetached ? nil : gitRunner.getRemoteTracking(for: worktree.path, branch: worktree.branch)

        let mergeInfo: MergeInfo? = worktree.isDetached ? nil : await gitRunner.getMergeInfo(for: worktree.branch, in: worktree.parentRepo)
        let status = await statusTask
        let stashCount = await stashCountTask
        let remoteTracking = await remoteTrackingTask

        // Calculate disk size (synchronous, non-isolated)
        let diskSize = gitRunner.getDirectorySize(at: worktree.path)

        // Build warnings list
        var warnings: [CleanupWarning] = []

        if !status.isClean {
            warnings.append(.uncommittedChanges(count: status.totalChanges))
        }

        if let tracking = remoteTracking, tracking.needsPush {
            warnings.append(.unpushedCommits(count: tracking.ahead))
        }

        if stashCount > 0 {
            warnings.append(.stashesPresent(count: stashCount))
        }

        if let lastCommit = mergeInfo?.lastCommitDate {
            let daysSinceActivity = Calendar.current.dateComponents([.day], from: lastCommit, to: Date()).day ?? 0
            if daysSinceActivity >= 0 && daysSinceActivity <= 7 {
                warnings.append(.recentActivity(days: daysSinceActivity))
            }
        }

        if mergeInfo?.remoteBranchExists == true {
            warnings.append(.remoteBranchStillExists)
        }

        // Sort warnings by severity
        warnings.sort { $0.severity > $1.severity }

        // Determine cleanup status
        let cleanupStatus: CleanupStatus
        if mergeInfo?.isMergedToMain == true {
            if warnings.isEmpty {
                cleanupStatus = .safe
            } else {
                cleanupStatus = .merged
            }
        } else {
            cleanupStatus = .unmerged
        }

        return CleanupCandidate(
            worktree: worktree,
            cleanupStatus: cleanupStatus,
            mergeInfo: mergeInfo,
            diskSize: diskSize,
            warnings: warnings
        )
    }
}
