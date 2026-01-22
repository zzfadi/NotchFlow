import SwiftUI

/// Central registry for all mini app plugins.
///
/// The registry manages both built-in plugins (Worktree, AIConfig, FogNote)
/// and external plugins (CodexBar). External plugins register themselves
/// at app launch via `PluginRegistry.shared.register()`.
@MainActor
public final class PluginRegistry: ObservableObject, Sendable {
    public static let shared = PluginRegistry()

    /// All registered plugins in display order
    @Published private(set) var plugins: [any MiniAppPlugin] = []

    private init() {
        registerBuiltInPlugins()
    }

    /// Register built-in mini apps on initialization
    private func registerBuiltInPlugins() {
        register(WorktreePlugin())
        register(AIConfigPlugin())
        register(FogNotePlugin())
        // External plugins
        register(CodexBarPluginAdapter())
    }

    /// Register a new plugin. Duplicate IDs are ignored with a warning.
    public func register(_ plugin: any MiniAppPlugin) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else {
            print("[PluginRegistry] Warning: Plugin '\(plugin.id)' already registered, skipping")
            return
        }
        plugins.append(plugin)
        print("[PluginRegistry] Registered: \(plugin.displayName) (\(plugin.id))")
    }

    /// Look up a plugin by its ID
    public func plugin(for id: String) -> (any MiniAppPlugin)? {
        plugins.first { $0.id == id }
    }

    /// Get all plugin IDs
    public var allPluginIds: [String] {
        plugins.map(\.id)
    }

    /// Default plugin ID (first registered)
    public var defaultPluginId: String {
        plugins.first?.id ?? "fogNote"
    }
}
