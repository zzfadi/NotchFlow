import SwiftUI

/// Row displaying a single cleanup candidate with status and selection
struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Selection checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .green : .gray.opacity(0.5))

                    // Status indicator
                    Image(systemName: candidate.cleanupStatus.icon)
                        .font(.system(size: 14))
                        .foregroundColor(candidate.cleanupStatus.color)

                    // Worktree info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.worktree.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(candidate.worktree.branch)
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Warnings count badge
                    if !candidate.warnings.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                            Text("\(candidate.warnings.count)")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    }

                    // Disk size
                    Text(candidate.formattedDiskSize)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 55, alignment: .trailing)

                    // Expand button
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(isSelected ? Color.green.opacity(0.1) : Color.white.opacity(0.03))

            // Expanded details
            if isExpanded {
                expandedDetails
            }
        }
        .cornerRadius(8)
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Path
            HStack {
                Text("Path:")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text(candidate.worktree.shortPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            // Merge status
            if let mergeInfo = candidate.mergeInfo {
                HStack {
                    Text("Status:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(mergeInfo.mergeStatusDescription)
                        .font(.system(size: 10))
                        .foregroundColor(mergeInfo.isMergedToMain ? .green : .orange)
                }
            }

            // Warnings
            if !candidate.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    ForEach(candidate.warnings) { warning in
                        HStack(spacing: 6) {
                            Image(systemName: warning.icon)
                                .font(.system(size: 10))
                                .foregroundColor(warning.color)

                            Text(warning.message)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }

            // Status explanation
            Text(statusExplanation)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(Color.white.opacity(0.02))
    }

    private var statusExplanation: String {
        switch candidate.cleanupStatus {
        case .safe:
            return "This worktree's branch is merged and has no uncommitted work. Safe to remove."
        case .merged:
            return "Branch is merged but has warnings. Review before removing."
        case .unmerged:
            return "Branch has commits not in main. May contain unmerged work."
        case .protected:
            return "This worktree cannot be removed."
        case .unknown:
            return "Could not determine merge status."
        }
    }
}

#Preview {
    VStack {
        CleanupCandidateRow(
            candidate: CleanupCandidate(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/feature-branch"),
                    branch: "feature/new-login",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                cleanupStatus: .safe,
                mergeInfo: MergeInfo(
                    isMergedToMain: true,
                    mainBranch: "main",
                    commitsAheadOfMain: 0,
                    remoteBranchExists: false,
                    lastCommitDate: Date().addingTimeInterval(-86400 * 7),
                    mergedAt: nil
                ),
                diskSize: 45_000_000,
                warnings: []
            ),
            isSelected: true,
            onToggle: {}
        )

        CleanupCandidateRow(
            candidate: CleanupCandidate(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/wip-branch"),
                    branch: "wip/experimental",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                cleanupStatus: .merged,
                mergeInfo: MergeInfo(
                    isMergedToMain: true,
                    mainBranch: "main",
                    commitsAheadOfMain: 0,
                    remoteBranchExists: true,
                    lastCommitDate: Date(),
                    mergedAt: nil
                ),
                diskSize: 128_000_000,
                warnings: [
                    .uncommittedChanges(count: 3),
                    .remoteBranchStillExists
                ]
            ),
            isSelected: false,
            onToggle: {}
        )
    }
    .padding()
    .background(Color.black)
}
