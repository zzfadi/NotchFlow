import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        Group {
            switch navigationState.activeApp {
            case .worktree:
                WorktreeView()
            case .aiConfig:
                AIConfigView()
            case .fogNote:
                FogNoteView()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

#Preview {
    ExpandedView()
        .environmentObject(NavigationState())
        .frame(width: 400, height: 250)
        .background(Color.black)
}
