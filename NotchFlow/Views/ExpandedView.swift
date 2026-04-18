import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        // Every registered mini-app stays mounted so tab switches don't
        // destroy scanner state or scroll position. Only the active tab is
        // visible and hit-testable. Iterating the registry is what makes a
        // new tab cost exactly one struct in MiniAppRegistry.all — no new
        // switch arm here, no changes in MainNotchView beyond the tab bar.
        ZStack {
            ForEach(MiniAppRegistry.all, id: \.id) { app in
                app.makeView()
                    .opacity(navigationState.activeApp == app.id ? 1 : 0)
                    .allowsHitTesting(navigationState.activeApp == app.id)
            }
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
