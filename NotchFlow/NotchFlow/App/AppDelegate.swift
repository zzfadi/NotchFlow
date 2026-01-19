import AppKit
import SwiftUI
import DynamicNotchKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var notchManager: NotchManager?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotch()
        
        // Show the notch after a short delay to ensure window is ready
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await notchManager?.expand()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchManager?.cleanup()
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
        // Activate the app and open the Settings window
        NSApp.activate(ignoringOtherApps: true)
        // Use SettingsLink behavior - this selector is available on macOS 13+
        // and is the standard way SwiftUI Settings scenes are opened
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
