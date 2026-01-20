import SwiftUI
import AppKit

struct MainNotchView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var settings = SettingsManager.shared

    private var currentSize: CGSize {
        settings.sizeForApp(navigationState.activeApp)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with mini-app icons
            HStack(spacing: 12) {
                // Pin toggle button
                PinButton()
                
                // Left side - Worktree button
                TabButton(
                    app: .worktree,
                    isActive: navigationState.activeApp == .worktree
                ) {
                    navigationState.switchTo(.worktree)
                }

                Spacer()

                // Right side - AI Config, Fog Note, and Ralph buttons
                TabButton(
                    app: .aiConfig,
                    isActive: navigationState.activeApp == .aiConfig
                ) {
                    navigationState.switchTo(.aiConfig)
                }

                TabButton(
                    app: .fogNote,
                    isActive: navigationState.activeApp == .fogNote
                ) {
                    navigationState.switchTo(.fogNote)
                }

                TabButton(
                    app: .ralphWiggum,
                    isActive: navigationState.activeApp == .ralphWiggum
                ) {
                    navigationState.switchTo(.ralphWiggum)
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
            NotchBottomBar(currentApp: navigationState.activeApp)
        }
        .frame(width: currentSize.width, height: currentSize.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentSize)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
        )
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            // Validate and clamp sizes when screen configuration changes
            for app in MiniApp.allCases {
                settings.validateSizeForCurrentScreen(app)
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

struct TabButton: View {
    let app: MiniApp
    let isActive: Bool
    let action: () -> Void

    @ObservedObject private var settings = SettingsManager.shared

    private var iconColor: Color {
        isActive ? settings.accentColor : .gray
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Use custom icon if available, otherwise use SF Symbol
                if let customIcon = app.customIcon {
                    Image(customIcon, bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: app.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)
                }

                if isActive {
                    Text(app.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(iconColor)
                }
            }
            .padding(.horizontal, isActive ? 12 : 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? settings.accentColor.opacity(0.2) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .help(app.description)
    }
}

#Preview {
    MainNotchView()
        .environmentObject(NavigationState())
}
