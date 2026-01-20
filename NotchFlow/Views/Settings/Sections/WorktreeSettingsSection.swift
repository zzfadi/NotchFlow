import SwiftUI

/// Worktree mini-app settings section
struct WorktreeSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "arrow.triangle.branch",
                    title: "Worktree",
                    subtitle: "Git worktree discovery settings",
                    accentColor: .orange
                )

                // Scan directories
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Scan Directories", systemImage: "folder.badge.gearshape")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("NotchFlow will search these directories for git repositories with worktrees.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        PathListEditor(
                            paths: $settings.worktreeScanPaths,
                            title: "Scan Directories",
                            onSave: { settings.saveSettings() }
                        )
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview {
    WorktreeSettingsSection()
        .frame(width: 450, height: 400)
}
