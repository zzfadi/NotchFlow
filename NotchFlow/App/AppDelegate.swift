import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var notchManager: NotchManager?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?

    // Store observer tokens to remove them later
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotch()
        setupNotifications()

        // Show the notch after a short delay to ensure window is ready
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await notchManager?.expand()
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
        // If we already have a settings window, just show it
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create a new settings window
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchFlow Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
