import Foundation
import SwiftUI

// MARK: - Note Category

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case task
    case idea
    case reference
    case meeting
    case snippet
    case uncategorized

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .task: return "checkmark.circle"
        case .idea: return "lightbulb"
        case .reference: return "doc.text"
        case .meeting: return "person.2"
        case .snippet: return "curlybraces"
        case .uncategorized: return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .task: return .green
        case .idea: return .yellow
        case .reference: return .blue
        case .meeting: return .purple
        case .snippet: return .orange
        case .uncategorized: return .gray
        }
    }
}

// MARK: - Note Priority

enum NotePriority: String, Codable, CaseIterable, Identifiable {
    case high
    case normal
    case low

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }

    var color: Color {
        switch self {
        case .high: return .red
        case .normal: return .clear
        case .low: return .gray
        }
    }
}

// MARK: - Note Model

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool

    // AI-enhanced metadata (persisted, invisible to user)
    var tags: [String]?
    var category: NoteCategory?
    var priority: NotePriority?

    init(
        id: UUID = UUID(),
        content: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isPinned: Bool = false,
        tags: [String]? = nil,
        category: NoteCategory? = nil,
        priority: NotePriority? = nil
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
        self.tags = tags
        self.category = category
        self.priority = priority
    }

    var title: String {
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? ""
        if firstLine.isEmpty {
            return "Untitled"
        }
        // Remove markdown heading prefix if present
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return trimmed.drop(while: { $0 == "#" || $0 == " " }).trimmingCharacters(in: .whitespaces)
        }
        return String(trimmed.prefix(50))
    }

    var preview: String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 {
            return String(lines[1].prefix(100))
        }
        return String(content.prefix(100))
    }

    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        content.split(whereSeparator: \.isWhitespace).count
    }

    mutating func update(content: String) {
        self.content = content
        self.modifiedAt = Date()
    }

    mutating func togglePin() {
        self.isPinned.toggle()
        self.modifiedAt = Date()
    }
}
