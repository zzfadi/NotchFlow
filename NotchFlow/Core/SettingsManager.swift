import Foundation
import SwiftUI
import AppKit

// MARK: - Notch Size Preset

@MainActor
enum NotchSizePreset: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case `default` = "Default"
    case large = "Large"
    case extraLarge = "Extra Large"
    case custom = "Custom"

    nonisolated var id: String { rawValue }

    /// Base (unclamped) size for this preset
    var baseSize: CGSize {
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

    /// Screen-safe size, clamped to current display's maximum safe bounds
    var size: CGSize {
        let base = baseSize
        let maxSafe = SettingsManager.screenSafeMaxSize()
        return CGSize(
            width: min(base.width, maxSafe.width),
            height: min(base.height, maxSafe.height)
        )
    }

    /// Returns true if this preset would be clamped on the current screen
    var isClamped: Bool {
        let base = baseSize
        let maxSafe = SettingsManager.screenSafeMaxSize()
        return base.width > maxSafe.width || base.height > maxSafe.height
    }

    /// Description showing clamped size if applicable
    var displayName: String {
        if isClamped {
            let clamped = size
            return "\(rawValue) (max \(Int(clamped.width))×\(Int(clamped.height)))"
        }
        return rawValue
    }

    static func preset(for size: CGSize) -> NotchSizePreset {
        // Check against clamped sizes (what's actually applied)
        for preset in [NotchSizePreset.compact, .default, .large, .extraLarge] {
            let presetSize = preset.size
            if abs(presetSize.width - size.width) < 1 && abs(presetSize.height - size.height) < 1 {
                return preset
            }
        }
        return .custom
    }
}

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Size Constraints (nonisolated for use outside MainActor)

    nonisolated static let minNotchWidth: CGFloat = 280
    nonisolated static let minNotchHeight: CGFloat = 180

    /// Absolute maximum values (for displays that can support them)
    nonisolated static let absoluteMaxNotchWidth: CGFloat = 1000
    nonisolated static let absoluteMaxNotchHeight: CGFloat = 700

    /// Padding to keep content safely within DynamicNotchKit's window bounds
    nonisolated private static let windowPaddingWidth: CGFloat = 40
    nonisolated private static let windowPaddingHeight: CGFloat = 60
    
    /// Returns the maximum safe size based on current screen dimensions.
    /// DynamicNotchKit creates windows at 85% of screen size, so we must stay within those bounds.
    static func screenSafeMaxSize(for screen: NSScreen? = NSScreen.main) -> CGSize {
        guard let screen = screen else {
            print("[SettingsManager] Warning: No screen available, using fallback size 600x400")
            return CGSize(width: 600, height: 400)
        }

        // DynamicNotchKit uses screen.frame.width * 0.85 and screen.frame.height * 0.85
        let windowFactor: CGFloat = 0.85
        let maxWidth = min(absoluteMaxNotchWidth, (screen.frame.width * windowFactor) - windowPaddingWidth)
        let maxHeight = min(absoluteMaxNotchHeight, (screen.frame.height * windowFactor) - windowPaddingHeight)

        return CGSize(
            width: max(minNotchWidth, maxWidth),
            height: max(minNotchHeight, maxHeight)
        )
    }
    
    /// Dynamic max width based on current screen
    static var maxNotchWidth: CGFloat {
        screenSafeMaxSize().width
    }
    
    /// Dynamic max height based on current screen
    static var maxNotchHeight: CGFloat {
        screenSafeMaxSize().height
    }

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

        // Apple Intelligence / Foundation Models
        static let foundationModelsEnabled = "foundationModelsEnabled"
        static let aiFeaturesFogNote = "aiFeaturesFogNote"
        static let aiFeaturesWorktree = "aiFeaturesWorktree"
        static let aiFeaturesAIConfig = "aiFeaturesAIConfig"
    }

    // MARK: - Published Properties

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("defaultApp") var defaultApp: String = MiniApp.fogNote.rawValue
    @AppStorage("accentColor") var accentColorHex: String = "FF69B4" // Pink
    @AppStorage("isPinned") var isPinned: Bool = false

    // MARK: - Apple Intelligence Settings
    @AppStorage("foundationModelsEnabled") var foundationModelsEnabled: Bool = false
    @AppStorage("aiFeaturesFogNote") var aiFeaturesFogNote: Bool = true
    @AppStorage("aiFeaturesWorktree") var aiFeaturesWorktree: Bool = true
    @AppStorage("aiFeaturesAIConfig") var aiFeaturesAIConfig: Bool = true

    // MARK: - Smart Organization (Invisible AI)
    @AppStorage("autoAnalyzeNotes") var autoAnalyzeNotes: Bool = true

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
        let clamped = Self.clampedSize(size)
        appSizes[app.rawValue] = ["width": clamped.width, "height": clamped.height]
        saveSettings()
    }

    /// Updates size in memory for live UI updates during drag, without persisting to disk.
    /// Call `setSize(_:for:)` when the drag ends to persist.
    func updateSizeWithoutSaving(_ size: CGSize, for app: MiniApp) {
        let clamped = Self.clampedSize(size)
        appSizes[app.rawValue] = ["width": clamped.width, "height": clamped.height]
    }
    
    /// Clamps a size to the current screen's safe bounds
    static func clampedSize(_ size: CGSize) -> CGSize {
        let maxSafe = screenSafeMaxSize()
        return CGSize(
            width: max(minNotchWidth, min(maxSafe.width, size.width)),
            height: max(minNotchHeight, min(maxSafe.height, size.height))
        )
    }
    
    /// Validates and clamps the current size for an app (useful after screen changes)
    func validateSizeForCurrentScreen(_ app: MiniApp) {
        let currentSize = sizeForApp(app)
        let clamped = Self.clampedSize(currentSize)
        if currentSize != clamped {
            print("[SettingsManager] Clamping \(app.rawValue) from \(Int(currentSize.width))x\(Int(currentSize.height)) to \(Int(clamped.width))x\(Int(clamped.height))")
            setSize(clamped, for: app)
        }
    }

    func presetForApp(_ app: MiniApp) -> NotchSizePreset {
        return NotchSizePreset.preset(for: sizeForApp(app))
    }

    func applyPreset(_ preset: NotchSizePreset, to app: MiniApp) {
        if preset != .custom {
            // Defer the state change to the next run loop tick to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.setSize(preset.size, for: app)
            }
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
