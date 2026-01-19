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
                // Sort by cleanup status using Comparable conformance: safe first, then merged, then unmerged, etc.
                candidates = newCandidates.sorted { $0.cleanupStatus < $1.cleanupStatus }
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

            // Remove the worktree with force flag (bypasses checks for uncommitted changes or locks)
            let removeResult = await gitRunner.removeWorktree(
                at: worktree.path,
                force: true,
                in: worktree.parentRepo
            )

            switch removeResult {
            case .success:
                var deletedBranch = false
                var branchDeletionError: String?

                // Delete branch only if: user requested it, not the main worktree, not a detached HEAD,
                // and not the main/master branch (which should never be deleted)
                if deleteBranches && !worktree.isMainWorktree && !worktree.isDetached && worktree.branch != "main" && worktree.branch != "master" {
                    let branchResult = await gitRunner.deleteBranch(
                        worktree.branch,
                        force: true,
                        in: worktree.parentRepo
                    )
                    switch branchResult {
                    case .success:
                        deletedBranch = true
                    case .failure(let error):
                        branchDeletionError = error.localizedDescription
                    }
                }

                results.append(CleanupResult(
                    worktree: worktree,
                    success: true,
                    deletedBranch: deletedBranch,
                    branchDeletionError: branchDeletionError
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
        async let statusResult = gitRunner.getStatus(for: worktree.path)
        async let stashCountResult = gitRunner.getStashCount(in: worktree.path)
        async let remoteTrackingTask = worktree.isDetached ? nil : gitRunner.getRemoteTracking(for: worktree.path, branch: worktree.branch)

        let mergeInfo: MergeInfo? = worktree.isDetached ? nil : await gitRunner.getMergeInfo(for: worktree.branch, in: worktree.parentRepo)
        let statusValue = await statusResult
        let stashCountValue = await stashCountResult
        let remoteTracking = await remoteTrackingTask

        // Extract values from Result types, defaulting on failure
        let status = (try? statusValue.get()) ?? GitStatusSummary()
        let stashCount = (try? stashCountValue.get()) ?? 0
        let statusFailed = statusValue.isSuccess == false
        let stashFailed = stashCountValue.isSuccess == false

        // Calculate disk size off main thread (file system enumeration can be slow)
        let worktreePath = worktree.path
        let diskSize = await Task.detached {
            GitCommandRunner.shared.getDirectorySize(at: worktreePath)
        }.value

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
        // Classification logic:
        // - .safe: Branch merged to main AND no warnings
        // - .merged: Branch merged to main BUT has warnings
        // - .unmerged: Branch not merged to main (may contain unmerged work)
        // - .unknown: Critical git commands failed
        let cleanupStatus: CleanupStatus
        if statusFailed && stashFailed {
            // Critical git commands failed - cannot determine status safely
            cleanupStatus = .unknown
        } else if worktree.isDetached {
            // Detached HEAD worktrees have no branch to merge - classify based on warnings only
            cleanupStatus = warnings.isEmpty ? .safe : .merged
        } else if mergeInfo?.isMergedToMain == true {
            cleanupStatus = warnings.isEmpty ? .safe : .merged
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
