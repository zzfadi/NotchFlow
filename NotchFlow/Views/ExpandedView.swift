import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        // All three views stay mounted so tab switches don't destroy
        // scanner state or scroll position. Only the active tab is visible.
        ZStack {
            WorktreeView()
                .opacity(navigationState.activeApp == .worktree ? 1 : 0)
                .allowsHitTesting(navigationState.activeApp == .worktree)

            AIMetaView()
                .opacity(navigationState.activeApp == .aiMeta ? 1 : 0)
                .allowsHitTesting(navigationState.activeApp == .aiMeta)

            FogNoteView()
                .opacity(navigationState.activeApp == .fogNote ? 1 : 0)
                .allowsHitTesting(navigationState.activeApp == .fogNote)
        }
        .animation(.easeInOut(duration: 0.18), value: navigationState.activeApp)
    }
}

#Preview {
    ExpandedView()
        .environmentObject(NavigationState())
        .frame(width: 400, height: 250)
        .background(Color.black)
}
