import SwiftUI

struct MainNotchView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with mini-app icons
            HStack(spacing: 12) {
                // Left side - Worktree button
                TabButton(
                    app: .worktree,
                    isActive: navigationState.activeApp == .worktree
                ) {
                    navigationState.switchTo(.worktree)
                }

                Spacer()

                // Right side - AI Config and Fog Note buttons
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content area
            ExpandedView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
        )
    }
}

struct TabButton: View {
    let app: MiniApp
    let isActive: Bool
    let action: () -> Void

    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: app.icon)
                    .font(.system(size: 14, weight: .medium))

                if isActive {
                    Text(app.rawValue)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(isActive ? settings.accentColor : .gray)
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
