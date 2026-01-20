import SwiftUI

/// General settings section - core app preferences
struct GeneralSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "gear",
                    title: "General",
                    subtitle: "Core app preferences",
                    accentColor: .blue
                )

                // Launch settings
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                        Divider()

                        HStack {
                            Text("Default Mini-App")
                            Spacer()
                            Picker("", selection: $settings.defaultApp) {
                                ForEach(MiniApp.allCases) { app in
                                    Label(app.rawValue, systemImage: app.icon)
                                        .tag(app.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }
                    .padding(4)
                }

                // Danger zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button(role: .destructive) {
                            settings.resetToDefaults()
                        } label: {
                            Label("Reset All Settings to Defaults", systemImage: "trash")
                        }
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
    GeneralSettingsSection()
        .frame(width: 450, height: 400)
}
