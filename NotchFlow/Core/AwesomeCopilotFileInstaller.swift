import Foundation

// MARK: - HTTPClient

/// Minimal HTTP abstraction so the file installer can be tested without
/// hitting the network. Production uses `URLSession.shared` via
/// `URLSessionHTTPClient`.
protocol HTTPClient: Sendable {
    func download(from url: URL) async throws -> Data
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PluginInstallerError.networkFailure("HTTP \(http.statusCode) fetching \(url)")
        }
        return data
    }
}

// MARK: - AwesomeCopilotFileInstaller

/// awesome-copilot and similar "file-copy" marketplaces don't have a
/// plugin cache — they're just a catalog of files you drop into your
/// project. This installer downloads each file declared in
/// `plugin.files` to the chosen target directory and writes a
/// `.notchflow-provenance.json` sidecar so the next scan can attribute
/// those files to the plugin.
struct AwesomeCopilotFileInstaller: PluginInstalling {
    private let http: HTTPClient
    private let fs: FileSystemProviding

    init(
        http: HTTPClient = URLSessionHTTPClient(),
        fs: FileSystemProviding = DefaultFileSystem()
    ) {
        self.http = http
        self.fs = fs
    }

    func canInstall(_ plugin: MetaPlugin) -> Bool {
        !plugin.files.isEmpty
    }

    func install(_ plugin: MetaPlugin, target: InstallTarget) async throws -> PluginProvenance {
        guard !plugin.files.isEmpty else {
            throw PluginInstallerError.manifestMissingFiles
        }
        let root = try resolveTargetRoot(target)

        for file in plugin.files {
            let data = try await http.download(from: file.remoteURL)
            let dest = root.appendingPathComponent(file.relativePath)
            try createParentDirectoryIfNeeded(for: dest)
            do {
                try data.write(to: dest, options: .atomic)
            } catch {
                throw PluginInstallerError.filesystemFailure(
                    "Writing \(file.relativePath): \(error.localizedDescription)"
                )
            }
        }

        try writeSidecar(
            in: root,
            plugin: plugin,
            target: target
        )

        return PluginProvenance(
            identity: plugin.identity,
            version: plugin.version,
            scope: .sidecar,
            isEnabled: true
        )
    }

    func uninstall(_ provenance: PluginProvenance) async throws {
        // Uninstall walks the sidecar in any known project root — we
        // don't know which one owns this provenance after the fact, so
        // this is a no-op placeholder. A richer implementation would
        // persist the install root alongside the sidecar for cleanup.
        throw PluginInstallerError.unsupported(
            "Uninstalling file-copy plugins manually: delete the installed files from your project."
        )
    }

    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) async throws -> PluginProvenance {
        // Reuse `install` because file-copy updates are just re-copies.
        // For now we always install to userScope on update — the richer
        // behavior (remember original target) ties into provenance
        // augmentation we haven't added yet.
        try await install(plugin, target: .userScope)
    }

    // MARK: - Private

    private func resolveTargetRoot(_ target: InstallTarget) throws -> URL {
        switch target {
        case .userScope:
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".notchflow-installs", isDirectory: true)
        case .projectScope(let url):
            return url
        case .teamScope:
            throw PluginInstallerError.unsupported(
                "Team-scope installs aren't supported for file-copy marketplaces"
            )
        }
    }

    private func createParentDirectoryIfNeeded(for fileURL: URL) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !fs.directoryExists(at: parent) {
            do {
                try FileManager.default.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true
                )
            } catch {
                throw PluginInstallerError.filesystemFailure(
                    "Creating \(parent.path): \(error.localizedDescription)"
                )
            }
        }
    }

    private func writeSidecar(
        in root: URL,
        plugin: MetaPlugin,
        target: InstallTarget
    ) throws {
        let sidecarURL = root.appendingPathComponent(".notchflow-provenance.json")
        var existing: [String: [String: Any]] = [:]
        if let data = try? Data(contentsOf: sidecarURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            existing = json
        }

        var entry: [String: Any] = [
            "canonicalSource": plugin.identity.canonicalSource,
            "pluginName": plugin.identity.pluginName,
            "installedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let v = plugin.version { entry["version"] = v }
        if let m = plugin.identity.marketplaceId { entry["marketplaceId"] = m }

        for file in plugin.files {
            existing[file.relativePath] = entry
        }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: existing,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: sidecarURL, options: .atomic)
        } catch {
            throw PluginInstallerError.filesystemFailure(
                "Writing sidecar \(sidecarURL.path): \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - NoOpPluginInstaller

/// Default for plugins where no safe install path exists (local/synth
/// cards, unknown source types). `canInstall` returns false; write
/// methods throw. Keeping this explicit means nothing in the UI fails
/// silently when the registry hands it out.
struct NoOpPluginInstaller: PluginInstalling {
    func canInstall(_ plugin: MetaPlugin) -> Bool { false }

    func install(_ plugin: MetaPlugin, target: InstallTarget) async throws -> PluginProvenance {
        throw PluginInstallerError.unsupported("No installer available for this plugin source")
    }

    func uninstall(_ provenance: PluginProvenance) async throws {
        throw PluginInstallerError.unsupported("No installer available to uninstall this plugin")
    }

    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) async throws -> PluginProvenance {
        throw PluginInstallerError.unsupported("No installer available to update this plugin")
    }
}
