import Foundation
@testable import NotchFlow

/// Stand-in `SettingsProviding` for tests. Holds the three scan-relevant
/// properties the scanners read; UI-facing fields on `SettingsManager` are
/// irrelevant here, which is why the production protocol is narrow.
@MainActor
final class FakeSettings: SettingsProviding {
    var aiConfigScanPaths: [String]
    var worktreeScanPaths: [String]
    var fogNotesDirectory: String

    init(
        aiConfigScanPaths: [String] = [],
        worktreeScanPaths: [String] = [],
        fogNotesDirectory: String = ""
    ) {
        self.aiConfigScanPaths = aiConfigScanPaths
        self.worktreeScanPaths = worktreeScanPaths
        self.fogNotesDirectory = fogNotesDirectory
    }
}

/// Stand-in `PermissionsProviding`.
@MainActor
final class FakePermissions: PermissionsProviding {
    var grantedFolders: [GrantedFolder]

    init(grantedFolders: [GrantedFolder] = []) {
        self.grantedFolders = grantedFolders
    }
}

/// Creates a unique temporary directory for a single test case. Callers own
/// cleanup via `cleanup()` in `tearDown`. Using `NSTemporaryDirectory()` via
/// a UUID subpath keeps fixtures isolated per test run even when run in
/// parallel.
struct TempDirectory {
    let url: URL

    init(name: String = "notchflow-tests-\(UUID().uuidString)") throws {
        let base = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        self.url = base
    }

    /// Create a nested subdirectory, creating intermediates as needed.
    @discardableResult
    func makeSubdirectory(_ path: String) throws -> URL {
        let sub = url.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(
            at: sub,
            withIntermediateDirectories: true
        )
        return sub
    }

    /// Write a text file at a relative path under the temp root. Creates
    /// parent directories on the fly.
    @discardableResult
    func writeFile(_ relativePath: String, contents: String) throws -> URL {
        let dest = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}
