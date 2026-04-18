import Foundation

/// Protocols that describe the bits of `SettingsManager` / `PermissionManager`
/// the scanners need at runtime.
///
/// The surface is **intentionally tiny** — exactly what the scanners read,
/// nothing more. A broader protocol would invite leaking UI state into tests
/// and drag along irrelevant dependencies.
///
/// Scanners accept these by init parameter, defaulted to the real singletons,
/// so production call sites are unchanged. Tests inject fakes.
///
/// ```
/// // production — default parameter
/// let scanner = AIConfigScanner()
///
/// // test — inject fakes
/// let scanner = AIConfigScanner(
///     settings: FakeSettings(aiConfigScanPaths: ["/tmp/fixtures"]),
///     permissions: FakePermissions(grantedFolders: [])
/// )
/// ```
///
/// The protocols are `AnyObject` because the concrete types (`SettingsManager`
/// / `PermissionManager`) are reference types and scanners hold them weakly
/// is a non-goal — they're singletons that outlive any scanner.
@MainActor
protocol SettingsProviding: AnyObject {
    var aiConfigScanPaths: [String] { get }
    var worktreeScanPaths: [String] { get }
    var fogNotesDirectory: String { get }
}

@MainActor
protocol PermissionsProviding: AnyObject {
    var grantedFolders: [GrantedFolder] { get }
}

// MARK: - Conformances

extension SettingsManager: SettingsProviding {}
extension PermissionManager: PermissionsProviding {}

// MARK: - Platform seams
//
// Scanners and stores reach into the home directory and the filesystem
// directly today, which makes unit tests either skip the side-effectful
// code paths entirely or fight with real disk state. These protocols are
// thin wrappers — just the calls we actually make — so tests can inject
// a fake tree without touching the user's machine.

/// Hands back the home directory. Production uses
/// `FileManager.default.homeDirectoryForCurrentUser`; tests substitute a
/// temp dir that looks like a fake `$HOME`.
protocol HomeDirectoryProviding: Sendable {
    var home: URL { get }
}

struct DefaultHomeDirectoryProvider: HomeDirectoryProviding {
    var home: URL { FileManager.default.homeDirectoryForCurrentUser }
}

/// The filesystem calls our scanners / plugin discovery actually make.
/// Kept narrow on purpose — if a call site needs something else, add it
/// here explicitly rather than leaking `FileManager` access.
protocol FileSystemProviding: Sendable {
    func fileExists(at url: URL) -> Bool
    func directoryExists(at url: URL) -> Bool
    func contentsOfDirectory(at url: URL) -> [URL]
    func readString(at url: URL) -> String?
    func attributes(at url: URL) -> [FileAttributeKey: Any]?
}

struct DefaultFileSystem: FileSystemProviding {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            && isDir.boolValue
    }

    func contentsOfDirectory(at url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    func readString(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    func attributes(at url: URL) -> [FileAttributeKey: Any]? {
        try? FileManager.default.attributesOfItem(atPath: url.path)
    }
}

/// The subset of `UserDefaults` our stores actually use. Lets
/// `MetaMarketplaceStore` tests round-trip persistence without touching
/// the shared suite that holds the user's real settings.
protocol DefaultsStoring: AnyObject {
    func stringArray(forKey key: String) -> [String]?
    func setStringArray(_ value: [String], forKey key: String)
}

/// Production implementation wrapping `UserDefaults.standard`. Marked
/// `@unchecked Sendable` because all mutable state is inside
/// `UserDefaults`, which is itself thread-safe for reads and writes.
final class SystemDefaultsStore: DefaultsStoring, @unchecked Sendable {
    static let shared = SystemDefaultsStore()

    func stringArray(forKey key: String) -> [String]? {
        UserDefaults.standard.stringArray(forKey: key)
    }

    func setStringArray(_ value: [String], forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
