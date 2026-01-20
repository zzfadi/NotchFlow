import SwiftUI

/// Shows the results of a cleanup operation
struct CleanupResultsSheet: View {
    let results: [CleanupResult]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header with success/fail summary
            headerView

            Divider()

            // Results list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(results) { result in
                        resultRow(result)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()

            // Done button
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(16)
        .frame(width: 350, height: 350)
        .background(Color.black.opacity(0.95))
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            // Success count
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(successCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    Text("Removed")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 40)

            Spacer()

            // Failed count
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(failedCount > 0 ? .red : .gray.opacity(0.3))

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(failedCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(failedCount > 0 ? .red : .gray)
                    Text("Failed")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func resultRow(_ result: CleanupResult) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(result.success ? .green : .red)

            // Worktree info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.worktree.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if result.success {
                    HStack(spacing: 4) {
                        Text("Removed")
                            .font(.system(size: 9))
                            .foregroundColor(.green)

                        if result.deletedBranch {
                            Text("+ branch")
                                .font(.system(size: 9))
                                .foregroundColor(.purple)
                        }
                    }
                } else if let error = result.error {
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(result.success ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .cornerRadius(6)
    }

    // MARK: - Computed Properties

    private var successCount: Int {
        results.filter { $0.success }.count
    }

    private var failedCount: Int {
        results.filter { !$0.success }.count
    }
}

#Preview {
    CleanupResultsSheet(
        results: [
            CleanupResult(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/feature-1"),
                    branch: "feature/one",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                success: true,
                deletedBranch: true
            ),
            CleanupResult(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/feature-2"),
                    branch: "feature/two",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                success: true,
                deletedBranch: false
            ),
            CleanupResult(
                worktree: Worktree(
                    path: URL(fileURLWithPath: "/Users/demo/.worktrees/project/locked-branch"),
                    branch: "fix/locked",
                    lastModified: Date(),
                    parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
                    isMainWorktree: false
                ),
                success: false,
                error: "Worktree is locked"
            )
        ],
        onDismiss: {}
    )
}
