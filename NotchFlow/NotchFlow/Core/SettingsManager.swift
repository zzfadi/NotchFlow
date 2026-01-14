import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - User Defaults Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let defaultApp = "defaultApp"
        static let worktreeScanPaths = "worktreeScanPaths"
        static let aiConfigScanPaths = "aiConfigScanPaths"
        static let fogNotesDirectory = "fogNotesDirectory"
        static let accentColor = "accentColor"
    }

    // MARK: - Published Properties

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("defaultApp") var defaultApp: String = MiniApp.fogNote.rawValue
    @AppStorage("accentColor") var accentColorHex: String = "FF69B4" // Pink

    @Published var worktreeScanPaths: [String] = []
    @Published var aiConfigScanPaths: [String] = []
    @Published var fogNotesDirectory: String = ""

    // MARK: - Computed Properties

    var defaultMiniApp: MiniApp {
        get { MiniApp(rawValue: defaultApp) ?? .fogNote }
        set { defaultApp = newValue.rawValue }
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .pink
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
    }

    // MARK: - Methods

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load worktree scan paths
        if let paths = defaults.stringArray(forKey: Keys.worktreeScanPaths) {
            worktreeScanPaths = paths
        } else {
            worktreeScanPaths = defaultWorktreePaths()
        }

        // Load AI config scan paths
        if let paths = defaults.stringArray(forKey: Keys.aiConfigScanPaths) {
            aiConfigScanPaths = paths
        } else {
            aiConfigScanPaths = defaultAIConfigPaths()
        }

        // Load fog notes directory
        if let dir = defaults.string(forKey: Keys.fogNotesDirectory), !dir.isEmpty {
            fogNotesDirectory = dir
        } else {
            fogNotesDirectory = defaultFogNotesDirectory()
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(worktreeScanPaths, forKey: Keys.worktreeScanPaths)
        defaults.set(aiConfigScanPaths, forKey: Keys.aiConfigScanPaths)
        defaults.set(fogNotesDirectory, forKey: Keys.fogNotesDirectory)
    }

    func resetToDefaults() {
        worktreeScanPaths = defaultWorktreePaths()
        aiConfigScanPaths = defaultAIConfigPaths()
        fogNotesDirectory = defaultFogNotesDirectory()
        launchAtLogin = false
        defaultApp = MiniApp.fogNote.rawValue
        accentColorHex = "FF69B4"
        saveSettings()
    }

    // MARK: - Default Values

    private func defaultWorktreePaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            home,
            "\(home)/Developer",
            "\(home)/Projects",
            "\(home)/Code",
            "\(home)/Repos",
            "\(home)/GitHub"
        ]
    }

    private func defaultAIConfigPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            home,
            "\(home)/Developer",
            "\(home)/Projects",
            "\(home)/Code"
        ]
    }

    private func defaultFogNotesDirectory() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Documents/FogNotes"
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = NSColor(self).cgColor.components else {
            return "000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
