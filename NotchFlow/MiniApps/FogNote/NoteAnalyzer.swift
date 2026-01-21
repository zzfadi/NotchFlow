import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Note Analysis Result

/// Result of analyzing a note's content
struct NoteAnalysisResult {
    let tags: [String]
    let category: NoteCategory
    let priority: NotePriority
}

// MARK: - Generable Struct for AI Extraction

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct AIExtractedNoteMetadata {
    @Guide(description: "1-3 single lowercase words describing the note topic")
    var tags: [String]

    @Guide(description: "One of: task, idea, reference, meeting, snippet")
    var category: String

    @Guide(description: "One of: high, normal, low based on urgency")
    var priority: String
}
#endif

// MARK: - Note Analyzer Service

/// Analyzes notes to extract metadata using AI with rule-based fallback.
/// Designed to be invisible to users - feels like smart algorithms.
@MainActor
final class NoteAnalyzer: ObservableObject {
    static let shared = NoteAnalyzer()

    @Published private(set) var isAnalyzing: Bool = false

    private let settings = SettingsManager.shared

    private init() {}

    // MARK: - Public API

    /// Analyze a note and return extracted metadata.
    /// Uses AI when available, falls back to rule-based analysis.
    func analyze(_ note: Note) async -> NoteAnalysisResult? {
        // Skip empty notes
        guard !note.isEmpty else { return nil }

        // Skip if recently analyzed and content unchanged
        guard note.needsAnalysis else { return nil }

        // Check if auto-analysis is enabled
        guard settings.autoAnalyzeNotes else { return nil }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Try AI first if available and enabled
        if settings.foundationModelsEnabled && settings.aiFeaturesFogNote {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if let result = await analyzeWithAI(note) {
                    return result
                }
            }
            #endif
        }

        // Fall back to rule-based analysis (always works)
        return analyzeWithRules(note)
    }

    /// Batch analyze multiple notes (e.g., on app launch)
    func analyzeNotes(_ notes: [Note]) async -> [UUID: NoteAnalysisResult] {
        var results: [UUID: NoteAnalysisResult] = [:]

        for note in notes {
            if let result = await analyze(note) {
                results[note.id] = result
            }
            // Small delay between analyses to avoid overwhelming the model
            try? await Task.sleep(for: .milliseconds(50))
        }

        return results
    }

    // MARK: - AI-Based Analysis

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func analyzeWithAI(_ note: Note) async -> NoteAnalysisResult? {
        // Check system availability
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else { return nil }

        do {
            let session = LanguageModelSession(instructions: """
                Extract metadata from notes. Be concise and accurate.
                For tags: use 1-3 single lowercase words.
                For category: choose exactly one of task/idea/reference/meeting/snippet.
                For priority: choose high only if urgent words present, otherwise normal or low.
                """)

            // Truncate input to stay within token limits
            let input = String(note.content.prefix(400))

            let response = try await session.respond(
                to: "Analyze this note:\n\n\(input)",
                generating: AIExtractedNoteMetadata.self
            )

            let metadata = response.content

            // Parse AI response into our types
            let category = NoteCategory(rawValue: metadata.category.lowercased()) ?? .uncategorized
            let priority = NotePriority(rawValue: metadata.priority.lowercased()) ?? .normal
            let tags = Array(metadata.tags.prefix(3).map { $0.lowercased() })

            return NoteAnalysisResult(tags: tags, category: category, priority: priority)

        } catch {
            // AI failed, will fall back to rules
            print("[NoteAnalyzer] AI analysis failed: \(error.localizedDescription)")
            return nil
        }
    }
    #endif

    // MARK: - Rule-Based Analysis (Fallback)

    private func analyzeWithRules(_ note: Note) -> NoteAnalysisResult {
        let tags = extractTagsWithRules(note.content)
        let category = detectCategoryWithRules(note.content)
        let priority = detectPriorityWithRules(note.content)

        return NoteAnalysisResult(tags: tags, category: category, priority: priority)
    }

    /// Extract tags using pattern matching
    private func extractTagsWithRules(_ content: String) -> [String] {
        var tags: Set<String> = []
        let lower = content.lowercased()

        // Extract hashtags using simple parsing
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if word.hasPrefix("#") && word.count > 1 {
                let tag = word.dropFirst().trimmingCharacters(in: .punctuationCharacters)
                if !tag.isEmpty && tag.count < 20 {
                    tags.insert(String(tag))
                }
            }
        }

        // Detect common topics
        let topicPatterns: [(keywords: [String], tag: String)] = [
            (["api", "endpoint", "rest"], "api"),
            (["bug", "fix", "issue", "error"], "bugfix"),
            (["test", "testing", "spec"], "testing"),
            (["deploy", "release", "production"], "deployment"),
            (["database", "db", "sql", "query"], "database"),
            (["ui", "ux", "design", "layout"], "design"),
            (["auth", "login", "password", "token"], "auth"),
            (["performance", "optimize", "speed"], "performance"),
        ]

        for (keywords, tag) in topicPatterns where keywords.contains(where: { lower.contains($0) }) {
            tags.insert(tag)
        }

        // Detect code presence
        if content.contains("```") || content.contains("func ") ||
           content.contains("class ") || content.contains("import ") {
            tags.insert("code")
        }

        return Array(tags.prefix(3))
    }

    /// Detect category based on content patterns
    private func detectCategoryWithRules(_ content: String) -> NoteCategory {
        let lower = content.lowercased()

        // Task indicators
        let taskPatterns = ["[ ]", "[x]", "todo", "task", "action item", "deadline", "due"]
        if taskPatterns.contains(where: { lower.contains($0) }) {
            return .task
        }

        // Code snippet indicators
        if content.contains("```") ||
           (content.contains("func ") && content.contains("{")) ||
           content.contains("import ") {
            return .snippet
        }

        // Meeting indicators
        let meetingPatterns = ["meeting", "attendees", "agenda", "minutes", "call with", "sync with"]
        if meetingPatterns.contains(where: { lower.contains($0) }) {
            return .meeting
        }

        // Idea indicators
        let ideaPatterns = ["idea", "what if", "could we", "brainstorm", "concept", "proposal"]
        if ideaPatterns.contains(where: { lower.contains($0) }) {
            return .idea
        }

        // Default to reference
        return .reference
    }

    /// Detect priority based on urgency indicators
    private func detectPriorityWithRules(_ content: String) -> NotePriority {
        let lower = content.lowercased()

        // High priority indicators
        let urgentPatterns = [
            "urgent", "asap", "critical", "immediately", "emergency",
            "high priority", "p0", "p1", "blocker", "deadline today",
            "due today", "!!!", "🔥", "🚨"
        ]
        if urgentPatterns.contains(where: { lower.contains($0) }) {
            return .high
        }

        // Low priority indicators
        let lowPatterns = [
            "low priority", "someday", "maybe", "backlog", "nice to have",
            "when time permits", "p3", "p4"
        ]
        if lowPatterns.contains(where: { lower.contains($0) }) {
            return .low
        }

        return .normal
    }
}
