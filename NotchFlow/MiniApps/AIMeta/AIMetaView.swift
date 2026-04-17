import SwiftUI

/// The "AI Meta" mini-app — outer shell for NotchFlow's cross-tool AI
/// component marketplace.
///
/// PR #2 ships the scaffold: the tab is renamed, the model/parser/store
/// types are in place, but the body still delegates to `AIConfigView` so
/// users see no functional regression. Later PRs swap the body for
/// marketplace card/rail UI that consumes `MetaMarketplaceStore`.
struct AIMetaView: View {
    var body: some View {
        AIConfigView()
    }
}

#Preview {
    AIMetaView()
        .environmentObject(NavigationState())
        .frame(width: 500, height: 400)
        .background(Color.black)
}
