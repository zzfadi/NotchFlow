import Foundation
import SwiftUI
import AppKit
import DynamicNotchKit

@MainActor
class NotchManager: ObservableObject {
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var isCollapsing = false
    @Published var isExpanded: Bool = false
    @Published var navigationState = NavigationState()

    func initialize() {
        let navState = self.navigationState
        let settings = SettingsManager.shared

        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .hapticFeedback],
            style: .notch  // Always show notch style, even on external monitors without hardware notch
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
        
        if notch == nil {
            print("[NotchManager] Error: Failed to initialize DynamicNotch")
        } else {
            print("[NotchManager] Successfully initialized notch")
        }
        
        setupClickAwayMonitor()
    }
    
    private func setupClickAwayMonitor() {
        // Clean up any existing monitors first to prevent leaks on re-initialization
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }

        // Global monitor: detects clicks outside the app (e.g., on desktop, other apps)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.isExpanded,
                      !self.isCollapsing,
                      !SettingsManager.shared.isPinned else { return }
                self.isCollapsing = true
                await self.collapse()
                self.isCollapsing = false
            }
        }

        // Local monitor: detects clicks inside the app but outside the notch content
        // This handles clicks on the notch window's transparent/background areas
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in
                guard let self = self,
                      self.isExpanded,
                      !self.isCollapsing,
                      !SettingsManager.shared.isPinned,
                      let window = event.window,
                      // Check if click hit a window but missed interactive content (hit background/transparent areas)
                      window.contentView?.hitTest(event.locationInWindow) == nil else { return }
                self.isCollapsing = true
                await self.collapse()
                self.isCollapsing = false
            }
            return event // Always pass through the event
        }

        // Verify monitors were registered successfully
        if globalClickMonitor == nil {
            print("[NotchManager] Warning: Failed to register global click monitor - accessibility permissions may be required")
        }
        if localClickMonitor == nil {
            print("[NotchManager] Warning: Failed to register local click monitor")
        }
    }

    func expand() async {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("[NotchManager] Error: No screen available for expansion")
            return
        }
        guard let notch = notch else {
            print("[NotchManager] Error: Notch not initialized")
            return
        }
        await notch.expand(on: screen)
        isExpanded = true
    }

    func collapse() async {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("[NotchManager] Error: No screen available for collapse")
            return
        }
        guard let notch = notch else {
            print("[NotchManager] Error: Notch not initialized")
            return
        }
        // Go to compact mode instead of fully hiding - this keeps a clickable icon
        await notch.compact(on: screen)
        isExpanded = false
    }

    func hide() async {
        guard let notch = notch else {
            print("[NotchManager] Error: Notch not initialized for hide")
            return
        }
        await notch.hide()
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
