import Foundation
import SwiftUI
import DynamicNotchKit

@MainActor
class NotchManager: ObservableObject {
    private var notch: DynamicNotch?
    @Published var isExpanded: Bool = false
    @Published var navigationState = NavigationState()

    func initialize() {
        notch = DynamicNotch(contentID: .init("notchflow")) {
            MainNotchView()
                .environmentObject(self.navigationState)
        }
    }

    func expand() async {
        await notch?.show(on: .screenWithMouse)
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
