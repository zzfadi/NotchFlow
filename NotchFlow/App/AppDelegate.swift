import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var notchManager: NotchManager?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    // Store observer tokens to remove them later
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotch()
        setupNotifications()
        prewarmMiniAppState()

        if SettingsManager.shared.onboardingComplete {
            // Yield one run-loop tick before expanding so AppKit finishes
            // processing `applicationDidFinishLaunching` and any pending
            // window setup inside DynamicNotchKit. Prior implementation
            // used a hardcoded 500ms sleep, which was wall-clock-based and
            // broke on cold boots / slow hardware; `Task { @MainActor }`
            // is a scheduler-based yield that scales to whatever the
            // system actually needs.
            Task { @MainActor in
                await self.notchManager?.expand()
            }
        } else {
            // First launch (or user asked to redo onboarding) — show the
            // welcome window instead of the notch. The notch expands when
            // onboarding finishes.
            showOnboardingWindow()
        }
    }

    /// Kick off every registered mini-app's prewarm hook. Each mini-app
    /// decides what "prewarm" means for itself (touch a singleton, scan
    /// disk, refresh marketplaces). Iterating the registry means adding a
    /// new tab wires up prewarm automatically — no edits needed here.
    private func prewarmMiniAppState() {
        for app in MiniAppRegistry.all {
            app.prewarm()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Remove all notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        notchManager?.cleanup()
    }

    // MARK: - Notification Setup

    private func setupNotifications() {
        let hideObserver = NotificationCenter.default.addObserver(
            forName: .hideNotch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.notchManager?.collapse()
            }
        }
        notificationObservers.append(hideObserver)

        let showObserver = NotificationCenter.default.addObserver(
            forName: .showNotch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.notchManager?.expand()
            }
        }
        notificationObservers.append(showObserver)

        let settingsObserver = NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showPreferences()
            }
        }
        notificationObservers.append(settingsObserver)

        let onboardingObserver = NotificationCenter.default.addObserver(
            forName: .showOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOnboardingWindow()
            }
        }
        notificationObservers.append(onboardingObserver)
    }

    // MARK: - Onboarding

    @objc func showOnboardingWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = onboardingWindow, window.isVisible {
            window.orderFrontRegardless()
            window.makeKey()
            return
        }

        // Hide the notch while onboarding is up so the user isn't distracted
        Task { await notchManager?.collapse() }

        let onboardingView = OnboardingView { [weak self] in
            self?.finishOnboarding()
        }
        let hostingController = NSHostingController(rootView: onboardingView)
        hostingController.view.autoresizingMask = [
            NSView.AutoresizingMask.width,
            NSView.AutoresizingMask.height
        ]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to NotchFlow"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 540, height: 460)

        window.delegate = self
        // Assign the tracked property FIRST. `bringWindowForwardThenReset`
        // calls `makeKey()`, which can fire `windowDidBecomeKey(_:)`
        // synchronously — that callback guards on `window ==
        // onboardingWindow`, so the property must already point at this
        // window when the callback runs.
        onboardingWindow = window
        bringWindowForwardThenReset(window)
    }

    private func finishOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil

        // Same rationale as in `applicationDidFinishLaunching` — yield one
        // run-loop tick after closing the onboarding window so the notch
        // window has a clean frame to animate into, without the previous
        // 250ms wall-clock sleep.
        Task { @MainActor in
            await self.notchManager?.expand()
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "NotchFlow")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show Notch", action: #selector(showNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Hide Notch", action: #selector(hideNotch), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchFlow", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Notch Setup

    private func setupNotch() {
        notchManager = NotchManager()
        notchManager?.initialize()
    }

    // MARK: - Menu Actions

    @objc func showNotch() {
        Task {
            await notchManager?.expand()
        }
    }

    @objc func hideNotch() {
        Task {
            await notchManager?.collapse()
        }
    }

    @objc func showPreferences() {
        // Activate app FIRST - critical for menu bar apps
        NSApp.activate(ignoringOtherApps: true)

        // If we already have a settings window, just bring it forward
        if let window = settingsWindow, window.isVisible {
            bringWindowForwardThenReset(window)
            return
        }

        // Create a new settings window with modern styling
        let settingsView = ModernSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        // Configure hosting view for proper resize behavior
        hostingController.view.autoresizingMask = [
            NSView.AutoresizingMask.width,
            NSView.AutoresizingMask.height
        ]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchFlow Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 580, height: 400)

        // Modern System Settings appearance
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified

        // Empty toolbar for proper titlebar height
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar

        window.delegate = self
        // Same ordering as the onboarding window: assign before the make-
        // key dance so `windowDidBecomeKey(_:)` finds the reference if it
        // fires synchronously.
        settingsWindow = window
        bringWindowForwardThenReset(window)
    }

    /// Bring `window` to the front by briefly raising its `level` to
    /// `.floating`, then reset to `.normal` **once it actually becomes
    /// key** via `NSWindowDelegate.windowDidBecomeKey(_:)`.
    ///
    /// Replaces the earlier `DispatchQueue.main.asyncAfter(deadline: .now()
    /// + 0.1)` dance, which was a wall-clock gamble that broke on slow
    /// systems. The window itself tells us when it's ready — that's the
    /// right signal.
    private func bringWindowForwardThenReset(_ window: NSWindow) {
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKey()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    /// When one of our floated-to-front windows (settings or onboarding)
    /// actually becomes key, reset its level to `.normal` so it behaves
    /// like an ordinary window thereafter. This used to be a timed
    /// `asyncAfter(0.1)` gamble — now it's event-driven, so it keeps
    /// working on slow hardware / cold boot / heavy app startup.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.level == .floating,
              window == settingsWindow || window == onboardingWindow
        else { return }
        window.level = .normal
    }

    /// Clean up our tracked references when the user closes a window. Keeps
    /// the `settingsWindow` / `onboardingWindow` properties from holding a
    /// stale reference that would trip up the "already visible" fast-path
    /// in `showPreferences()`.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow { settingsWindow = nil }
        if window == onboardingWindow { onboardingWindow = nil }
    }
}
