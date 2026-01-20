import SwiftUI

/// AI Config mini-app settings section
struct AIConfigSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "brain",
                    title: "AI Config",
                    subtitle: "AI configuration file discovery",
                    accentColor: .cyan
                )

                // Scan directories
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Scan Directories", systemImage: "folder.badge.gearshape")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("NotchFlow will search these directories for AI configuration files (CLAUDE.md, .cursorrules, etc.).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        PathListEditor(
                            paths: $settings.aiConfigScanPaths,
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
    AIConfigSettingsSection()
        .frame(width: 450, height: 400)
}
