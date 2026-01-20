import Foundation
import Subprocess

/// Result of running a subprocess
struct SubprocessResult: Sendable {
    let outputLines: [String]
    let errorLines: [String]
    let exitCode: Int
}

/// Runs a subprocess and returns the result
/// Using a static function to avoid Sendable issues with class state
enum StreamingSubprocess {
    static func run(
        path: String,
        arguments: [String],
        workingDirectory: URL
    ) throws -> SubprocessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read stdout and stderr
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let outputLines = String(data: stdoutData, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []

        let errorLines = String(data: stderrData, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []

        return SubprocessResult(
            outputLines: outputLines,
            errorLines: errorLines,
            exitCode: Int(process.terminationStatus)
        )
    }
}

/// Executes Ralph loops using a hybrid bash/Swift approach
actor LoopExecutor {
    private var pausedLoops: Set<UUID> = []
    private var stoppedLoops: Set<UUID> = []

    // MARK: - Public API

    func executeLoop(_ loop: RalphLoop) -> AsyncStream<LoopEvent> {
        AsyncStream { continuation in
            Task {
                await runLoop(loop, continuation: continuation)
            }
        }
    }

    func pauseLoop(_ id: UUID) {
        pausedLoops.insert(id)
    }

    func stopLoop(_ id: UUID) {
        stoppedLoops.insert(id)
        pausedLoops.remove(id)
    }

    // MARK: - Loop Execution

    private func runLoop(_ loop: RalphLoop, continuation: AsyncStream<LoopEvent>.Continuation) async {
        var currentIteration = loop.currentIteration
        let maxIterations = loop.maxIterations ?? 999

        // Clear any previous state
        pausedLoops.remove(loop.id)
        stoppedLoops.remove(loop.id)

        while currentIteration < maxIterations {
            // Check for stop
            if stoppedLoops.contains(loop.id) {
                continuation.yield(.outputLine("⏹️ Loop stopped by user"))
                continuation.yield(.loopCompleted(reason: .userStopped))
                stoppedLoops.remove(loop.id)
                break
            }

            // Check for pause
            if pausedLoops.contains(loop.id) {
                continuation.yield(.outputLine("⏸️ Loop paused..."))
                // Wait until resumed or stopped
                while pausedLoops.contains(loop.id) && !stoppedLoops.contains(loop.id) {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                if stoppedLoops.contains(loop.id) {
                    continuation.yield(.outputLine("⏹️ Loop stopped by user"))
                    continuation.yield(.loopCompleted(reason: .userStopped))
                    stoppedLoops.remove(loop.id)
                    break
                }
                pausedLoops.remove(loop.id)
                continuation.yield(.outputLine("▶️ Loop resumed"))
            }

            // Start iteration
            continuation.yield(.outputLine(""))
            continuation.yield(.outputLine("───────────────────────────────────────────────────"))
            continuation.yield(.outputLine("🔄 Iteration \(currentIteration + 1) starting..."))
            continuation.yield(.iterationStarted(number: currentIteration))

            // Execute single iteration with streaming output
            let iteration = await executeSingleIterationWithStreaming(
                loop: loop,
                iterationNumber: currentIteration,
                continuation: continuation
            )

            // Report iteration completion
            let statusIcon = iteration.isSuccess ? "✅" : "❌"
            continuation.yield(.outputLine("\(statusIcon) Iteration \(currentIteration + 1) completed (exit code: \(iteration.exitCode ?? -1))"))
            if !iteration.filesChanged.isEmpty {
                continuation.yield(.outputLine("📝 Files changed: \(iteration.filesChanged.count)"))
            }
            continuation.yield(.iterationCompleted(iteration: iteration))

            // Check for completion marker in output
            if let output = iteration.outputSnippet,
               output.contains("RALPH_COMPLETE") {
                continuation.yield(.loopCompleted(reason: .success))
                break
            }

            // Check for success (exit code 0)
            if iteration.exitCode == 0 {
                // Could be a successful iteration, continue unless completion marker found
            }

            currentIteration += 1
        }

        // Check if max iterations reached
        if currentIteration >= maxIterations {
            continuation.yield(.loopCompleted(reason: .maxIterationsReached))
        }

        continuation.finish()
    }

    private func executeSingleIterationWithStreaming(
        loop: RalphLoop,
        iterationNumber: Int,
        continuation: AsyncStream<LoopEvent>.Continuation
    ) async -> LoopIteration {
        let startedAt = Date()
        var exitCode: Int?
        var outputLines: [String] = []
        var errorLines: [String] = []

        // Get git state before execution
        let beforeCommit = await getCurrentCommit(in: loop.projectPath)

        // Execute the CLI command
        do {
            let script = buildIterationScript(loop: loop, iteration: iterationNumber)

            continuation.yield(.outputLine("🚀 Executing: \(loop.cliTool)"))

            // Run subprocess and collect output
            let result = try StreamingSubprocess.run(
                path: "/bin/bash",
                arguments: ["-c", script],
                workingDirectory: loop.projectPath
            )

            // Process stdout lines
            for line in result.outputLines {
                // Filter out Ralph markers from display but keep them in output
                if !line.hasPrefix("RALPH_ITERATION") {
                    continuation.yield(.outputLine(line))
                }
                outputLines.append(line)
            }

            // Process stderr lines
            for line in result.errorLines {
                continuation.yield(.errorLine("⚠️ \(line)"))
                errorLines.append(line)
            }

            exitCode = result.exitCode

        } catch {
            exitCode = -1
            let errorMsg = error.localizedDescription
            continuation.yield(.errorLine("❌ Error: \(errorMsg)"))
            errorLines.append(errorMsg)
        }

        // Get git state after execution
        let afterCommit = await getCurrentCommit(in: loop.projectPath)

        // Analyze file changes
        let filesChanged = await analyzeFileChanges(
            in: loop.projectPath,
            before: beforeCommit,
            after: afterCommit
        )

        // Generate semantic summary if files changed
        var semanticSummary: String?
        if !filesChanged.isEmpty {
            semanticSummary = generateSimpleSummary(filesChanged: filesChanged)
        }

        return LoopIteration(
            loopId: loop.id,
            iterationNumber: iterationNumber,
            startedAt: startedAt,
            completedAt: Date(),
            exitCode: exitCode,
            filesChanged: filesChanged,
            semanticSummary: semanticSummary,
            gitCommitHash: afterCommit != beforeCommit ? afterCommit : nil,
            tokensUsed: nil,
            estimatedCost: nil,
            outputSnippet: outputLines.suffix(50).joined(separator: "\n"),
            errorMessage: errorLines.isEmpty ? nil : errorLines.joined(separator: "\n")
        )
    }

    // Keep the non-streaming version for backwards compatibility
    private func executeSingleIteration(loop: RalphLoop, iterationNumber: Int) async -> LoopIteration {
        let startedAt = Date()
        var exitCode: Int?
        var outputSnippet: String?
        var errorMessage: String?

        // Get git state before execution
        let beforeCommit = await getCurrentCommit(in: loop.projectPath)

        // Execute the CLI command
        do {
            // Build command: cat PROMPT.md | cli-tool
            // For safety and cross-platform, we'll use a shell script approach
            let script = buildIterationScript(loop: loop, iteration: iterationNumber)

            let result = try await Subprocess.run(
                .path("/bin/bash"),
                arguments: ["-c", script],
                workingDirectory: .init(loop.projectPath.path),
                output: .string(limit: 1024 * 1024), // 1MB
                error: .string(limit: 64 * 1024)      // 64KB
            )

            if case .exited(let code) = result.terminationStatus {
                exitCode = Int(code)
            } else {
                exitCode = -1
            }
            outputSnippet = result.standardOutput?.suffix(2000).description
            if let stderr = result.standardError, !stderr.isEmpty {
                errorMessage = stderr
            }

        } catch {
            exitCode = -1
            errorMessage = error.localizedDescription
        }

        // Get git state after execution
        let afterCommit = await getCurrentCommit(in: loop.projectPath)

        // Analyze file changes
        let filesChanged = await analyzeFileChanges(
            in: loop.projectPath,
            before: beforeCommit,
            after: afterCommit
        )

        // Generate semantic summary if files changed
        var semanticSummary: String?
        if !filesChanged.isEmpty {
            semanticSummary = generateSimpleSummary(filesChanged: filesChanged)
        }

        return LoopIteration(
            loopId: loop.id,
            iterationNumber: iterationNumber,
            startedAt: startedAt,
            completedAt: Date(),
            exitCode: exitCode,
            filesChanged: filesChanged,
            semanticSummary: semanticSummary,
            gitCommitHash: afterCommit != beforeCommit ? afterCommit : nil,
            tokensUsed: nil, // Would need to parse from output
            estimatedCost: nil,
            outputSnippet: outputSnippet,
            errorMessage: errorMessage
        )
    }

    // MARK: - Script Building

    private func buildIterationScript(loop: RalphLoop, iteration: Int) -> String {
        // For Copilot CLI, we use -p flag to pass the prompt content directly
        // This is different from claude-code which uses stdin piping
        let promptPath = loop.promptPath.path
        let cliTool = loop.cliTool

        // Build arguments string (includes --model, --allow-all-tools, etc.)
        let argsString = loop.cliArguments.joined(separator: " ")

        // Copilot CLI uses -p for prompt, others might use stdin
        let isCopilot = cliTool == "copilot"

        if isCopilot {
            return """
            #!/bin/bash
            set -e

            # Ralph Wiggum Iteration \(iteration) - Copilot CLI
            echo "RALPH_ITERATION_START:\(iteration)"

            # Execute the prompt through Copilot CLI with -p flag
            if [ -f "\(promptPath)" ]; then
                PROMPT_CONTENT=$(cat "\(promptPath)")
                \(cliTool) \(argsString) -p "$PROMPT_CONTENT"
                exit_code=$?
            else
                echo "Error: Prompt file not found: \(promptPath)" >&2
                exit_code=1
            fi

            # Check for completion marker
            if [ $exit_code -eq 0 ]; then
                echo "RALPH_COMPLETE"
            fi

            echo "RALPH_ITERATION_END:\(iteration):$exit_code"
            exit $exit_code
            """
        } else {
            // Fallback for other CLI tools (stdin piping)
            return """
            #!/bin/bash
            set -e

            # Ralph Wiggum Iteration \(iteration)
            echo "RALPH_ITERATION_START:\(iteration)"

            # Execute the prompt through the CLI tool via stdin
            if [ -f "\(promptPath)" ]; then
                cat "\(promptPath)" | \(cliTool) \(argsString)
                exit_code=$?
            else
                echo "Error: Prompt file not found: \(promptPath)" >&2
                exit_code=1
            fi

            echo "RALPH_ITERATION_END:\(iteration):$exit_code"
            exit $exit_code
            """
        }
    }

    // MARK: - Git Operations

    private func getCurrentCommit(in directory: URL) async -> String? {
        do {
            let result = try await Subprocess.run(
                .path("/usr/bin/git"),
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: .init(directory.path),
                output: .string(limit: 1024),
                error: .string(limit: 1024)
            )

            if result.terminationStatus.isSuccess {
                return result.standardOutput?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        } catch {
            // Not a git repo or git not available
        }
        return nil
    }

    private func analyzeFileChanges(in directory: URL, before: String?, after: String?) async -> [FileChange] {
        guard let before = before, let after = after, before != after else {
            // No commit change, check for uncommitted changes
            return await getUncommittedChanges(in: directory)
        }

        do {
            let result = try await Subprocess.run(
                .path("/usr/bin/git"),
                arguments: ["diff", "--name-status", before, after],
                workingDirectory: .init(directory.path),
                output: .string(limit: 64 * 1024),
                error: .string(limit: 1024)
            )

            if result.terminationStatus.isSuccess, let output = result.standardOutput {
                return parseNameStatusOutput(output)
            }
        } catch {
            // Git diff failed
        }
        return []
    }

    private func getUncommittedChanges(in directory: URL) async -> [FileChange] {
        do {
            let result = try await Subprocess.run(
                .path("/usr/bin/git"),
                arguments: ["status", "--porcelain"],
                workingDirectory: .init(directory.path),
                output: .string(limit: 64 * 1024),
                error: .string(limit: 1024)
            )

            if result.terminationStatus.isSuccess, let output = result.standardOutput {
                return parsePorcelainOutput(output)
            }
        } catch {
            // Git status failed
        }
        return []
    }

    private func parseNameStatusOutput(_ output: String) -> [FileChange] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { return nil }

            let statusChar = String(parts[0].prefix(1))
            let path = String(parts[1])

            let changeType: FileChange.ChangeType
            switch statusChar {
            case "A": changeType = .added
            case "M": changeType = .modified
            case "D": changeType = .deleted
            case "R": changeType = .renamed
            case "C": changeType = .copied
            default: changeType = .modified
            }

            return FileChange(path: path, changeType: changeType)
        }
    }

    private func parsePorcelainOutput(_ output: String) -> [FileChange] {
        output.split(separator: "\n").compactMap { line in
            guard line.count > 3 else { return nil }

            let statusCode = String(line.prefix(2))
            let path = String(line.dropFirst(3))

            let changeType: FileChange.ChangeType
            if statusCode.contains("A") || statusCode.contains("?") {
                changeType = .added
            } else if statusCode.contains("D") {
                changeType = .deleted
            } else if statusCode.contains("R") {
                changeType = .renamed
            } else {
                changeType = .modified
            }

            return FileChange(path: path, changeType: changeType)
        }
    }

    private func generateSimpleSummary(filesChanged: [FileChange]) -> String {
        let added = filesChanged.filter { $0.changeType == .added }.count
        let modified = filesChanged.filter { $0.changeType == .modified }.count
        let deleted = filesChanged.filter { $0.changeType == .deleted }.count

        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if modified > 0 { parts.append("\(modified) modified") }
        if deleted > 0 { parts.append("\(deleted) deleted") }

        return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
    }
}

// Note: TerminationStatus.isSuccess and related APIs are defined in GitCommandRunner.swift
