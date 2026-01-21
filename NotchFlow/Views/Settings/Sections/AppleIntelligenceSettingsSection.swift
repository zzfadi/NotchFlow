import SwiftUI

/// Apple Intelligence settings - on-device AI for FogNote
struct AppleIntelligenceSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var aiService = FoundationModelsService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "wand.and.stars",
                    title: "Apple Intelligence",
                    subtitle: "Smart note organization",
                    accentColor: .indigo
                )

                // Availability status
                availabilityCard

                // Main toggle
                if aiService.availability.canBeEnabled || settings.foundationModelsEnabled {
                    mainToggleCard
                }

                // Info section
                infoCard

                Spacer()
            }
            .padding(24)
        }
        .onAppear { aiService.checkAvailability() }
        .onChange(of: settings.foundationModelsEnabled) { _, _ in
            aiService.checkAvailability()
        }
    }

    private var availabilityCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(aiService.availability.statusColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: aiService.availability.statusSymbol)
                        .font(.system(size: 18))
                        .foregroundColor(aiService.availability.statusColor)
                }

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
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.appleintelligencelanguage") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(4)
        }
    }

    private var mainToggleCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Smart Organization", isOn: $settings.foundationModelsEnabled)
                    .toggleStyle(.switch)

                Text("Automatically organizes notes with tags, categories, and priorities. All processing happens on-device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(4)
        }
    }

    private var infoCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("How It Works", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "tag", text: "Extracts relevant tags from note content")
                    InfoRow(icon: "folder", text: "Categorizes notes (task, idea, meeting, etc.)")
                    InfoRow(icon: "exclamationmark.circle", text: "Detects priority from urgency words")
                    InfoRow(icon: "lock.shield", text: "All processing stays on your Mac")
                }
            }
            .padding(4)
        }
    }
}

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

#Preview {
    AppleIntelligenceSettingsSection()
        .frame(width: 450, height: 500)
}
