import Foundation
import SwiftUI
import AppKit
import DynamicNotchKit

@MainActor
class NotchManager: ObservableObject {
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    @Published var isExpanded: Bool = false
    @Published var navigationState = NavigationState()

    func initialize() {
        let navState = self.navigationState
        let settings = SettingsManager.shared
        
        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .auto
        ) {
            AnyView(
                MainNotchView()
                    .environmentObject(navState)
            )
        } compactLeading: {
            // Compact leading - show app icon, click to expand
            AnyView(
                Image(systemName: "rectangle.topthird.inset.filled")
                    .foregroundStyle(settings.accentColor)
                    .onTapGesture {
                        NotificationCenter.default.post(name: .showNotch, object: nil)
                    }
            )
        } compactTrailing: {
            AnyView(EmptyView())
        }
    }

    func expand() async {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        await notch?.expand(on: screen)
        isExpanded = true
    }

    func collapse() async {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // Go to compact mode instead of fully hiding - this keeps a clickable icon
        await notch?.compact(on: screen)
        isExpanded = false
    }
    
    func hide() async {
        await notch?.hide()
        isExpanded = false
    }

    func toggle() async {
        if isExpanded {
            await collapse()
        } else {
            await expand()
        }
    }

    func cleanup() {
        Task {
            await notch?.hide()
        }
    }
}
