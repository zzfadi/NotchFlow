import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        Group {
            if let plugin = navigationState.activePlugin {
                plugin.makeView()
            } else {
                // Fallback if no plugin found
                Text("No plugin loaded")
                    .foregroundColor(.secondary)
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
