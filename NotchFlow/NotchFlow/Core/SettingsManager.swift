import Foundation
import SwiftUI

// MARK: - Notch Size Preset

enum NotchSizePreset: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case `default` = "Default"
    case large = "Large"
    case extraLarge = "Extra Large"
    case custom = "Custom"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .compact:
            return CGSize(width: 400, height: 280)
        case .default:
            return CGSize(width: 600, height: 400)
        case .large:
            return CGSize(width: 800, height: 550)
        case .extraLarge:
            return CGSize(width: 1000, height: 700)
        case .custom:
            return CGSize(width: 600, height: 400) // Fallback, actual custom size stored separately
        }
    }

    static func preset(for size: CGSize) -> NotchSizePreset {
        for preset in [NotchSizePreset.compact, .default, .large, .extraLarge] {
            if abs(preset.size.width - size.width) < 1 && abs(preset.size.height - size.height) < 1 {
                return preset
            }
        }
        return .custom
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Size Constraints

    static let minNotchWidth: CGFloat = 280
    static let maxNotchWidth: CGFloat = 1000
    static let minNotchHeight: CGFloat = 180
    static let maxNotchHeight: CGFloat = 700

    // MARK: - User Defaults Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let defaultApp = "defaultApp"
        static let worktreeScanPaths = "worktreeScanPaths"
        static let aiConfigScanPaths = "aiConfigScanPaths"
        static let fogNotesDirectory = "fogNotesDirectory"
        static let accentColor = "accentColor"
        static let appSizes = "appSizes"
        static let isPinned = "isPinned"
    }

    // MARK: - Published Properties

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("defaultApp") var defaultApp: String = MiniApp.fogNote.rawValue
    @AppStorage("accentColor") var accentColorHex: String = "FF69B4" // Pink
    @AppStorage("isPinned") var isPinned: Bool = false

    @Published var worktreeScanPaths: [String] = []
    @Published var aiConfigScanPaths: [String] = []
    @Published var fogNotesDirectory: String = ""
    @Published var appSizes: [String: [String: CGFloat]] = [:]

    // MARK: - Computed Properties

    var defaultMiniApp: MiniApp {
        get { MiniApp(rawValue: defaultApp) ?? .fogNote }
        set { defaultApp = newValue.rawValue }
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .pink
    }

    // MARK: - Per-App Size Methods

    func sizeForApp(_ app: MiniApp) -> CGSize {
        if let sizeDict = appSizes[app.rawValue],
           let width = sizeDict["width"],
           let height = sizeDict["height"] {
            return CGSize(width: width, height: height)
        }
        return NotchSizePreset.default.size
    }

    func setSize(_ size: CGSize, for app: MiniApp) {
        let clampedWidth = max(Self.minNotchWidth, min(Self.maxNotchWidth, size.width))
        let clampedHeight = max(Self.minNotchHeight, min(Self.maxNotchHeight, size.height))
        appSizes[app.rawValue] = ["width": clampedWidth, "height": clampedHeight]
        saveSettings()
    }

    /// Updates size in memory for live UI updates during drag, without persisting to disk.
    /// Call `setSize(_:for:)` when the drag ends to persist.
    func updateSizeWithoutSaving(_ size: CGSize, for app: MiniApp) {
        let clampedWidth = max(Self.minNotchWidth, min(Self.maxNotchWidth, size.width))
        let clampedHeight = max(Self.minNotchHeight, min(Self.maxNotchHeight, size.height))
        appSizes[app.rawValue] = ["width": clampedWidth, "height": clampedHeight]
    }

    func presetForApp(_ app: MiniApp) -> NotchSizePreset {
        return NotchSizePreset.preset(for: sizeForApp(app))
    }

    func applyPreset(_ preset: NotchSizePreset, to app: MiniApp) {
        if preset != .custom {
            setSize(preset.size, for: app)
        }
    }

    func resetAllSizesToDefault() {
        appSizes = [:]
        saveSettings()
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

        // Load per-app sizes
        if let sizesData = defaults.dictionary(forKey: Keys.appSizes) as? [String: [String: CGFloat]] {
            appSizes = sizesData
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(worktreeScanPaths, forKey: Keys.worktreeScanPaths)
        defaults.set(aiConfigScanPaths, forKey: Keys.aiConfigScanPaths)
        defaults.set(fogNotesDirectory, forKey: Keys.fogNotesDirectory)
        defaults.set(appSizes, forKey: Keys.appSizes)
    }

    func resetToDefaults() {
        worktreeScanPaths = defaultWorktreePaths()
        aiConfigScanPaths = defaultAIConfigPaths()
        fogNotesDirectory = defaultFogNotesDirectory()
        launchAtLogin = false
        defaultApp = MiniApp.fogNote.rawValue
        accentColorHex = "FF69B4"
        appSizes = [:]
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
        // Convert to sRGB color space to ensure consistent RGB component extraction
        // First get NSColor, then convert to sRGB to handle extended color spaces properly
        let nsColor = NSColor(self)
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "FF69B4" // Default pink if color space conversion fails
        }

        // Extract RGB components using NSColor's component accessors for reliability
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(max(0, min(255, red * 255)))
        let g = Int(max(0, min(255, green * 255)))
        let b = Int(max(0, min(255, blue * 255)))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
