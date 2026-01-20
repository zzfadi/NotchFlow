import SwiftUI
import AppKit

// MARK: - Shared Utilities

/// Presents an NSOpenPanel to browse for a folder and returns the selected path
@MainActor
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
    @ObservedObject private var settings = SettingsManager.shared
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
        .frame(width: 500, height: 500)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedApp: MiniApp = .fogNote

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

            Section("Notch Size") {
                Picker("Configure for", selection: $selectedApp) {
                    ForEach(MiniApp.allCases) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
                .pickerStyle(.segmented)

                let currentPreset = settings.presetForApp(selectedApp)
                let currentSize = settings.sizeForApp(selectedApp)
                let maxSafe = SettingsManager.screenSafeMaxSize()

                // Show screen bounds info
                HStack {
                    Image(systemName: "display")
                        .foregroundColor(.secondary)
                    Text("Screen max: \(Int(maxSafe.width))×\(Int(maxSafe.height))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if NotchSizePreset.large.isClamped || NotchSizePreset.extraLarge.isClamped {
                        Label("Some presets clamped", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Picker("Size Preset", selection: presetBinding) {
                    ForEach(NotchSizePreset.allCases.filter { $0 != .custom }) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                    // Only show Custom option if currently using custom size (read-only indicator)
                    if currentPreset == .custom {
                        Text("Custom").tag(NotchSizePreset.custom)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Width: \(Int(currentSize.width))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(SettingsManager.minNotchWidth)) - \(Int(maxSafe.width))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: widthBinding,
                        in: SettingsManager.minNotchWidth...maxSafe.width,
                        step: 10
                    )

                    HStack {
                        Text("Height: \(Int(currentSize.height))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(SettingsManager.minNotchHeight)) - \(Int(maxSafe.height))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: heightBinding,
                        in: SettingsManager.minNotchHeight...maxSafe.height,
                        step: 10
                    )
                }
                .disabled(currentPreset != .custom)
                .opacity(currentPreset == .custom ? 1.0 : 0.5)

                HStack {
                    Button("Reset All Apps to Default") {
                        settings.resetAllSizesToDefault()
                    }
                    .foregroundColor(.orange)

                    Spacer()

                    Text("Drag bottom-right corner of notch to resize")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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

    private var presetBinding: Binding<NotchSizePreset> {
        Binding(
            get: { settings.presetForApp(selectedApp) },
            set: { newPreset in
                // Custom is a computed state (not a selectable preset)
                // Only apply if it's an actual preset
                guard newPreset != .custom else { return }
                settings.applyPreset(newPreset, to: selectedApp)
            }
        )
    }

    private var widthBinding: Binding<CGFloat> {
        Binding(
            get: { settings.sizeForApp(selectedApp).width },
            set: { newWidth in
                let currentSize = settings.sizeForApp(selectedApp)
                settings.setSize(CGSize(width: newWidth, height: currentSize.height), for: selectedApp)
            }
        )
    }

    private var heightBinding: Binding<CGFloat> {
        Binding(
            get: { settings.sizeForApp(selectedApp).height },
            set: { newHeight in
                let currentSize = settings.sizeForApp(selectedApp)
                settings.setSize(CGSize(width: currentSize.width, height: newHeight), for: selectedApp)
            }
        )
    }
}

struct WorktreeSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
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
    @ObservedObject private var settings = SettingsManager.shared
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
    @ObservedObject private var settings = SettingsManager.shared

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
