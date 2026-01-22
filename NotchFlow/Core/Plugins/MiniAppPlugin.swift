import SwiftUI

/// Protocol that all mini apps must conform to (built-in and external plugins).
///
/// This protocol enables a dynamic plugin architecture where mini apps can be
/// registered at runtime rather than hardcoded in switch statements.
@MainActor
public protocol MiniAppPlugin: Identifiable, Sendable {
    /// Unique identifier for the app (e.g., "worktree", "codexBar")
    var id: String { get }

    /// Display name shown in tab bar tooltips and settings
    var displayName: String { get }

    /// SF Symbol name for the tab icon
    var icon: String { get }

    /// Short description for accessibility and tooltips
    var description: String { get }

    /// The main view for this mini app
    @ViewBuilder
    func makeView() -> AnyView

    /// Optional settings view for the settings panel
    @ViewBuilder
    func makeSettingsView() -> AnyView?

    /// Called when the app becomes the active tab
    func onActivate()

    /// Called when switching away from this app
    func onDeactivate()

    /// Default size for this app's expanded view
    var preferredSize: CGSize { get }

    /// Accent color for this plugin (uses system accent if nil)
    var accentColor: Color? { get }
}

// MARK: - Default Implementations

public extension MiniAppPlugin {
    func onActivate() {}
    func onDeactivate() {}

    var preferredSize: CGSize {
        CGSize(width: 600, height: 400)
    }

    var accentColor: Color? { nil }

    func makeSettingsView() -> AnyView? { nil }
}
