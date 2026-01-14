import Foundation
import SwiftUI

enum MiniApp: String, CaseIterable, Identifiable {
    case worktree = "Worktree"
    case aiConfig = "AI Config"
    case fogNote = "Fog Note"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .worktree:
            return "arrow.triangle.branch"
        case .aiConfig:
            return "brain"
        case .fogNote:
            return "note.text"
        }
    }

    var description: String {
        switch self {
        case .worktree:
            return "Git worktree discovery and management"
        case .aiConfig:
            return "Find and manage AI configuration files"
        case .fogNote:
            return "Quick capture and note management"
        }
    }
}

class NavigationState: ObservableObject {
    @Published var activeApp: MiniApp = .fogNote
    @Published var isExpanded: Bool = false

    func switchTo(_ app: MiniApp) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeApp = app
        }
    }

    func expand() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = true
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }

    func toggle() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
}
