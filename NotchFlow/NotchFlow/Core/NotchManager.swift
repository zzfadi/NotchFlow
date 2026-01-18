import Foundation
import SwiftUI
import AppKit
import DynamicNotchKit

@MainActor
class NotchManager: ObservableObject {
    private var notch: DynamicNotch<AnyView, EmptyView, EmptyView>?
    @Published var isExpanded: Bool = false
    @Published var navigationState = NavigationState()

    func initialize() {
        let navState = self.navigationState
        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .auto
        ) {
            AnyView(
                MainNotchView()
                    .environmentObject(navState)
            )
        }
    }

    func expand() async {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        await notch?.expand(on: screen)
        isExpanded = true
    }

    func collapse() async {
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
