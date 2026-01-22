import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let hideNotch = Notification.Name("hideNotch")
    static let showNotch = Notification.Name("showNotch")
    static let showSettings = Notification.Name("showSettings")
}

// MARK: - Navigation State

@MainActor
class NavigationState: ObservableObject {
    /// Current active plugin ID (string-based for dynamic plugins)
    @Published var activeAppId: String = "fogNote"
    @Published var isExpanded: Bool = false

    /// Get the currently active plugin from the registry
    var activePlugin: (any MiniAppPlugin)? {
        PluginRegistry.shared.plugin(for: activeAppId)
    }

    /// Switch to a plugin by ID with lifecycle callbacks
    func switchTo(_ pluginId: String) {
        guard pluginId != activeAppId else { return }

        // Notify old plugin it's being deactivated
        activePlugin?.onDeactivate()

        withAnimation(.easeInOut(duration: 0.2)) {
            activeAppId = pluginId
        }

        // Notify new plugin it's now active
        activePlugin?.onActivate()
    }

    /// Switch to a plugin directly
    func switchTo(_ plugin: any MiniAppPlugin) {
        switchTo(plugin.id)
    }

    func expand() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = true
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }

    func toggle() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
}
