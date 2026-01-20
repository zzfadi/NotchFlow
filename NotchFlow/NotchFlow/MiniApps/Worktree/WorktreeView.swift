import SwiftUI
import AppKit

struct WorktreeView: View {
    @StateObject private var scanner = WorktreeScanner()
    @State private var selectedWorktree: Worktree?
    @State private var searchText: String = ""
    @State private var expandedRepos: Set<UUID> = []
    @State private var viewMode: ViewMode = .list
    @State private var showingDetail: Bool = false
    @State private var showingCreateSheet: Bool = false
    @State private var showingCleanupView: Bool = false
    @State private var refreshRotation: Double = 0

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case graph = "Graph"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .graph: return "point.3.connected.trianglepath.dotted"
            }
        }
    }

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

    var totalWorktrees: Int {
        scanner.repositoryGroups.flatMap { $0.worktrees }.count
    }

    var dirtyWorktrees: Int {
        scanner.repositoryGroups.flatMap { $0.worktrees }.filter { $0.status?.isClean == false }.count
    }

    var body: some View {
        HSplitView {
            // Left panel - List
            VStack(spacing: 0) {
                headerView
                Divider()
                mainContent
            }
            .frame(minWidth: 250)

            // Right panel - Detail (when selected)
            if showingDetail, let worktree = selectedWorktree {
                WorktreeDetailView(
                    worktree: worktree,
                    onClose: { showingDetail = false },
                    onRefresh: { scanner.refreshWorktree(worktree) }
                )
                .frame(minWidth: 280, maxWidth: 320)
            }
        }
        .onAppear {
            if scanner.repositoryGroups.isEmpty {
                scanner.scan()
            }
        }
        .sheet(isPresented: $showingCleanupView) {
            CleanupCandidatesView(
                repositoryGroups: scanner.repositoryGroups,
                onDismiss: { showingCleanupView = false },
                onCleanupComplete: {
                    showingCleanupView = false
                    scanner.scan()
                }
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // Stats bar
            HStack(spacing: 12) {
                StatBadge(
                    icon: "arrow.triangle.branch",
                    value: "\(totalWorktrees)",
                    label: "worktrees",
                    color: .cyan
                )

                if dirtyWorktrees > 0 {
                    StatBadge(
                        icon: "exclamationmark.circle",
                        value: "\(dirtyWorktrees)",
                        label: "dirty",
                        color: .orange
                    )
                }

                Spacer()

                // View mode toggle
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
            }

            // Search and actions
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))

                    TextField("Search worktrees", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)

                // Cleanup button
                Button(action: {
                    showingCleanupView = true
                }) {
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(scanner.repositoryGroups.isEmpty || scanner.isScanning)
                .help("Clean up merged worktrees")

                // Refresh button
                Button(action: {
                    scanner.scan()
                }) {
                    Image(systemName: scanner.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(refreshRotation))
                }
                .buttonStyle(.plain)
                .disabled(scanner.isScanning)
                .help("Refresh worktrees")
                .onChange(of: scanner.isScanning) { _, isScanning in
                    if isScanning {
                        // Start continuous rotation
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            refreshRotation = 360
                        }
                    } else {
                        // Stop and reset rotation
                        withAnimation(.easeOut(duration: 0.3)) {
                            refreshRotation = 0
                        }
                    }
                }
            }

            // Progress indicator
            if scanner.isScanning || scanner.isFetchingStatus {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)

                    Text(scanner.isScanning ? "Scanning..." : "Fetching status...")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    Spacer()

                    if scanner.isScanning {
                        Text("\(Int(scanner.scanProgress * 100))%")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(8)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if scanner.isScanning && scanner.repositoryGroups.isEmpty {
            scanningView
        } else if scanner.repositoryGroups.isEmpty {
            emptyStateView
        } else {
            switch viewMode {
            case .list:
                worktreeListView
            case .graph:
                worktreeGraphView
            }
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Scanning for worktrees...")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Text("Checking \(Int(scanner.scanProgress * 100))%")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.7))
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

    // MARK: - List View

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
                                        showingDetail = true
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

    // MARK: - Graph View

    private var worktreeGraphView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Repository name
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.pink.opacity(0.8))

                            Text(group.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            if group.totalChanges > 0 {
                                Text("\(group.totalChanges) changes")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 8)

                        // Graph
                        WorktreeGraphView(group: group)
                    }
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(8)
                }
            }
            .padding(8)
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

                // Compact graph preview
                CompactWorktreeGraph(worktrees: group.worktrees)
                    .padding(.horizontal, 4)

                Spacer()

                // Status indicators
                if group.totalChanges > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 8))
                        Text("\(group.totalChanges)")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.orange)
                }

                if group.hasUnpushedChanges {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }

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

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
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
                // Status indicator
                statusIndicator

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

                    HStack(spacing: 6) {
                        Text(worktree.branchDisplayName)
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.8))
                            .lineLimit(1)

                        // Remote tracking status
                        if let tracking = worktree.remoteTracking, !tracking.isSynced {
                            Text(tracking.summary)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(tracking.needsPush ? .green : .orange)
                        }
                    }
                }

                Spacer()

                // Right side info
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
                    // Status summary and time
                    HStack(spacing: 8) {
                        if let status = worktree.status, !status.isClean {
                            Text(status.summary)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.orange)
                        }

                        Text(worktree.lastModified, style: .relative)
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
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

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        Group {
            if let status = worktree.status {
                Circle()
                    .fill(status.isClean ? Color.green : (status.conflicted > 0 ? Color.red : Color.orange))
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: 6, height: 6)
            }
        }
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

    private func copyPath(_ path: URL) {
        WorktreeActions.copyPath(path)
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
        .frame(width: 600, height: 350)
        .background(Color.black)
}
