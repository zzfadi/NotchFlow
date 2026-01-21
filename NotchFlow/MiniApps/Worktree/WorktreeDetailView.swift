import SwiftUI
import AppKit

struct WorktreeDetailView: View {
    let worktree: Worktree
    let onClose: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            detailHeader

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // Status Card
                    statusCard

                    // Remote Tracking Card
                    if let tracking = worktree.remoteTracking {
                        remoteTrackingCard(tracking)
                    }

                    // Recent Commits
                    if let commits = worktree.recentCommits, !commits.isEmpty {
                        recentCommitsCard(commits)
                    }

                    // Path Info
                    pathInfoCard

                    // Quick Actions
                    actionsCard
                }
                .padding(12)
            }
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(spacing: 8) {
            // Type indicator
            Image(systemName: worktree.isMainWorktree ? "house.fill" : "arrow.triangle.branch")
                .font(.system(size: 14))
                .foregroundColor(worktree.isMainWorktree ? .orange : .cyan)

            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(worktree.branchDisplayName)
                    .font(.system(size: 11))
                    .foregroundColor(.cyan.opacity(0.8))
            }

            Spacer()

            // Refresh button
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Refresh status")

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Working Tree Status", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            if let status = worktree.status {
                if status.isClean {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Clean working tree")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 6) {
                        statusRow(label: "Staged", count: status.staged, icon: "plus.circle.fill", color: .green)
                        statusRow(label: "Modified", count: status.modified, icon: "pencil.circle.fill", color: .orange)
                        statusRow(label: "Deleted", count: status.deleted, icon: "minus.circle.fill", color: .red)
                        statusRow(label: "Untracked", count: status.untracked, icon: "questionmark.circle.fill", color: .gray)
                        if status.conflicted > 0 {
                            statusRow(label: "Conflicted", count: status.conflicted, icon: "exclamationmark.triangle.fill", color: .red)
                        }
                    }
                }

                // Stash indicator
                if let stashCount = worktree.stashCount, stashCount > 0 {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 10))
                        Text("\(stashCount) stash\(stashCount == 1 ? "" : "es")")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Fetching status...")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func statusRow(label: String, count: Int, icon: String, color: Color) -> some View {
        Group {
            if count > 0 {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 10))
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                }
            }
        }
    }

    // MARK: - Remote Tracking Card

    private func remoteTrackingCard(_ tracking: RemoteTrackingInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Remote: \(tracking.remoteName)/\(tracking.remoteBranch)", systemImage: "cloud")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                // Ahead
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text("\(tracking.ahead)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(tracking.ahead > 0 ? .green : .gray)

                    Text("ahead")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Divider()
                    .frame(height: 30)

                // Behind
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                        Text("\(tracking.behind)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(tracking.behind > 0 ? .orange : .gray)

                    Text("behind")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Sync status
                if tracking.isSynced {
                    Label("Synced", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else if tracking.needsPush {
                    Label("Push", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else if tracking.needsPull {
                    Label("Pull", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            if let lastFetch = tracking.lastFetch {
                Text("Last fetch: \(lastFetch, style: .relative)")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Recent Commits Card

    private func recentCommitsCard(_ commits: [CommitInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recent Commits", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            VStack(spacing: 0) {
                ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                    HStack(spacing: 8) {
                        // Commit graph line
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.cyan.opacity(0.3))
                                    .frame(width: 2, height: 8)
                            } else {
                                Spacer().frame(height: 8)
                            }

                            Circle()
                                .fill(commit.isHead ? Color.cyan : Color.gray)
                                .frame(width: 8, height: 8)

                            if index < commits.count - 1 {
                                Rectangle()
                                    .fill(Color.cyan.opacity(0.3))
                                    .frame(width: 2, height: 8)
                            } else {
                                Spacer().frame(height: 8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(commit.shortHash)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan)

                                if commit.isHead {
                                    Text("HEAD")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.cyan)
                                        .cornerRadius(3)
                                }

                                Spacer()

                                Text(commit.relativeDate)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }

                            Text(commit.message)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Path Info Card

    private var pathInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                pathRow(label: "Worktree", path: worktree.shortPath)
                pathRow(label: "Repository", path: worktree.parentRepo.lastPathComponent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func pathRow(label: String, path: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)

            Text(path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(worktree.path.path, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Copy path")
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quick Actions", systemImage: "bolt")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ActionCardButton(icon: "terminal", label: "Terminal") {
                    openInTerminal(worktree.path)
                }

                ActionCardButton(icon: "curlybraces", label: "VS Code") {
                    openInVSCode(worktree.path)
                }

                ActionCardButton(icon: "folder", label: "Finder") {
                    openInFinder(worktree.path)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func openInTerminal(_ path: URL) {
        WorktreeActions.openInTerminal(path)
    }

    private func openInVSCode(_ path: URL) {
        WorktreeActions.openInVSCode(path)
    }

    private func openInFinder(_ path: URL) {
        WorktreeActions.openInFinder(path)
    }
}

// MARK: - Action Card Button

struct ActionCardButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorktreeDetailView(
        worktree: Worktree(
            path: URL(fileURLWithPath: "/Users/demo/Code/project"),
            branch: "main",
            lastModified: Date(),
            parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
            isMainWorktree: true,
            status: GitStatusSummary(staged: 2, modified: 3, untracked: 1),
            remoteTracking: RemoteTrackingInfo(
                remoteName: "origin",
                remoteBranch: "main",
                ahead: 2,
                behind: 1,
                lastFetch: Date().addingTimeInterval(-3600)
            ),
            recentCommits: [
                CommitInfo(id: "abc123", shortHash: "abc123", message: "Fix bug",
                           author: "Dev", date: Date(), isHead: true),
                CommitInfo(id: "def456", shortHash: "def456", message: "Add feature",
                           author: "Dev", date: Date().addingTimeInterval(-86400), isHead: false)
            ],
            stashCount: 2
        ),
        onClose: {},
        onRefresh: {}
    )
    .frame(width: 300, height: 500)
    .background(Color.black)
}
