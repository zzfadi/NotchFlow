import Foundation
import SwiftUI
import CryptoKit

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Note Analysis Result

/// Result of analyzing a note's content
struct NoteAnalysisResult: Equatable {
    let tags: [String]
    let category: NoteCategory
    let priority: NotePriority
    let confidence: Double

    static let empty = NoteAnalysisResult(
        tags: [],
        category: .uncategorized,
        priority: .normal,
        confidence: 0
    )
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
///
/// Design principles for 3B on-device model:
/// - **Stability over novelty**: Don't change metadata on every analysis
/// - **Debounce**: Wait for user to stop typing before analyzing
/// - **Content hashing**: Only re-analyze if content significantly changed
/// - **Sticky metadata**: Keep existing category/priority unless clearly better
/// - **Minimal prompts**: Short, structured extraction (not open-ended generation)
/// - **Graceful fallback**: Rule-based analysis when AI unavailable
@MainActor
final class NoteAnalyzer: ObservableObject {
    static let shared = NoteAnalyzer()

    @Published private(set) var isAnalyzing: Bool = false

    private let settings = SettingsManager.shared

    // MARK: - Stability Controls

    /// Minimum characters before attempting AI analysis
    private let minContentForAI = 50

    /// Maximum characters to send to AI (keep prompts small for 3B model)
    private let maxContentForAI = 300

    /// Cooldown between analyses for same note (seconds)
    private let analysisCooldown: TimeInterval = 30

    /// Cache of recent analysis times per note ID
    private var lastAnalysisTime: [UUID: Date] = [:]

    /// Cache of content hashes to detect changes
    private var contentHashes: [UUID: String] = [:]

    private init() {}

    // MARK: - Public API

    /// Analyze a note and return extracted metadata.
    /// Uses AI when available, falls back to rule-based analysis.
    /// Returns nil if analysis should be skipped (cooldown, no change, etc.)
    func analyze(_ note: Note) async -> NoteAnalysisResult? {
        // Skip empty notes
        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Check cooldown - avoid re-analyzing too frequently
        if let lastTime = lastAnalysisTime[note.id],
           Date().timeIntervalSince(lastTime) < analysisCooldown {
            return nil
        }

        // Check if content significantly changed
        let currentHash = contentHash(note.content)
        if let previousHash = contentHashes[note.id], previousHash == currentHash {
            return nil
        }

        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisTime[note.id] = Date()
            contentHashes[note.id] = currentHash
        }

        // Try AI for longer content when enabled
        if settings.foundationModelsEnabled && note.content.count >= minContentForAI {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if let result = await analyzeWithAI(note) {
                    return applyStickiness(result, existingNote: note)
                }
            }
            #endif
        }

        // Fall back to rule-based analysis
        return analyzeWithRules(note)
    }

    /// Force immediate analysis, bypassing cooldown
    func forceAnalyze(_ note: Note) async -> NoteAnalysisResult? {
        lastAnalysisTime.removeValue(forKey: note.id)
        contentHashes.removeValue(forKey: note.id)
        return await analyze(note)
    }

    /// Clear analysis cache for a note
    func clearCache(for noteId: UUID) {
        lastAnalysisTime.removeValue(forKey: noteId)
        contentHashes.removeValue(forKey: noteId)
    }

    // MARK: - Content Hashing

    private func contentHash(_ content: String) -> String {
        let normalized = content
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .prefix(500)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Stickiness (Avoid Flip-Flopping)

    private func applyStickiness(_ result: NoteAnalysisResult, existingNote: Note) -> NoteAnalysisResult {
        var finalCategory = result.category
        var finalPriority = result.priority

        // Keep existing category if AI confidence is low or new is generic
        if let existing = existingNote.category, existing != .uncategorized {
            if result.confidence < 0.7 || result.category == .reference {
                finalCategory = existing
            }
        }

        // Keep existing priority unless AI is confident about a change
        if let existing = existingNote.priority {
            let isBigJump = (existing == .high && result.priority == .low) ||
                           (existing == .low && result.priority == .high)
            if result.priority == .normal || (isBigJump && result.confidence < 0.8) {
                finalPriority = existing
            }
        }

        return NoteAnalysisResult(
            tags: result.tags,
            category: finalCategory,
            priority: finalPriority,
            confidence: result.confidence
        )
    }

    // MARK: - AI-Based Analysis

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func analyzeWithAI(_ note: Note) async -> NoteAnalysisResult? {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else { return nil }

        do {
            // Keep instructions minimal for 3B model
            let session = LanguageModelSession(instructions: """
                Extract metadata. Be consistent.
                Tags: 1-3 lowercase words.
                Category: task/idea/reference/meeting/snippet.
                Priority: high only if urgent, else normal/low.
                """)

            // Truncate to keep within 3B model's sweet spot
            let input = String(note.content.prefix(maxContentForAI))

            let response = try await session.respond(
                to: "Analyze:\n\(input)",
                generating: AIExtractedNoteMetadata.self
            )

            let metadata = response.content
            let category = NoteCategory(rawValue: metadata.category.lowercased()) ?? .uncategorized
            let priority = NotePriority(rawValue: metadata.priority.lowercased()) ?? .normal
            let tags = metadata.tags
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count <= 15 }
                .prefix(3)

            let confidence = calculateConfidence(tags: Array(tags), category: category, content: note.content)

            return NoteAnalysisResult(
                tags: Array(tags),
                category: category,
                priority: priority,
                confidence: confidence
            )
        } catch {
            return nil // Silent fallback to rules
        }
    }

    private func calculateConfidence(tags: [String], category: NoteCategory, content: String) -> Double {
        var score = 0.5
        let lowerContent = content.lowercased()

        // Tags that appear in content boost confidence
        let relevantTags = tags.filter { lowerContent.contains($0) }
        score += Double(relevantTags.count) * 0.1

        // Non-generic category boosts confidence
        if category != .uncategorized && category != .reference {
            score += 0.15
        }

        // Longer content = more context
        if content.count > 100 { score += 0.1 }
        if content.count > 200 { score += 0.1 }

        return min(1.0, score)
    }
    #endif

    // MARK: - Rule-Based Analysis

    private func analyzeWithRules(_ note: Note) -> NoteAnalysisResult {
        let tags = extractTagsWithRules(note.content)
        let category = detectCategoryWithRules(note.content)
        let priority = detectPriorityWithRules(note.content)

        return NoteAnalysisResult(
            tags: tags,
            category: category,
            priority: priority,
            confidence: 0.6
        )
    }

    private func extractTagsWithRules(_ content: String) -> [String] {
        var tags: Set<String> = []
        let lower = content.lowercased()

        // Extract explicit hashtags
        for word in lower.components(separatedBy: .whitespacesAndNewlines)
            where word.hasPrefix("#") && word.count > 1 {
            let tag = word.dropFirst().trimmingCharacters(in: .punctuationCharacters)
            if !tag.isEmpty && tag.count < 20 {
                tags.insert(String(tag))
            }
        }

        // Detect common topics
        let patterns: [(keywords: [String], tag: String)] = [
            (["api", "endpoint"], "api"),
            (["bug", "fix", "error"], "bugfix"),
            (["test", "testing"], "testing"),
            (["deploy", "release"], "deployment"),
            (["database", "sql"], "database"),
            (["ui", "design"], "design"),
            (["auth", "login"], "auth")
        ]

        for (keywords, tag) in patterns where keywords.contains(where: { lower.contains($0) }) {
            tags.insert(tag)
            if tags.count >= 3 { break }
        }

        if content.contains("```") || content.contains("func ") {
            tags.insert("code")
        }

        return Array(tags.prefix(3))
    }

    private func detectCategoryWithRules(_ content: String) -> NoteCategory {
        let lower = content.lowercased()

        if lower.contains("[ ]") || lower.contains("[x]") || lower.contains("todo") {
            return .task
        }
        if content.contains("```") || (content.contains("func ") && content.contains("{")) {
            return .snippet
        }
        if lower.contains("meeting") || lower.contains("agenda") {
            return .meeting
        }
        if lower.contains("idea") || lower.contains("what if") {
            return .idea
        }
        return .reference
    }

    private func detectPriorityWithRules(_ content: String) -> NotePriority {
        let lower = content.lowercased()

        if ["urgent", "asap", "critical", "blocker", "p0", "p1", "!!!"]
            .contains(where: { lower.contains($0) }) {
            return .high
        }
        if ["someday", "maybe", "backlog", "p3"]
            .contains(where: { lower.contains($0) }) {
            return .low
        }
        return .normal
    }
}
