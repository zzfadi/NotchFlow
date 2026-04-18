import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let hideNotch = Notification.Name("hideNotch")
    static let showNotch = Notification.Name("showNotch")
    static let showSettings = Notification.Name("showSettings")
    static let showOnboarding = Notification.Name("showOnboarding")
}

/// `activeApp` holds the **id** of the active mini-app, not the mini-app
/// struct itself. Using the ID lets us persist / publish a plain `String`
/// without dragging the full registry through every consumer — the registry
/// resolves IDs to concrete mini-apps at render/prewarm time.
@MainActor
class NavigationState: ObservableObject {
    @Published var activeApp: String = MiniAppRegistry.defaultApp.id
    @Published var isExpanded: Bool = false

    func switchTo(_ app: any MiniApp) {
        switchTo(id: app.id)
    }

    func switchTo(id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeApp = id
        }
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
