import CodexBarNotchPlugin
import SwiftUI

/// Adapter that bridges CodexBarPlugin to NotchFlow's MiniAppPlugin protocol.
/// This allows CodexBar to be registered in NotchFlow's PluginRegistry.
@MainActor
struct CodexBarPluginAdapter: MiniAppPlugin {
    private let codexBar = CodexBarPlugin()

    let id: String
    let displayName: String
    let icon: String
    let description: String

    init() {
        self.id = codexBar.id
        self.displayName = codexBar.displayName
        self.icon = codexBar.icon
        self.description = codexBar.description
    }

    var preferredSize: CGSize {
        codexBar.preferredSize
    }

    var accentColor: Color? {
        codexBar.accentColor
    }

    func makeView() -> AnyView {
        AnyView(codexBar.makeView())
    }
}
