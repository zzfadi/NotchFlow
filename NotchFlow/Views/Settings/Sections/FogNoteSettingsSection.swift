import SwiftUI
import AppKit
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.notchflow.app", category: "fognote")

/// Fog Note mini-app settings section
struct FogNoteSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "note.text",
                    title: "Fog Note",
                    subtitle: "Quick capture and note storage",
                    accentColor: settings.accentColor
                )

                // Storage location
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Storage Location", systemImage: "folder")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Your notes are stored as markdown files in this directory.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Notes Directory", text: $settings.fogNotesDirectory)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                browseForDirectory()
                            }
                        }

                        HStack {
                            Button {
                                openInFinder()
                            } label: {
                                Label("Open in Finder", systemImage: "folder")
                            }

                            Spacer()

                            // Show note count if directory exists
                            if let count = noteCount {
                                Text("\(count) note\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Computed Properties

    private var noteCount: Int? {
        let path = settings.fogNotesDirectory
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            return contents.filter { $0.hasSuffix(".md") }.count
        } catch {
            log.error("Error reading notes directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Actions

    @MainActor
    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let path = panel.url?.path {
            settings.fogNotesDirectory = path
            settings.saveSettings()
        }
    }

    private func openInFinder() {
        let success = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.fogNotesDirectory)
        if !success {
            log.error("Failed to open directory in Finder: \(settings.fogNotesDirectory, privacy: .public)")
        }
    }
}

#Preview {
    FogNoteSettingsSection()
        .frame(width: 450, height: 400)
}
