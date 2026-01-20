import SwiftUI
import AppKit

/// Sheet for creating new worktrees
struct CreateWorktreeSheet: View {
    let parentRepo: URL
    let onDismiss: () -> Void
    let onCreated: () -> Void

    @State private var worktreePath: String = ""
    @State private var selectedBranch: String = ""
    @State private var newBranchName: String = ""
    @State private var createNewBranch: Bool = true
    @State private var availableBranches: [String] = []
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    private let gitRunner = GitCommandRunner.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)

                Text("Create Worktree")
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

            // Repository info
            HStack {
                Text("Repository:")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text(parentRepo.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }

            // Worktree path
            VStack(alignment: .leading, spacing: 4) {
                Text("Worktree Location")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)

                HStack {
                    TextField("Path for new worktree", text: $worktreePath)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)

                    Button(action: selectFolder) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Branch selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Branch")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)

                Picker("Branch Mode", selection: $createNewBranch) {
                    Text("Create new branch").tag(true)
                    Text("Use existing branch").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if createNewBranch {
                    TextField("New branch name", text: $newBranchName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)

                    if !availableBranches.isEmpty {
                        HStack {
                            Text("Base branch:")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)

                            Picker("Base", selection: $selectedBranch) {
                                ForEach(availableBranches, id: \.self) { branch in
                                    Text(branch).tag(branch)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 150)
                        }
                    }
                } else {
                    if availableBranches.isEmpty {
                        Text("Loading branches...")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    } else {
                        Picker("Branch", selection: $selectedBranch) {
                            ForEach(availableBranches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)

                Spacer()

                Button(action: createWorktree) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        Text("Create")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isCreating || !isValidInput)
            }
        }
        .padding(16)
        .frame(width: 350, height: 380)
        .background(Color.black.opacity(0.9))
        .onAppear {
            loadBranches()
            suggestPath()
        }
    }

    private var isValidInput: Bool {
        !worktreePath.isEmpty && (createNewBranch ? !newBranchName.isEmpty : !selectedBranch.isEmpty)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Location"

        if panel.runModal() == .OK, let url = panel.url {
            worktreePath = url.path
        }
    }

    private func loadBranches() {
        Task {
            let branchesResult = await gitRunner.getAllBranches(in: parentRepo)
            let branches = (try? branchesResult.get()) ?? []
            await MainActor.run {
                // Filter out symbolic refs like "HEAD", "HEAD -> main", "origin/HEAD -> origin/main"
                // Use exact matching with space after arrow to avoid filtering branches named "HEAD-feature"
                availableBranches = branches.filter { branch in
                    !(branch == "HEAD" ||
                      branch.hasPrefix("HEAD -> ") ||
                      branch == "origin/HEAD" ||
                      branch.hasPrefix("origin/HEAD -> "))
                }
                if let main = availableBranches.first(where: { $0 == "main" || $0 == "master" }) {
                    selectedBranch = main
                } else if let first = availableBranches.first {
                    selectedBranch = first
                }
            }
        }
    }

    private func suggestPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let worktreesDir = home.appendingPathComponent(".worktrees")
        let repoName = parentRepo.lastPathComponent
        worktreePath = worktreesDir.appendingPathComponent(repoName).appendingPathComponent("new-worktree").path
    }

    private func createWorktree() {
        isCreating = true
        errorMessage = nil

        Task {
            let path = URL(fileURLWithPath: worktreePath)
            let result: Result<Void, GitError>

            if createNewBranch {
                result = await gitRunner.addWorktreeNewBranch(
                    at: path,
                    newBranch: newBranchName,
                    baseBranch: selectedBranch.isEmpty ? nil : selectedBranch,
                    in: parentRepo
                )
            } else {
                result = await gitRunner.addWorktree(
                    at: path,
                    branch: selectedBranch,
                    in: parentRepo
                )
            }

            await MainActor.run {
                isCreating = false

                switch result {
                case .success:
                    onCreated()
                    onDismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Confirmation dialog for removing a worktree
struct RemoveWorktreeSheet: View {
    let worktree: Worktree
    let onDismiss: () -> Void
    let onRemoved: () -> Void

    @State private var forceRemove: Bool = false
    @State private var isRemoving: Bool = false
    @State private var errorMessage: String?

    private let gitRunner = GitCommandRunner.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)

                Text("Remove Worktree")
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

            // Worktree info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Name:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(worktree.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Branch:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(worktree.branch)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyan)
                }

                HStack {
                    Text("Path:")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(worktree.shortPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            // Warning
            if let status = worktree.status, !status.isClean {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This worktree has uncommitted changes!")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }

            // Force remove toggle
            Toggle(isOn: $forceRemove) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Force remove")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("Remove even if there are uncommitted changes")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(.switch)

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)

                Spacer()

                Button(action: removeWorktree) {
                    HStack {
                        if isRemoving {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        Text("Remove")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isRemoving)
            }
        }
        .padding(16)
        .frame(width: 350, height: 340)
        .background(Color.black.opacity(0.9))
    }

    private func removeWorktree() {
        isRemoving = true
        errorMessage = nil

        Task {
            let result = await gitRunner.removeWorktree(
                at: worktree.path,
                force: forceRemove,
                in: worktree.parentRepo
            )

            await MainActor.run {
                isRemoving = false

                switch result {
                case .success:
                    onRemoved()
                    onDismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Button for pruning stale worktree references
struct PruneWorktreesButton: View {
    let repoPath: URL
    let onPruned: () -> Void

    @State private var isPruning: Bool = false
    @State private var showResult: Bool = false
    @State private var resultMessage: String = ""
    @State private var hideTask: Task<Void, Never>?

    private let gitRunner = GitCommandRunner.shared

    var body: some View {
        Button(action: pruneWorktrees) {
            HStack(spacing: 4) {
                if isPruning {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.system(size: 10))
                }
                Text("Prune")
                    .font(.system(size: 10))
            }
            .foregroundColor(.orange)
        }
        .buttonStyle(.plain)
        .disabled(isPruning)
        .help("Remove stale worktree references")
        .popover(isPresented: $showResult) {
            Text(resultMessage)
                .font(.system(size: 11))
                .padding(8)
        }
        .onDisappear {
            // Cancel pending hide task when view is removed
            hideTask?.cancel()
        }
    }

    private func pruneWorktrees() {
        isPruning = true
        // Cancel any pending hide task
        hideTask?.cancel()

        Task {
            let result = await gitRunner.pruneWorktrees(in: repoPath)

            await MainActor.run {
                isPruning = false

                switch result {
                case .success:
                    resultMessage = "Pruned stale worktree references"
                    onPruned()
                case .failure(let error):
                    resultMessage = error.localizedDescription
                }

                showResult = true

                // Auto-hide after 3 seconds using cancellable Task
                hideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if !Task.isCancelled {
                        showResult = false
                    }
                }
            }
        }
    }
}

#Preview {
    CreateWorktreeSheet(
        parentRepo: URL(fileURLWithPath: "/Users/demo/Code/project"),
        onDismiss: {},
        onCreated: {}
    )
}
