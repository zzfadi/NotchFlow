import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Availability Status

/// Represents the availability state of Apple Foundation Models on this device
enum FoundationModelsAvailability: Equatable {
    case available
    case unavailableOS              // macOS version too old
    case unavailableHardware        // Not Apple Silicon
    case unavailableNotConfigured   // User hasn't set up Apple Intelligence
    case unavailableDownloading     // Model still downloading
    case disabled                   // User disabled in settings

    var localizedDescription: String {
        switch self {
        case .available:
            return "Apple Intelligence is available"
        case .unavailableOS:
            return "Requires macOS 26 or later"
        case .unavailableHardware:
            return "Requires Apple Silicon Mac"
        case .unavailableNotConfigured:
            return "Apple Intelligence not configured in System Settings"
        case .unavailableDownloading:
            return "Apple Intelligence model is downloading..."
        case .disabled:
            return "Disabled in NotchFlow settings"
        }
    }

    var canBeEnabled: Bool {
        switch self {
        case .available, .unavailableDownloading, .disabled:
            return true
        default:
            return false
        }
    }

    var statusColor: Color {
        switch self {
        case .available:
            return .green
        case .disabled:
            return .orange
        case .unavailableDownloading:
            return .blue
        default:
            return .red
        }
    }

    var statusSymbol: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .disabled:
            return "pause.circle.fill"
        case .unavailableDownloading:
            return "arrow.down.circle.fill"
        default:
            return "xmark.circle.fill"
        }
    }

    var statusTitle: String {
        switch self {
        case .available:
            return "Ready"
        case .disabled:
            return "Disabled"
        case .unavailableDownloading:
            return "Preparing..."
        default:
            return "Unavailable"
        }
    }
}

// MARK: - AI Task Types

/// Predefined AI task types - FogNote only for now
enum AITaskType {
    case analyzeNote
    case custom(prompt: String)

    var systemPrompt: String? {
        switch self {
        case .analyzeNote:
            return "Extract metadata from notes. Be accurate and consistent."
        case .custom:
            return nil
        }
    }

    func buildPrompt(for input: String) -> String {
        switch self {
        case .analyzeNote:
            return "Analyze:\n\(input)"
        case .custom(let prompt):
            return "\(prompt)\n\n\(input)"
        }
    }
}

// MARK: - Errors

enum FoundationModelsError: LocalizedError {
    case notAvailable(FoundationModelsAvailability)
    case generationFailed(String)
    case cancelled
    case inputTooLong

    var errorDescription: String? {
        switch self {
        case .notAvailable(let availability):
            return availability.localizedDescription
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .cancelled:
            return "Operation was cancelled"
        case .inputTooLong:
            return "Input text is too long. Please use a shorter text."
        }
    }

    var userMessage: String {
        switch self {
        case .notAvailable(let availability):
            return availability.localizedDescription
        case .generationFailed:
            return "AI generation failed. Please try again."
        case .cancelled:
            return "Operation cancelled."
        case .inputTooLong:
            return "Text is too long for AI processing."
        }
    }

    var recoveryAction: String? {
        switch self {
        case .notAvailable(let availability):
            switch availability {
            case .unavailableNotConfigured:
                return "Open System Settings"
            case .disabled:
                return "Enable in NotchFlow Settings"
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - Foundation Models Service

/// Main service for interacting with Apple Foundation Models
/// Provides availability checking, text generation, and streaming capabilities
@MainActor
final class FoundationModelsService: ObservableObject {
    static let shared = FoundationModelsService()

    @Published private(set) var availability: FoundationModelsAvailability = .unavailableOS
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var currentStreamText: String = ""

    /// Maximum input characters (approximate, to stay within token limits)
    private let maxInputCharacters = 12000 // ~3000 tokens, leaving room for output

    private init() {
        checkAvailability()
    }

    // MARK: - Availability Check

    /// Checks and updates the current availability status
    func checkAvailability() {
        // First check system availability, then apply user preference
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            checkSystemAvailability()
        } else {
            availability = .unavailableOS
        }
        #else
        availability = .unavailableOS
        #endif

        // If system is available but user has disabled, show as disabled
        if availability == .available && !SettingsManager.shared.foundationModelsEnabled {
            availability = .disabled
        }
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func checkSystemAvailability() {
        let systemAvailability = SystemLanguageModel.default.availability

        switch systemAvailability {
        case .available:
            availability = .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                availability = .unavailableHardware
            case .appleIntelligenceNotEnabled:
                availability = .unavailableNotConfigured
            case .modelNotReady:
                availability = .unavailableDownloading
            @unknown default:
                availability = .unavailableOS
            }
        @unknown default:
            availability = .unavailableOS
        }
    }
    #endif

    /// Returns true if AI features should be shown in UI
    var isAvailableForUI: Bool {
        availability == .available
    }

    // MARK: - Text Generation (Non-Streaming)

    /// Generates a response for the given task and input
    /// - Parameters:
    ///   - task: The type of AI task to perform
    ///   - input: The input text to process
    /// - Returns: The generated response text
    func generate(for task: AITaskType, input: String) async throws -> String {
        guard availability == .available else {
            throw FoundationModelsError.notAvailable(availability)
        }

        guard input.count <= maxInputCharacters else {
            throw FoundationModelsError.inputTooLong
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await performGeneration(task: task, input: input)
        }
        #endif

        throw FoundationModelsError.notAvailable(.unavailableOS)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func performGeneration(task: AITaskType, input: String) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        let session: LanguageModelSession
        if let systemPrompt = task.systemPrompt {
            session = LanguageModelSession(instructions: systemPrompt)
        } else {
            session = LanguageModelSession()
        }

        let prompt = task.buildPrompt(for: input)
        let response = try await session.respond(to: prompt)

        return response.content
    }
    #endif

    // MARK: - Streaming Generation

    /// Generates a response with streaming updates
    /// - Parameters:
    ///   - task: The type of AI task to perform
    ///   - input: The input text to process
    ///   - onChunk: Callback invoked for each chunk of generated text
    func streamGenerate(
        for task: AITaskType,
        input: String,
        onChunk: @escaping (String) -> Void
    ) async throws {
        guard availability == .available else {
            throw FoundationModelsError.notAvailable(availability)
        }

        guard input.count <= maxInputCharacters else {
            throw FoundationModelsError.inputTooLong
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            try await performStreamGeneration(task: task, input: input, onChunk: onChunk)
            return
        }
        #endif

        throw FoundationModelsError.notAvailable(.unavailableOS)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func performStreamGeneration(
        task: AITaskType,
        input: String,
        onChunk: @escaping (String) -> Void
    ) async throws {
        isProcessing = true
        currentStreamText = ""
        defer { isProcessing = false }

        let session: LanguageModelSession
        if let systemPrompt = task.systemPrompt {
            session = LanguageModelSession(instructions: systemPrompt)
        } else {
            session = LanguageModelSession()
        }

        let prompt = task.buildPrompt(for: input)

        for try await chunk in session.streamResponse(to: prompt) {
            let text = chunk.content
            currentStreamText += text
            onChunk(text)
        }
    }
    #endif

    // MARK: - Utility

    /// Resets the current stream state
    func resetStream() {
        currentStreamText = ""
    }

    /// Truncates input to fit within token limits
    func truncateIfNeeded(_ input: String) -> String {
        if input.count > maxInputCharacters {
            let truncated = String(input.prefix(maxInputCharacters))
            return truncated + "\n\n[Content truncated due to length...]"
        }
        return input
    }
}
