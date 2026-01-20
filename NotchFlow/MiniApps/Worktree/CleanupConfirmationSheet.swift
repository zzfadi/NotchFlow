import SwiftUI

/// Confirmation dialog before performing cleanup
struct CleanupConfirmationSheet: View {
    let candidates: [CleanupCandidate]
    let deleteBranches: Bool
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                Text("Confirm Cleanup")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Summary
            VStack(spacing: 12) {
                // Counts
                HStack(spacing: 20) {
                    statBadge(
                        value: "\(candidates.count)",
                        label: "Worktrees",
                        color: .white
                    )

                    statBadge(
                        value: "\(safeCount)",
                        label: "Safe",
                        color: .green
                    )

                    statBadge(
                        value: "\(withWarningsCount)",
                        label: "With Warnings",
                        color: .orange
                    )
                }

                // Space to be freed
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text("\(formattedTotalSize) will be freed")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(8)
            }

            // Worktrees with warnings
            if withWarningsCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Worktrees with warnings:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(candidatesWithWarnings) { candidate in
                                warningRow(candidate)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Branch deletion notice
            if deleteBranches {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)

                    Text("Local branches will also be deleted")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }

            Spacer()

            // Warning text
            Text("This action cannot be undone. Branches can be restored from remote if needed.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            // Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)

                Spacer()

                Button(action: onConfirm) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Remove \(candidates.count) Worktree\(candidates.count == 1 ? "" : "s")")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(16)
        .frame(width: 350, height: 400)
        .background(Color.black.opacity(0.95))
    }

    // MARK: - Subviews

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
    }

    private func warningRow(_ candidate: CleanupCandidate) -> some View {
        HStack {
            Text(candidate.worktree.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            ForEach(candidate.warnings.prefix(2)) { warning in
                Image(systemName: warning.icon)
                    .font(.system(size: 9))
                    .foregroundColor(warning.color)
            }

            if candidate.warnings.count > 2 {
                Text("+\(candidate.warnings.count - 2)")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(4)
    }

    // MARK: - Computed Properties

    private var safeCount: Int {
        candidates.filter { $0.cleanupStatus == .safe }.count
    }

    private var withWarningsCount: Int {
        candidates.filter { !$0.warnings.isEmpty }.count
    }

    private var candidatesWithWarnings: [CleanupCandidate] {
        candidates.filter { !$0.warnings.isEmpty }
    }

    private var formattedTotalSize: String {
        let total = candidates.compactMap { $0.diskSize }.reduce(0, +)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(total))
    }
}

#Preview {
    CleanupConfirmationSheet(
        candidates: [
            CleanupCandidate(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/feature-1"),
                    branch: "feature/one",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                cleanupStatus: .safe,
                diskSize: 45_000_000,
                warnings: []
            ),
            CleanupCandidate(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/feature-2"),
                    branch: "feature/two",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                cleanupStatus: .merged,
                diskSize: 128_000_000,
                warnings: [.uncommittedChanges(count: 3)]
            )
        ],
        deleteBranches: true,
        onDismiss: {},
        onConfirm: {}
    )
}
