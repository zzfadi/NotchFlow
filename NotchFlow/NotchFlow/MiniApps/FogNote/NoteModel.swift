import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
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
