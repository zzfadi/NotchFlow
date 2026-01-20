import Foundation
import SwiftUI

// MARK: - Ralph State

enum RalphState: String, CaseIterable, Identifiable {
    case idle
    case thinking
    case working
    case confused
    case error
    case success
    case compiling
    case testing
    case committed
    case celebrating

    var id: String { rawValue }

    // MARK: - Quotes

    var quotes: [String] {
        switch self {
        case .idle:
            return [
                "I'm learnding!",
                "My cat's breath smells like cat food",
                "I bent my wookie",
                "Hi, Super Nintendo Chalmers!",
                "I like trucks"
            ]
        case .thinking:
            return [
                "Um, let me think...",
                "My brain is working!",
                "The doctor said I wouldn't have so many nosebleeds if I kept my finger out of there",
                "I'm thinking with my thinker"
            ]
        case .working:
            return [
                "I'm helping!",
                "Look what I can do!",
                "I'm doing good!",
                "Watch me go!",
                "I choo-choo-choose you!"
            ]
        case .confused:
            return [
                "I don't understand",
                "My brain is ouchie",
                "That's unpossible!",
                "I'm confused by the instructions"
            ]
        case .error:
            return [
                "Me fail English? That's unpossible!",
                "I eated the purple berries",
                "Ow, my brain!",
                "Something went wrongly"
            ]
        case .success:
            return [
                "I'm a star!",
                "Yay! I did it!",
                "I won! I won!",
                "Look at me, I'm helping!"
            ]
        case .compiling:
            return [
                "Slow down, I'm making dots!",
                "Building things...",
                "My computer is thinking too",
                "Compiling is like waiting for cookies"
            ]
        case .testing:
            return [
                "Testing, testing, 1, 2, 3",
                "My nose makes its own bubblegum",
                "Running all the checks!",
                "Let's see if it works"
            ]
        case .committed:
            return [
                "I choo-choo-choose you!",
                "Saved to git!",
                "My changes are committed!",
                "I made a commit!"
            ]
        case .celebrating:
            return [
                "Yay! I'm a winner!",
                "This is the best day of my life!",
                "I'm so happy!",
                "We did it together!"
            ]
        }
    }

    // MARK: - Coding Context

    var codingContext: String {
        switch self {
        case .idle: return "Waiting for task..."
        case .thinking: return "Analyzing code..."
        case .working: return "Writing code..."
        case .confused: return "Unexpected state..."
        case .error: return "Error occurred"
        case .success: return "Task complete!"
        case .compiling: return "Compiling..."
        case .testing: return "Running tests..."
        case .committed: return "Committed changes"
        case .celebrating: return "Loop finished!"
        }
    }

    // MARK: - Visual Properties

    var icon: String {
        switch self {
        case .idle: return "moon.zzz"
        case .thinking: return "brain"
        case .working: return "hammer"
        case .confused: return "questionmark.circle"
        case .error: return "exclamationmark.triangle"
        case .success: return "checkmark.seal"
        case .compiling: return "gearshape.2"
        case .testing: return "checklist"
        case .committed: return "arrow.up.circle"
        case .celebrating: return "party.popper"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .thinking: return .blue
        case .working: return .orange
        case .confused: return .yellow
        case .error: return .red
        case .success: return .green
        case .compiling: return .purple
        case .testing: return .cyan
        case .committed: return .mint
        case .celebrating: return .pink
        }
    }

    var animationName: String {
        "ralph_\(rawValue)"
    }

    // MARK: - Methods

    func randomQuote() -> String {
        quotes.randomElement() ?? "I'm Ralph!"
    }

    // MARK: - State Transitions

    static func from(loopStatus: LoopStatus, lastExitCode: Int? = nil) -> RalphState {
        switch loopStatus {
        case .idle:
            return .idle
        case .running:
            return .working
        case .paused:
            return .thinking
        case .completed:
            return .celebrating
        case .failed:
            return .error
        }
    }

    static func from(iterationEvent: LoopEvent) -> RalphState {
        switch iterationEvent {
        case .iterationStarted:
            return .working
        case .iterationCompleted(let iteration):
            return iteration.isSuccess ? .success : .confused
        case .outputLine(let line):
            if line.lowercased().contains("compil") {
                return .compiling
            } else if line.lowercased().contains("test") {
                return .testing
            } else if line.lowercased().contains("commit") {
                return .committed
            }
            return .working
        case .errorLine:
            return .error
        case .loopCompleted(let reason):
            switch reason {
            case .success:
                return .celebrating
            case .maxIterationsReached, .budgetExceeded:
                return .confused
            case .userStopped:
                return .idle
            }
        case .loopFailed:
            return .error
        }
    }
}

// MARK: - Ralph Character Configuration

struct RalphCharacterConfig {
    var soundEnabled: Bool = true
    var quoteChangeInterval: TimeInterval = 5.0
    var animationSpeed: Double = 1.0

    static let `default` = RalphCharacterConfig()
}
