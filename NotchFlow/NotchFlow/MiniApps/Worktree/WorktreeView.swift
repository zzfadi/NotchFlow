import SwiftUI
import AppKit

struct WorktreeView: View {
    @StateObject private var scanner = WorktreeScanner()
    @State private var selectedWorktree: Worktree?
    @State private var searchText: String = ""
    @State private var expandedRepos: Set<UUID> = []

    var filteredGroups: [RepositoryGroup] {
        if searchText.isEmpty {
            return scanner.repositoryGroups
        }
        return scanner.repositoryGroups.compactMap { group in
            let filteredWorktrees = group.worktrees.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.branch.localizedCaseInsensitiveContains(searchText) ||
                $0.shortPath.localizedCaseInsensitiveContains(searchText)
            }
            if filteredWorktrees.isEmpty {
                return nil
            }
            return RepositoryGroup(id: group.id, repoPath: group.repoPath, worktrees: filteredWorktrees)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and refresh
            headerView

            Divider()

            // Content
            if scanner.isScanning {
                scanningView
            } else if scanner.repositoryGroups.isEmpty {
                emptyStateView
            } else {
                worktreeListView
            }
        }
        .onAppear {
            if scanner.repositoryGroups.isEmpty {
                scanner.scan()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))

                TextField("Search worktrees", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)

            // Refresh button
            Button(action: {
                scanner.scan()
            }) {
                Image(systemName: scanner.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .disabled(scanner.isScanning)
            .help("Refresh worktrees")
        }
        .padding(8)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Scanning for worktrees...")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Worktrees Found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Text("Configure scan directories in Settings")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.7))

            Button(action: {
                scanner.scan()
            }) {
                Text("Scan Again")
                    .font(.system(size: 12))
                    .foregroundColor(.pink)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Worktree List

    private var worktreeListView: some View {
        ScrollView {
            LazyVStack(spacing: 4, pinnedViews: [.sectionHeaders]) {
                ForEach(filteredGroups) { group in
                    Section(header: repositoryHeaderView(group)) {
                        if expandedRepos.contains(group.id) || !searchText.isEmpty {
                            ForEach(group.worktrees) { worktree in
                                WorktreeRowView(
                                    worktree: worktree,
                                    isSelected: selectedWorktree?.id == worktree.id,
                                    onSelect: {
                                        selectedWorktree = worktree
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Repository Header

    private func repositoryHeaderView(_ group: RepositoryGroup) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedRepos.contains(group.id) {
                    expandedRepos.remove(group.id)
                } else {
                    expandedRepos.insert(group.id)
                }
            }
        }) {
            HStack {
                Image(systemName: expandedRepos.contains(group.id) || !searchText.isEmpty ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 12)

                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.pink.opacity(0.8))

                Text(group.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(group.worktrees.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Worktree Row View

struct WorktreeRowView: View {
    let worktree: Worktree
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Branch icon
                Image(systemName: worktree.isMainWorktree ? "house.fill" : "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(worktree.isMainWorktree ? .orange : .cyan)
                    .frame(width: 16)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(worktree.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if worktree.isDetached {
                            Text("DETACHED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }

                    Text(worktree.branchDisplayName)
                        .font(.system(size: 10))
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                // Actions
                if isHovering || isSelected {
                    HStack(spacing: 4) {
                        ActionButton(icon: "terminal", tooltip: "Open in Terminal") {
                            openInTerminal(worktree.path)
                        }

                        ActionButton(icon: "curlybraces", tooltip: "Open in VS Code") {
                            openInVSCode(worktree.path)
                        }

                        ActionButton(icon: "folder", tooltip: "Open in Finder") {
                            openInFinder(worktree.path)
                        }
                    }
                } else {
                    Text(worktree.lastModified, style: .relative)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.pink.opacity(0.2) : (isHovering ? Color.white.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(action: { openInTerminal(worktree.path) }) {
                Label("Open in Terminal", systemImage: "terminal")
            }

            Button(action: { openInVSCode(worktree.path) }) {
                Label("Open in VS Code", systemImage: "curlybraces")
            }

            Button(action: { openInFinder(worktree.path) }) {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(action: { copyPath(worktree.path) }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Actions

    private func openInTerminal(_ path: URL) {
        // Escape single quotes by replacing ' with '\'' for safe shell interpolation
        let escapedPath = path.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedPath)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func openInVSCode(_ path: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["code", path.path]
        try? task.run()
    }

    private func openInFinder(_ path: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }

    private func copyPath(_ path: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path.path, forType: .string)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

#Preview {
    WorktreeView()
        .frame(width: 400, height: 250)
        .background(Color.black)
}
