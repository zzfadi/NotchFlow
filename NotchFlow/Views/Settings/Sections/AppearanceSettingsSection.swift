import SwiftUI

/// Appearance settings section - visual customization
struct AppearanceSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var pluginRegistry = PluginRegistry.shared
    @State private var selectedPluginId: String = "fogNote"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "paintpalette",
                    title: "Appearance",
                    subtitle: "Customize how NotchFlow looks",
                    accentColor: .purple
                )

                // Accent color
                GroupBox {
                    HStack {
                        Label("Accent Color", systemImage: "paintbrush.fill")
                        Spacer()
                        ColorPicker("", selection: accentColorBinding)
                            .labelsHidden()
                    }
                    .padding(4)
                }

                // Notch size configuration
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Notch Size", systemImage: "rectangle.expand.vertical")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        // Plugin selector
                        Picker("Configure for", selection: $selectedPluginId) {
                            ForEach(pluginRegistry.plugins, id: \.id) { plugin in
                                Text(plugin.displayName).tag(plugin.id)
                            }
                        }
                        .pickerStyle(.segmented)

                        let currentPreset = settings.presetForPlugin(selectedPluginId)
                        let currentSize = settings.sizeForPlugin(selectedPluginId)
                        let maxSafe = SettingsManager.screenSafeMaxSize()

                        // Screen bounds info
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

                        // Preset picker
                        Picker("Size Preset", selection: presetBinding) {
                            ForEach(NotchSizePreset.allCases.filter { $0 != .custom }) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                            if currentPreset == .custom {
                                Text("Custom").tag(NotchSizePreset.custom)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Size sliders
                        VStack(alignment: .leading, spacing: 12) {
                            // Width slider
                            VStack(alignment: .leading, spacing: 4) {
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
                            }

                            // Height slider
                            VStack(alignment: .leading, spacing: 4) {
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
                        }
                        .disabled(currentPreset != .custom)
                        .opacity(currentPreset == .custom ? 1.0 : 0.5)

                        // Actions
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
                    .padding(4)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Bindings

    private var accentColorBinding: Binding<Color> {
        Binding(
            get: { settings.accentColor },
            set: { settings.accentColorHex = $0.hexString }
        )
    }

    private var presetBinding: Binding<NotchSizePreset> {
        Binding(
            get: { settings.presetForPlugin(selectedPluginId) },
            set: { newPreset in
                guard newPreset != .custom else { return }
                settings.applyPreset(newPreset, toPlugin: selectedPluginId)
            }
        )
    }

    private var widthBinding: Binding<CGFloat> {
        Binding(
            get: { settings.sizeForPlugin(selectedPluginId).width },
            set: { newWidth in
                let currentSize = settings.sizeForPlugin(selectedPluginId)
                settings.setSizeForPlugin(selectedPluginId, size: CGSize(width: newWidth, height: currentSize.height))
            }
        )
    }

    private var heightBinding: Binding<CGFloat> {
        Binding(
            get: { settings.sizeForPlugin(selectedPluginId).height },
            set: { newHeight in
                let currentSize = settings.sizeForPlugin(selectedPluginId)
                settings.setSizeForPlugin(selectedPluginId, size: CGSize(width: currentSize.width, height: newHeight))
            }
        )
    }
}

#Preview {
    AppearanceSettingsSection()
        .frame(width: 450, height: 600)
}
