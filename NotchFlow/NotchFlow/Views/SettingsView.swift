import SwiftUI
import AppKit

// MARK: - Shared Utilities

/// Presents an NSOpenPanel to browse for a folder and returns the selected path
func browseForFolder(completion: @escaping (String?) -> Void) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false

    if panel.runModal() == .OK {
        completion(panel.url?.path)
    } else {
        completion(nil)
    }
}

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case worktree = "Worktree"
        case aiConfig = "AI Config"
        case fogNote = "Fog Note"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            WorktreeSettingsView()
                .tabItem {
                    Label("Worktree", systemImage: "arrow.triangle.branch")
                }
                .tag(SettingsTab.worktree)

            AIConfigSettingsView()
                .tabItem {
                    Label("AI Config", systemImage: "brain")
                }
                .tag(SettingsTab.aiConfig)

            FogNoteSettingsView()
                .tabItem {
                    Label("Fog Note", systemImage: "note.text")
                }
                .tag(SettingsTab.fogNote)
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Picker("Default Mini-App", selection: $settings.defaultApp) {
                    ForEach(MiniApp.allCases) { app in
                        Text(app.rawValue).tag(app.rawValue)
                    }
                }
            }

            Section {
                ColorPicker("Accent Color", selection: accentColorBinding)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var accentColorBinding: Binding<Color> {
        Binding(
            get: { settings.accentColor },
            set: { settings.accentColorHex = $0.hexString }
        )
    }
}

struct WorktreeSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var newPath: String = ""

    var body: some View {
        Form {
            Section("Scan Directories") {
                List {
                    ForEach(settings.worktreeScanPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(action: {
                                settings.worktreeScanPaths.removeAll { $0 == path }
                                settings.saveSettings()
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 150)

                HStack {
                    TextField("Add path...", text: $newPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        if !newPath.isEmpty && !settings.worktreeScanPaths.contains(newPath) {
                            settings.worktreeScanPaths.append(newPath)
                            settings.saveSettings()
                            newPath = ""
                        }
                    }
                    .disabled(newPath.isEmpty)

                    Button("Browse...") {
                        browseForFolder { path in
                            if let path = path, !settings.worktreeScanPaths.contains(path) {
                                settings.worktreeScanPaths.append(path)
                                settings.saveSettings()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AIConfigSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var newPath: String = ""

    var body: some View {
        Form {
            Section("Scan Directories") {
                List {
                    ForEach(settings.aiConfigScanPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(action: {
                                settings.aiConfigScanPaths.removeAll { $0 == path }
                                settings.saveSettings()
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 150)

                HStack {
                    TextField("Add path...", text: $newPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        if !newPath.isEmpty && !settings.aiConfigScanPaths.contains(newPath) {
                            settings.aiConfigScanPaths.append(newPath)
                            settings.saveSettings()
                            newPath = ""
                        }
                    }
                    .disabled(newPath.isEmpty)

                    Button("Browse...") {
                        browseForFolder { path in
                            if let path = path, !settings.aiConfigScanPaths.contains(path) {
                                settings.aiConfigScanPaths.append(path)
                                settings.saveSettings()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct FogNoteSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    TextField("Notes Directory", text: $settings.fogNotesDirectory)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        browseForFolder { path in
                            if let path = path {
                                settings.fogNotesDirectory = path
                                settings.saveSettings()
                            }
                        }
                    }
                }

                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.fogNotesDirectory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
