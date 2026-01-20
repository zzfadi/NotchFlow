import SwiftUI

/// Appearance settings section - visual customization
struct AppearanceSettingsSection: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedApp: MiniApp = .fogNote

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

                        // App selector
                        Picker("Configure for", selection: $selectedApp) {
                            ForEach(MiniApp.allCases) { app in
                                Text(app.rawValue).tag(app)
                            }
                        }
                        .pickerStyle(.segmented)

                        let currentPreset = settings.presetForApp(selectedApp)
                        let currentSize = settings.sizeForApp(selectedApp)
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
            get: { settings.presetForApp(selectedApp) },
            set: { newPreset in
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

#Preview {
    AppearanceSettingsSection()
        .frame(width: 450, height: 600)
}
