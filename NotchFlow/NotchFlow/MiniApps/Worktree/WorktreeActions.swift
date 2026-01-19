import Foundation
import AppKit

/// Shared utility for worktree actions like opening in Terminal, VS Code, or Finder
enum WorktreeActions {

    /// Opens the specified path in Terminal.app
    static func openInTerminal(_ path: URL) {
        let escapedPath = path.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedPath)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    /// Opens the specified path in VS Code using the 'code' command
    static func openInVSCode(_ path: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["code", path.path]
        do {
            try task.run()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to Open in VS Code"
            alert.informativeText = "The 'code' command could not be found. Please ensure VS Code is installed and the 'code' command is in your PATH."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Opens the specified path in Finder
    static func openInFinder(_ path: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }

    /// Copies the path to the clipboard
    static func copyPath(_ path: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path.path, forType: .string)
    }
}
