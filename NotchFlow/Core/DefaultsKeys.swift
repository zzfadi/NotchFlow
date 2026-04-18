import Foundation

/// Single source of truth for every `UserDefaults` key NotchFlow reads or
/// writes.
///
/// Before this file, keys were defined as string literals at each call site
/// (plus a private `Keys` enum inside `SettingsManager` that only covered the
/// settings-owned keys, with `PermissionManager` and `MetaMarketplaceStore`
/// duplicating their own literals separately). Typos were silent and key
/// renames were grep-and-pray.
///
/// Two conventions:
///
/// 1. **Every key in the app goes here.** This includes `@AppStorage` keys
///    that `SettingsManager` passes as string literals — those literals must
///    match values listed here. A grep over the codebase for `"launchAtLogin"`
///    and friends should return exactly one result: this file and the
///    `@AppStorage` wrapper that matches it.
///
/// 2. **Prefer typed `Defaults.xxx` accessors over raw `UserDefaults.standard`
///    calls.** `@AppStorage` is the exception because the property-wrapper
///    syntax needs the literal inline.
enum DefaultsKeys {
    // MARK: - SettingsManager

    static let launchAtLogin = "launchAtLogin"
    static let defaultApp = "defaultApp"
    static let worktreeScanPaths = "worktreeScanPaths"
    static let aiConfigScanPaths = "aiConfigScanPaths"
    static let fogNotesDirectory = "fogNotesDirectory"
    static let accentColor = "accentColor"
    static let appSizes = "appSizes"
    static let isPinned = "isPinned"
    static let uiScale = "uiScale"
    static let notchTheme = "notchTheme"
    static let onboardingComplete = "onboardingComplete"

    // MARK: - PermissionManager

    static let grantedFolderPaths = "grantedFolderPaths"

    // MARK: - AI Meta

    static let metaMarketplaceURLs = "metaMarketplaceURLs"
}

/// Thin typed wrapper over `UserDefaults.standard` so call sites read as
/// `Defaults.stringArray(DefaultsKeys.foo)` instead of a raw
/// `UserDefaults.standard.stringArray(forKey: "foo")`.
///
/// Keeps `UserDefaults` out of most files and makes every read/write use a
/// named key from `DefaultsKeys`. Only covers the types we currently need;
/// add more accessors as more types show up.
enum Defaults {
    private static var store: UserDefaults { .standard }

    static func string(_ key: String) -> String? {
        store.string(forKey: key)
    }

    static func setString(_ key: String, _ value: String?) {
        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    static func stringArray(_ key: String) -> [String]? {
        store.stringArray(forKey: key)
    }

    static func setStringArray(_ key: String, _ value: [String]) {
        store.set(value, forKey: key)
    }

    static func dictionary(_ key: String) -> [String: Any]? {
        store.dictionary(forKey: key)
    }

    static func setDictionary(_ key: String, _ value: [String: Any]) {
        store.set(value, forKey: key)
    }
}
