import SwiftUI

/// Filter options for cleanup candidates
enum CleanupFilter: String, CaseIterable {
    case all = "All"
    case safe = "Safe"
    case merged = "Merged"

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .safe: return "checkmark.circle"
        case .merged: return "arrow.triangle.merge"
        }
    }
}

/// Main view for managing worktree cleanup
struct CleanupCandidatesView: View {
    let repositoryGroups: [RepositoryGroup]
    let onDismiss: () -> Void
    let onCleanupComplete: () -> Void

    @StateObject private var scanner = CleanupScanner()
    @State private var selectedFilter: CleanupFilter = .all
    @State private var selectedCandidates: Set<UUID> = []
    @State private var deleteBranches: Bool = true
    @State private var showingConfirmation: Bool = false
    @State private var showingResults: Bool = false
    @State private var cleanupResults: [CleanupResult] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.white.opacity(0.1))

            if scanner.isScanning {
                scanningView
            } else if scanner.candidates.isEmpty {
                emptyStateView
            } else {
                // Filter tabs + stats
                filterBar

                // Candidate list
                candidateList

                // Footer with actions
                footerView
            }
        }
        .frame(width: 420, height: 520)
        .background(Color.black.opacity(0.95))
        .onAppear {
            scanner.scan(from: repositoryGroups)
        }
        .sheet(isPresented: $showingConfirmation) {
            CleanupConfirmationSheet(
                candidates: selectedCandidatesArray,
                deleteBranches: deleteBranches,
                onDismiss: { showingConfirmation = false },
                onConfirm: { performCleanup() }
            )
        }
        .sheet(isPresented: $showingResults) {
            CleanupResultsSheet(
                results: cleanupResults,
                onDismiss: {
                    showingResults = false
                    if cleanupResults.contains(where: { $0.success }) {
                        onCleanupComplete()
                    }
                }
            )
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(.system(size: 16))
                .foregroundColor(.green)

            Text("Cleanup Worktrees")
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
        .padding(16)
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing worktrees...")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            ProgressView(value: scanner.scanProgress)
                .frame(width: 200)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("All Clean!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("No linked worktrees found to clean up.")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Filter tabs
            HStack(spacing: 8) {
                ForEach(CleanupFilter.allCases, id: \.self) { filter in
                    filterTab(filter)
                }

                Spacer()

                // Stats
                if !scanner.safeCandidates.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(scanner.safeCandidates.count) safe")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)

                        Text("•")
                            .foregroundColor(.gray)

                        Text(scanner.formattedReclaimableSpace)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }

    private func filterTab(_ filter: CleanupFilter) -> some View {
        Button(action: { selectedFilter = filter }) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10))
                Text(filter.rawValue)
                    .font(.system(size: 10, weight: .medium))

                if filter != .all {
                    let count = filter == .safe ? scanner.safeCandidates.count : scanner.mergedCandidates.count
                    Text("(\(count))")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(selectedFilter == filter ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedFilter == filter ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var candidateList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredCandidates) { candidate in
                    CleanupCandidateRow(
                        candidate: candidate,
                        isSelected: selectedCandidates.contains(candidate.id),
                        onToggle: { toggleSelection(candidate) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var footerView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.1))

            // Selection info and quick actions
            HStack {
                Text("\(selectedCandidates.count) selected")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer()

                Button("Select All Safe") {
                    selectAllSafe()
                }
                .font(.system(size: 10))
                .foregroundColor(.green)
                .buttonStyle(.plain)
                .disabled(scanner.safeCandidates.isEmpty)

                Text("•")
                    .foregroundColor(.gray.opacity(0.5))

                Button("Clear") {
                    selectedCandidates.removeAll()
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .buttonStyle(.plain)
                .disabled(selectedCandidates.isEmpty)
            }
            .padding(.horizontal, 16)

            // Delete branches toggle
            Toggle(isOn: $deleteBranches) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text("Also delete local branches")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 16)

            // Action buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)

                Spacer()

                Button(action: { showingConfirmation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Clean Up \(selectedCandidates.count)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedCandidates.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Computed Properties

    private var filteredCandidates: [CleanupCandidate] {
        switch selectedFilter {
        case .all:
            return scanner.candidates
        case .safe:
            return scanner.safeCandidates
        case .merged:
            return scanner.mergedCandidates
        }
    }

    private var selectedCandidatesArray: [CleanupCandidate] {
        scanner.candidates.filter { selectedCandidates.contains($0.id) }
    }

    // MARK: - Actions

    private func toggleSelection(_ candidate: CleanupCandidate) {
        if selectedCandidates.contains(candidate.id) {
            selectedCandidates.remove(candidate.id)
        } else {
            selectedCandidates.insert(candidate.id)
        }
    }

    private func selectAllSafe() {
        for candidate in scanner.safeCandidates {
            selectedCandidates.insert(candidate.id)
        }
    }

    private func performCleanup() {
        showingConfirmation = false

        Task {
            let results = await scanner.performCleanup(
                candidates: selectedCandidatesArray,
                deleteBranches: deleteBranches
            )

            await MainActor.run {
                cleanupResults = results
                selectedCandidates.removeAll()
                showingResults = true
            }
        }
    }
}

#Preview {
    CleanupCandidatesView(
        repositoryGroups: [],
        onDismiss: {},
        onCleanupComplete: {}
    )
}
