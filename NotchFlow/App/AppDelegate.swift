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
            // Normal path — reveal the notch shortly after the window is ready
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await notchManager?.expand()
            }
        } else {
            // First launch (or user asked to redo onboarding) — show the
            // welcome window instead of the notch. The notch expands when
            // onboarding finishes.
            showOnboardingWindow()
        }
    }

    /// Kick off every mini-app's expensive-to-load data in the background
    /// immediately at launch, so clicking a tab for the first time doesn't
    /// block on a disk walk or manifest fetch. Each scanner is a singleton
    /// and publishes results back on the main actor when done.
    private func prewarmMiniAppState() {
        // Touch the singletons once to force initialization. Their inits
        // kick off their own background loading (NoteStorage loads from
        // disk, LocalPluginSynthesizer starts its AIConfigScanner scan).
        _ = NoteStorage.shared
        _ = LocalPluginSynthesizer.shared

        // Worktree + remote marketplaces don't auto-scan on init, so fire
        // them explicitly. scan() / refreshAll() internally dispatch the
        // expensive work off the main actor.
        WorktreeScanner.shared.scan()
        Task {
            await MetaMarketplaceStore.shared.refreshAll()
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

        window.level = .floating
        window.orderFrontRegardless()
        window.makeKey()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak window] in
            window?.level = .normal
        }

        onboardingWindow = window
    }

    private func finishOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            await notchManager?.expand()
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
            window.level = .floating
            window.orderFrontRegardless()
            window.makeKey()
            // Reset level after a brief delay so it behaves normally once focused
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak window] in
                window?.level = .normal
            }
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

        // Bring to front reliably
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKey()

        // Reset level after a brief delay so it behaves normally once focused
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak window] in
            window?.level = .normal
        }

        settingsWindow = window
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
