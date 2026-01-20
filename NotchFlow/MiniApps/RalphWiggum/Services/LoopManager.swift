import Foundation
import SwiftUI
import Combine

/// Main orchestrator for Ralph Wiggum loops
@MainActor
class LoopManager: ObservableObject {
    static let shared = LoopManager()

    // MARK: - Published State

    @Published var loops: [RalphLoop] = []
    @Published var currentState: RalphState = .idle
    @Published private(set) var unlockedAchievements: [UnlockedAchievement] = []
    @Published private(set) var stats: AchievementStats = AchievementStats()

    // MARK: - Private State

    private var iterations: [UUID: [LoopIteration]] = [:]
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private var executor = LoopExecutor()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Output Log (for live console view)

    /// Live output log for each loop (circular buffer, max 500 lines per loop)
    @Published var outputLogs: [UUID: [OutputLine]] = [:]
    private let maxLogLines = 500

    struct OutputLine: Identifiable {
        let id = UUID()
        let timestamp: Date
        let text: String
        let isError: Bool
    }

    // MARK: - Storage Paths

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchFlow/RalphWiggum")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var loopsStorageURL: URL {
        storageDirectory.appendingPathComponent("loops.json")
    }

    private var achievementsStorageURL: URL {
        storageDirectory.appendingPathComponent("achievements.json")
    }

    private var statsStorageURL: URL {
        storageDirectory.appendingPathComponent("stats.json")
    }

    // MARK: - Initialization

    private init() {
        loadData()
        updateCurrentState()
    }

    // MARK: - Computed Properties

    var totalIterations: Int {
        loops.reduce(0) { $0 + $1.currentIteration }
    }

    var runningLoops: [RalphLoop] {
        loops.filter { $0.status == .running }
    }

    var activeLoopCount: Int {
        loops.filter { $0.status.isActive }.count
    }

    // MARK: - CRUD Operations

    func addLoop(_ loop: RalphLoop) {
        loops.append(loop)
        iterations[loop.id] = []
        saveData()

        // Check for first loop achievement
        checkAchievement(.firstLoop, loopId: loop.id)
        stats.totalLoopsStarted += 1
    }

    func updateLoop(_ loop: RalphLoop) {
        if let index = loops.firstIndex(where: { $0.id == loop.id }) {
            loops[index] = loop
            saveData()
        }
    }

    func deleteLoop(_ id: UUID) {
        // Stop if running
        if let loop = loops.first(where: { $0.id == id }), loop.status.isActive {
            runningTasks[id]?.cancel()
            runningTasks.removeValue(forKey: id)
        }

        loops.removeAll { $0.id == id }
        iterations.removeValue(forKey: id)
        saveData()
        updateCurrentState()
    }

    func getIterations(for loopId: UUID) -> [LoopIteration] {
        iterations[loopId] ?? []
    }

    // MARK: - Loop Control

    func startLoop(_ id: UUID) async {
        guard let index = loops.firstIndex(where: { $0.id == id }) else { return }

        // Update state
        loops[index].status = .running
        loops[index].lastRunAt = Date()
        saveData()
        updateCurrentState()

        // Initialize output log
        let loop = loops[index]
        appendOutputLine(loopId: id, text: "═══════════════════════════════════════════════════", isError: false)
        appendOutputLine(loopId: id, text: "🔄 Starting Ralph Loop: \(loop.name)", isError: false)
        appendOutputLine(loopId: id, text: "📁 Project: \(loop.projectPath.path)", isError: false)
        appendOutputLine(loopId: id, text: "📝 Prompt: \(loop.promptPath.lastPathComponent)", isError: false)
        appendOutputLine(loopId: id, text: "🛠️ CLI: \(loop.cliTool) \(loop.cliArguments.joined(separator: " "))", isError: false)
        appendOutputLine(loopId: id, text: "═══════════════════════════════════════════════════", isError: false)

        // Check time-based achievements
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 6 {
            checkAchievement(.earlyBird, loopId: id)
        }
        if hour >= 0 && hour < 5 {
            checkAchievement(.nightOwl, loopId: id)
        }

        // Check concurrent loop achievement
        if activeLoopCount >= 3 {
            checkAchievement(.threeProjects, loopId: id)
        }
        stats.maxConcurrentLoops = max(stats.maxConcurrentLoops, activeLoopCount)

        // Start execution task
        let task = Task {
            await runLoopExecution(id: id)
        }
        runningTasks[id] = task
    }

    func pauseLoop(_ id: UUID) async {
        guard let index = loops.firstIndex(where: { $0.id == id }) else { return }

        loops[index].status = .paused
        saveData()
        updateCurrentState()

        // Signal executor to pause (it will complete current iteration first)
        await executor.pauseLoop(id)
    }

    func resumeLoop(_ id: UUID) async {
        guard let index = loops.firstIndex(where: { $0.id == id }) else { return }

        loops[index].status = .running
        saveData()
        updateCurrentState()

        // Resume execution
        let task = Task {
            await runLoopExecution(id: id)
        }
        runningTasks[id] = task
    }

    func stopLoop(_ id: UUID) async {
        guard let index = loops.firstIndex(where: { $0.id == id }) else { return }

        // Cancel task
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)

        // Update state
        loops[index].status = .idle
        loops[index].completedAt = Date()
        saveData()
        updateCurrentState()

        // Signal executor to stop
        await executor.stopLoop(id)
    }

    // MARK: - Loop Execution

    private func runLoopExecution(id: UUID) async {
        guard let loop = loops.first(where: { $0.id == id }) else { return }

        let startTime = Date()
        var iterationCount = 0
        var failureCount = 0

        for await event in await executor.executeLoop(loop) {
            // Check for cancellation
            if Task.isCancelled { break }

            // Handle events
            switch event {
            case .iterationStarted(let number):
                currentState = .working
                iterationCount = number

            case .iterationCompleted(let iteration):
                // Store iteration
                if iterations[id] == nil {
                    iterations[id] = []
                }
                iterations[id]?.append(iteration)

                // Update loop
                if let index = loops.firstIndex(where: { $0.id == id }) {
                    loops[index].currentIteration = iteration.iterationNumber + 1
                    if let tokens = iteration.tokensUsed {
                        loops[index].totalTokensUsed += tokens
                    }
                    if let cost = iteration.estimatedCost {
                        loops[index].totalEstimatedCost += cost
                    }
                    saveData()
                }

                // Update state based on result
                currentState = iteration.isSuccess ? .success : .confused

                // Track stats
                stats.totalIterationsCompleted += 1
                if iteration.isSuccess {
                    stats.totalSuccessfulIterations += 1
                    stats.consecutiveFailures = 0
                    checkAchievement(.firstSuccess, loopId: id, iterationId: iteration.id)
                } else {
                    stats.totalFailedIterations += 1
                    failureCount += 1
                    stats.consecutiveFailures += 1
                    stats.maxConsecutiveFailures = max(stats.maxConsecutiveFailures, stats.consecutiveFailures)

                    if stats.consecutiveFailures >= 10 {
                        checkAchievement(.persistent, loopId: id)
                    }
                }

                // Check iteration milestones
                if stats.totalIterationsCompleted >= 100 {
                    checkAchievement(.hundredIterations, loopId: id)
                }
                if stats.totalIterationsCompleted >= 1000 {
                    checkAchievement(.thousandIterations, loopId: id)
                }

            case .outputLine(let line):
                // Store output line for console view
                appendOutputLine(loopId: id, text: line, isError: false)

                // Update state based on output content
                if line.lowercased().contains("compil") {
                    currentState = .compiling
                } else if line.lowercased().contains("test") {
                    currentState = .testing
                } else if line.lowercased().contains("commit") {
                    currentState = .committed
                }

            case .errorLine(let line):
                // Store error line for console view
                appendOutputLine(loopId: id, text: line, isError: true)
                currentState = .error

            case .loopCompleted(let reason):
                if let index = loops.firstIndex(where: { $0.id == id }) {
                    loops[index].status = .completed
                    loops[index].completedAt = Date()
                    saveData()
                }
                currentState = .celebrating

                // Check completion achievements
                let duration = Date().timeIntervalSince(startTime)
                stats.longestLoopDuration = max(stats.longestLoopDuration, duration)

                if duration >= 8 * 60 * 60 { // 8 hours
                    checkAchievement(.overnight, loopId: id)
                }

                if reason == .success && failureCount == 0 {
                    checkAchievement(.zeroErrors, loopId: id)
                }

                if let loop = loops.first(where: { $0.id == id }),
                   loop.totalEstimatedCost < 1.0 && loop.status == .completed {
                    stats.lowestSuccessfulCost = min(stats.lowestSuccessfulCost, loop.totalEstimatedCost)
                    checkAchievement(.cheapWin, loopId: id)
                }

                // Check speed demon (10 iterations in 5 minutes)
                if iterationCount >= 10 && duration < 5 * 60 {
                    stats.fastestTenIterations = min(stats.fastestTenIterations, duration)
                    checkAchievement(.speedDemon, loopId: id)
                }

            case .loopFailed(let error):
                if let index = loops.firstIndex(where: { $0.id == id }) {
                    loops[index].status = .failed
                    loops[index].completedAt = Date()
                    saveData()
                }
                currentState = .error
                print("[LoopManager] Loop \(id) failed: \(error)")
            }
        }

        runningTasks.removeValue(forKey: id)
        updateCurrentState()
    }

    // MARK: - State Management

    private func updateCurrentState() {
        if runningLoops.isEmpty {
            currentState = .idle
        } else {
            // Keep current state if running
        }
    }

    // MARK: - Output Log Management

    private func appendOutputLine(loopId: UUID, text: String, isError: Bool) {
        if outputLogs[loopId] == nil {
            outputLogs[loopId] = []
        }

        let line = OutputLine(timestamp: Date(), text: text, isError: isError)
        outputLogs[loopId]?.append(line)

        // Trim to max lines (circular buffer)
        if let count = outputLogs[loopId]?.count, count > maxLogLines {
            outputLogs[loopId]?.removeFirst(count - maxLogLines)
        }
    }

    func getOutputLog(for loopId: UUID) -> [OutputLine] {
        outputLogs[loopId] ?? []
    }

    func clearOutputLog(for loopId: UUID) {
        outputLogs[loopId] = []
    }

    // MARK: - Achievements

    func isAchievementUnlocked(_ achievement: RalphAchievement) -> Bool {
        unlockedAchievements.contains { $0.achievement == achievement }
    }

    private func checkAchievement(_ achievement: RalphAchievement, loopId: UUID? = nil, iterationId: UUID? = nil) {
        guard !isAchievementUnlocked(achievement) else { return }

        let unlocked = UnlockedAchievement(
            achievement: achievement,
            loopId: loopId,
            iterationId: iterationId
        )
        unlockedAchievements.append(unlocked)
        saveData()

        // Could trigger notification/sound here
        print("[LoopManager] Achievement unlocked: \(achievement.name)")
    }

    // MARK: - Persistence

    private func loadData() {
        // Load loops
        if let data = try? Data(contentsOf: loopsStorageURL),
           let decoded = try? JSONDecoder().decode([RalphLoop].self, from: data) {
            loops = decoded

            // Reset any loops that were running when app quit
            for i in loops.indices where loops[i].status == .running || loops[i].status == .paused {
                loops[i].status = .idle
            }
        }

        // Load achievements
        if let data = try? Data(contentsOf: achievementsStorageURL),
           let decoded = try? JSONDecoder().decode([UnlockedAchievement].self, from: data) {
            unlockedAchievements = decoded
        }

        // Load stats
        if let data = try? Data(contentsOf: statsStorageURL),
           let decoded = try? JSONDecoder().decode(AchievementStats.self, from: data) {
            stats = decoded
        }
    }

    private func saveData() {
        // Save loops
        if let data = try? JSONEncoder().encode(loops) {
            try? data.write(to: loopsStorageURL)
        }

        // Save achievements
        if let data = try? JSONEncoder().encode(unlockedAchievements) {
            try? data.write(to: achievementsStorageURL)
        }

        // Save stats
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: statsStorageURL)
        }
    }
}
