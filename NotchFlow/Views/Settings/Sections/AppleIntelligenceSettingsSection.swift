import SwiftUI

/// Apple Intelligence settings section - on-device AI configuration
struct AppleIntelligenceSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var aiService = FoundationModelsService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "wand.and.stars",
                    title: "Apple Intelligence",
                    subtitle: "On-device AI features",
                    accentColor: .indigo
                )

                // Availability status card
                availabilityCard

                // Main toggle (show if can be enabled OR if already enabled)
                if aiService.availability.canBeEnabled || settings.foundationModelsEnabled {
                    mainToggleCard
                }

                // Per-app toggles (only show when enabled and available)
                if settings.foundationModelsEnabled && aiService.availability == .available {
                    perAppTogglesCard
                }

                // Info section
                infoCard

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            aiService.checkAvailability()
        }
        .onChange(of: settings.foundationModelsEnabled) { _, _ in
            aiService.checkAvailability()
        }
    }

    // MARK: - Availability Card

    private var availabilityCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(aiService.availability.statusTitle)
                        .font(.headline)

                    Text(aiService.availability.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if aiService.availability == .unavailableNotConfigured {
                    Button("Open Settings") {
                        openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(4)
        }
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(aiService.availability.statusColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: aiService.availability.statusSymbol)
                .font(.system(size: 18))
                .foregroundColor(aiService.availability.statusColor)
        }
    }

    // MARK: - Main Toggle Card

    private var mainToggleCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Apple Intelligence Features", isOn: $settings.foundationModelsEnabled)
                    .toggleStyle(.switch)

                Text("Uses on-device AI to summarize notes, suggest commit messages, and explain configurations. All processing happens locally on your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(4)
        }
    }

    // MARK: - Per-App Toggles Card

    private var perAppTogglesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("Enable for Mini Apps", systemImage: "app.badge")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    Toggle(isOn: $settings.aiFeaturesFogNote) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fog Note")
                                Text("Summarize and expand notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "note.text")
                                .foregroundColor(settings.accentColor)
                        }
                    }

                    Divider()

                    Toggle(isOn: $settings.aiFeaturesWorktree) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Worktree")
                                Text("Suggest commit messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.orange)
                        }
                    }

                    Divider()

                    Toggle(isOn: $settings.aiFeaturesAIConfig) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Config")
                                Text("Explain configuration files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "brain")
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("About Apple Intelligence", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "lock.shield", text: "All AI processing happens on-device")
                    InfoRow(icon: "arrow.up.arrow.down", text: "No data is sent to external servers")
                    InfoRow(icon: "cpu", text: "Requires Apple Silicon and macOS 26+")
                }
            }
            .padding(4)
        }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        // Open Apple Intelligence settings in System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.appleintelligencelanguage") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Info Row Component

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    AppleIntelligenceSettingsSection()
        .frame(width: 450, height: 600)
}
