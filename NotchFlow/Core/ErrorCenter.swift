import Foundation
import SwiftUI
import os.log

private let log = Logger(
    subsystem: "com.notchflow.app",
    category: "ErrorCenter"
)

/// Severity for a surfaced message. Drives the toast's icon + color.
enum ToastLevel {
    case error, warning, info

    var iconName: String {
        switch self {
        case .error:   return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .cyan
        }
    }
}

/// A single surfaced message. Identified by UUID so the overlay can animate
/// individual toasts in and out independently.
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let level: ToastLevel
    let createdAt: Date = Date()
    /// Optional source tag so callers can coalesce / replace earlier toasts
    /// from the same source (e.g. successive failures of the same scanner).
    let source: String?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// Centralized place for scanners/stores to surface errors the user should
/// see. Replaces the `try?` swallow pattern that previously left the UI in
/// "loading" state forever when background work failed.
///
/// Usage:
/// ```
/// ErrorCenter.shared.surface("Could not scan ~/Projects", level: .error,
///                            source: "WorktreeScanner")
/// ```
@MainActor
final class ErrorCenter: ObservableObject {
    static let shared = ErrorCenter()

    @Published private(set) var toasts: [Toast] = []

    /// How long a toast stays on screen before auto-dismissing. Kept short
    /// because the overlay sits on top of tab content; long toasts would
    /// be obnoxious.
    private let autoDismissInterval: TimeInterval = 4.0

    private init() {}

    /// Append a new toast. If `source` is provided and a toast with the same
    /// source already exists, the older one is replaced — this prevents a
    /// loop of failing fetches from stacking up 50 identical toasts.
    func surface(_ message: String, level: ToastLevel = .error, source: String? = nil) {
        let toast = Toast(message: message, level: level, source: source)

        if let source {
            toasts.removeAll { $0.source == source }
        }
        toasts.append(toast)

        switch level {
        case .error:   log.error("\(message, privacy: .public)")
        case .warning: log.warning("\(message, privacy: .public)")
        case .info:    log.info("\(message, privacy: .public)")
        }

        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.autoDismissInterval ?? 4))
            self?.dismiss(id: id)
        }
    }

    func dismiss(id: UUID) {
        toasts.removeAll { $0.id == id }
    }

    func dismissAll() {
        toasts.removeAll()
    }
}
