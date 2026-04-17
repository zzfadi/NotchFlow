import SwiftUI
import AppKit

/// Settings panel: manage the folders NotchFlow has been granted access to.
/// Mirrors the "Privacy & Security → Files and Folders" panel in System
/// Settings, scoped to NotchFlow.
struct PermissionsSettingsSection: View {
    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "lock.shield",
                    title: "Permissions",
                    subtitle: "Folders NotchFlow can read",
                    accentColor: .green
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Granted folders", systemImage: "folder.fill.badge.gearshape")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("NotchFlow only reads folders you explicitly grant. Adding a folder opens the macOS file picker — picking it there is what authorizes NotchFlow with the operating system.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if permissions.grantedFolders.isEmpty {
                            emptyState
                        } else {
                            foldersList
                        }

                        HStack {
                            Button {
                                permissions.requestAccessViaPanel(multiSelect: true)
                            } label: {
                                Label("Add folder…", systemImage: "plus")
                            }

                            Spacer()

                            Button {
                                permissions.seedToolConfigDefaults()
                            } label: {
                                Label("Re-add tool defaults", systemImage: "arrow.clockwise")
                            }
                            .help("Re-adds ~/.claude, ~/.cursor, and the VS Code user config paths if they exist")
                        }
                    }
                    .padding(4)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Onboarding", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Run the first-launch welcome flow again. Useful if you want to re-pick folders with the guided UX.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            settings.onboardingComplete = false
                            NotificationCenter.default.post(name: .showOnboarding, object: nil)
                        } label: {
                            Label("Run onboarding again", systemImage: "arrow.uturn.left.circle")
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No folders granted")
                    .font(.system(size: 13, weight: .medium))
                Text("NotchFlow can still read global tool configs under ~/Library, but won't scan your projects until you add folders.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var foldersList: some View {
        VStack(spacing: 4) {
            ForEach(permissions.grantedFolders) { folder in
                PermissionRow(folder: folder)
            }
        }
    }
}

// MARK: - Row

private struct PermissionRow: View {
    let folder: GrantedFolder
    @State private var isHovering = false
    @ObservedObject private var permissions = PermissionManager.shared

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(folder.exists ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .help(folder.exists ? "Accessible" : "Folder no longer exists on disk")

            Image(systemName: "folder.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text(folder.displayPath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovering {
                Button {
                    NSWorkspace.shared.selectFile(
                        folder.url.path,
                        inFileViewerRootedAtPath: folder.url.deletingLastPathComponent().path
                    )
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button {
                    permissions.revoke(folder)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Revoke access")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionsSettingsSection()
        .frame(width: 450, height: 500)
}
