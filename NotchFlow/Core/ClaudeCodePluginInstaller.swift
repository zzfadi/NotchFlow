import Foundation

// MARK: - SubprocessRunning

/// Thin protocol around running a shell command so installer tests can
/// inject a fake instead of actually forking `claude`. The production
/// implementation uses `Process` directly — no external dependency on
/// swift-subprocess.
protocol SubprocessRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> SubprocessResult
}

struct SubprocessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

struct DefaultSubprocessRunner: SubprocessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) async throws -> SubprocessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment { process.environment = environment }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: outData, encoding: .utf8) ?? ""
                let err = String(data: errData, encoding: .utf8) ?? ""
                continuation.resume(returning: SubprocessResult(
                    exitCode: proc.terminationStatus,
                    stdout: out,
                    stderr: err
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - ClaudeCodePluginInstaller

/// Shells out to the `claude` CLI's plugin subcommands. Requires the
/// Claude Code CLI to be installed and on `PATH` — we look under
/// `/usr/local/bin/claude`, `~/.local/bin/claude`, and then fall back to
/// `which` resolution via `env`.
struct ClaudeCodePluginInstaller: PluginInstalling {
    private let runner: SubprocessRunning

    init(runner: SubprocessRunning = DefaultSubprocessRunner()) {
        self.runner = runner
    }

    func canInstall(_ plugin: MetaPlugin) -> Bool {
        switch plugin.source {
        case .github, .url, .git, .npm:
            return true
        case .relative, .local, .unknown:
            return false
        }
    }

    func install(_ plugin: MetaPlugin, target: InstallTarget) async throws -> PluginProvenance {
        let scopeFlag = flag(for: target)
        let spec = installSpec(for: plugin)
        let args = ["plugin", "install", spec, "--scope", scopeFlag]
        try await execute(arguments: args)
        return PluginProvenance(
            identity: plugin.identity,
            version: plugin.version,
            scope: scope(for: target),
            isEnabled: true
        )
    }

    func uninstall(_ provenance: PluginProvenance) async throws {
        try await execute(arguments: [
            "plugin", "uninstall", provenance.identity.pluginName
        ])
    }

    func update(_ provenance: PluginProvenance, to plugin: MetaPlugin) async throws -> PluginProvenance {
        try await execute(arguments: [
            "plugin", "update", provenance.identity.pluginName
        ])
        return PluginProvenance(
            identity: plugin.identity,
            version: plugin.version,
            scope: provenance.scope,
            isEnabled: provenance.isEnabled
        )
    }

    // MARK: - Private

    private func installSpec(for plugin: MetaPlugin) -> String {
        switch plugin.source {
        case .github(let repo, let ref, _):
            return ref.map { "\(repo)@\($0)" } ?? repo
        case .url(let url):
            return url.absoluteString
        case .git(let url, let ref, _):
            return ref.map { "\(url)#\($0)" } ?? url
        case .npm(let pkg, let version):
            return version.map { "\(pkg)@\($0)" } ?? pkg
        case .relative, .local, .unknown:
            return plugin.name
        }
    }

    private func flag(for target: InstallTarget) -> String {
        switch target {
        case .userScope: return "user"
        case .projectScope: return "project"
        case .teamScope: return "team"
        }
    }

    private func scope(for target: InstallTarget) -> PluginProvenance.Scope {
        switch target {
        case .userScope: return .user
        case .projectScope: return .project
        case .teamScope: return .team
        }
    }

    private func execute(arguments: [String]) async throws {
        let claudePath = resolveClaudePath()
        let result = try await runner.run(
            executable: claudePath,
            arguments: arguments,
            environment: nil
        )
        guard result.exitCode == 0 else {
            throw PluginInstallerError.subprocessFailure(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }

    private func resolveClaudePath() -> String {
        let candidates = [
            "/usr/local/bin/claude",
            NSString(string: "~/.local/bin/claude").expandingTildeInPath,
            "/opt/homebrew/bin/claude"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Fallback: rely on the `env` shim so PATH resolution applies.
        return "/usr/bin/env"
    }
}
