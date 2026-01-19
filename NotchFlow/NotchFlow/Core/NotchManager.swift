import Foundation
import SwiftUI
import AppKit
import DynamicNotchKit

@MainActor
class NotchManager: ObservableObject {
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
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
        
        setupClickAwayMonitor()
    }
    
    private func setupClickAwayMonitor() {
        // Global monitor: detects clicks outside the app (e.g., on desktop, other apps)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.isExpanded,
                      !SettingsManager.shared.isPinned else { return }
                await self.collapse()
            }
        }
        
        // Local monitor: detects clicks inside the app but outside the notch content
        // This handles clicks on the notch window's transparent/background areas
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self,
                  self.isExpanded,
                  !SettingsManager.shared.isPinned else { return event }
            
            // Check if click is on a window that's not interactive content
            // The event target window being nil or the click being on background triggers collapse
            if let window = event.window, window.contentView?.hitTest(event.locationInWindow) == nil {
                Task { @MainActor in
                    await self.collapse()
                }
            }
            return event // Always pass through the event
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
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        Task {
            await notch?.hide()
        }
    }
}
