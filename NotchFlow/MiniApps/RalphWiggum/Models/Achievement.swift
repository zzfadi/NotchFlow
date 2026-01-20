import Foundation
import SwiftUI

// MARK: - Ralph Achievement

enum RalphAchievement: String, CaseIterable, Identifiable, Codable {
    case firstLoop = "first_loop"
    case firstSuccess = "first_success"
    case overnight = "overnight"
    case hundredIterations = "hundred_iterations"
    case thousandIterations = "thousand_iterations"
    case zeroErrors = "zero_errors"
    case threeProjects = "three_projects"
    case cheapWin = "cheap_win"
    case speedDemon = "speed_demon"
    case persistent = "persistent"
    case nightOwl = "night_owl"
    case earlyBird = "early_bird"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .firstLoop: return "I'm Learnding!"
        case .firstSuccess: return "I'm a Star!"
        case .overnight: return "Sleep is for the Weak"
        case .hundredIterations: return "Persistence"
        case .thousandIterations: return "Unstoppable"
        case .zeroErrors: return "Unpossible!"
        case .threeProjects: return "Multitasker"
        case .cheapWin: return "Budget Champion"
        case .speedDemon: return "Speed Demon"
        case .persistent: return "Never Give Up"
        case .nightOwl: return "Night Owl"
        case .earlyBird: return "Early Bird"
        }
    }

    var description: String {
        switch self {
        case .firstLoop: return "Started your first Ralph loop"
        case .firstSuccess: return "Completed an iteration successfully"
        case .overnight: return "Ran a loop for 8+ hours"
        case .hundredIterations: return "Completed 100 total iterations"
        case .thousandIterations: return "Completed 1,000 total iterations"
        case .zeroErrors: return "Completed a loop with no errors"
        case .threeProjects: return "Ran 3 concurrent loops"
        case .cheapWin: return "Completed a successful loop under $1"
        case .speedDemon: return "Completed 10 iterations in under 5 minutes"
        case .persistent: return "Continued after 10+ failed iterations"
        case .nightOwl: return "Started a loop after midnight"
        case .earlyBird: return "Started a loop before 6 AM"
        }
    }

    var icon: String {
        switch self {
        case .firstLoop: return "sparkles"
        case .firstSuccess: return "star.fill"
        case .overnight: return "moon.stars.fill"
        case .hundredIterations: return "flame.fill"
        case .thousandIterations: return "bolt.fill"
        case .zeroErrors: return "checkmark.seal.fill"
        case .threeProjects: return "square.stack.3d.up.fill"
        case .cheapWin: return "dollarsign.circle.fill"
        case .speedDemon: return "hare.fill"
        case .persistent: return "figure.climbing"
        case .nightOwl: return "owl"
        case .earlyBird: return "bird.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstLoop: return .blue
        case .firstSuccess: return .yellow
        case .overnight: return .purple
        case .hundredIterations: return .orange
        case .thousandIterations: return .red
        case .zeroErrors: return .green
        case .threeProjects: return .cyan
        case .cheapWin: return .mint
        case .speedDemon: return .pink
        case .persistent: return .indigo
        case .nightOwl: return .purple
        case .earlyBird: return .orange
        }
    }

    var ralphQuote: String {
        switch self {
        case .firstLoop: return "I'm learnding!"
        case .firstSuccess: return "I'm a star!"
        case .overnight: return "I stayed up ALL night!"
        case .hundredIterations: return "I can count to 100!"
        case .thousandIterations: return "That's a lot of numbers!"
        case .zeroErrors: return "Me fail English? That's unpossible!"
        case .threeProjects: return "I'm helping everyone!"
        case .cheapWin: return "I saved money!"
        case .speedDemon: return "I'm fast like a cheetah!"
        case .persistent: return "I never give up!"
        case .nightOwl: return "The moon is my friend"
        case .earlyBird: return "Good morning, Super Nintendo Chalmers!"
        }
    }

    var rarity: Rarity {
        switch self {
        case .firstLoop, .firstSuccess: return .common
        case .overnight, .cheapWin, .nightOwl, .earlyBird: return .uncommon
        case .hundredIterations, .threeProjects, .speedDemon, .persistent: return .rare
        case .zeroErrors: return .epic
        case .thousandIterations: return .legendary
        }
    }

    enum Rarity: String, Codable {
        case common
        case uncommon
        case rare
        case epic
        case legendary

        var color: Color {
            switch self {
            case .common: return .gray
            case .uncommon: return .green
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .orange
            }
        }

        var displayName: String {
            rawValue.capitalized
        }
    }
}

// MARK: - Unlocked Achievement

struct UnlockedAchievement: Identifiable, Codable, Equatable {
    let id: UUID
    let achievement: RalphAchievement
    let unlockedAt: Date
    let loopId: UUID?
    let iterationId: UUID?

    init(
        id: UUID = UUID(),
        achievement: RalphAchievement,
        unlockedAt: Date = Date(),
        loopId: UUID? = nil,
        iterationId: UUID? = nil
    ) {
        self.id = id
        self.achievement = achievement
        self.unlockedAt = unlockedAt
        self.loopId = loopId
        self.iterationId = iterationId
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: unlockedAt, relativeTo: Date())
    }
}

// MARK: - Achievement Stats

struct AchievementStats: Codable {
    var totalLoopsStarted: Int = 0
    var totalIterationsCompleted: Int = 0
    var totalSuccessfulIterations: Int = 0
    var totalFailedIterations: Int = 0
    var longestLoopDuration: TimeInterval = 0
    var lowestSuccessfulCost: Double = .infinity
    var maxConcurrentLoops: Int = 0
    var fastestTenIterations: TimeInterval = .infinity
    var consecutiveFailures: Int = 0
    var maxConsecutiveFailures: Int = 0

    mutating func reset() {
        self = AchievementStats()
    }
}
