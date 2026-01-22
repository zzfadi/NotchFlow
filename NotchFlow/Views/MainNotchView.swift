import SwiftUI
import AppKit

struct MainNotchView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var pluginRegistry = PluginRegistry.shared

    private var currentSize: CGSize {
        settings.sizeForPlugin(navigationState.activeAppId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with mini-app icons
            HStack(spacing: 12) {
                // Pin toggle button
                PinButton()

                // Dynamic plugin tabs from registry
                ForEach(pluginRegistry.plugins, id: \.id) { plugin in
                    PluginTabButton(
                        plugin: plugin,
                        isActive: navigationState.activeAppId == plugin.id
                    ) {
                        navigationState.switchTo(plugin)
                    }

                    // Add spacer after first plugin (worktree) to push rest to right
                    if plugin.id == pluginRegistry.plugins.first?.id {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content area
            ExpandedView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom bar - swipe up to close, drag to resize
            NotchBottomBar(currentPluginId: navigationState.activeAppId)
        }
        .frame(width: currentSize.width, height: currentSize.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentSize)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            // Validate and clamp sizes when screen configuration changes
            for plugin in pluginRegistry.plugins {
                settings.validateSizeForCurrentScreen(plugin.id)
            }
        }
    }
}

struct PinButton: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        Button {
            settings.isPinned.toggle()
        } label: {
            Image(systemName: settings.isPinned ? "pin.fill" : "pin.slash")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(settings.isPinned ? settings.accentColor : .gray)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(settings.isPinned ? settings.accentColor.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(settings.isPinned ? "Unpin (clicking away will close)" : "Pin open (prevents closing when clicking away)")
    }
}

struct PluginTabButton: View {
    let plugin: any MiniAppPlugin
    let isActive: Bool
    let action: () -> Void

    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: plugin.icon)
                    .font(.system(size: 14, weight: .medium))

                if isActive {
                    Text(plugin.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(isActive ? (plugin.accentColor ?? settings.accentColor) : .gray)
            .padding(.horizontal, isActive ? 12 : 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? (plugin.accentColor ?? settings.accentColor).opacity(0.2) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .help(plugin.description)
    }
}

#Preview {
    MainNotchView()
        .environmentObject(NavigationState())
}
