import SwiftUI

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable, Identifiable {
    // Platform sections
    case general = "General"
    case appearance = "Appearance"
    case appleIntelligence = "Apple Intelligence"
    case about = "About"

    // Mini-app sections
    case worktree = "Worktree"
    case aiConfig = "AI Config"
    case fogNote = "Fog Note"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .appearance:
            return "paintpalette"
        case .appleIntelligence:
            return "wand.and.stars"
        case .about:
            return "info.circle"
        case .worktree:
            return "arrow.triangle.branch"
        case .aiConfig:
            return "brain"
        case .fogNote:
            return "note.text"
        }
    }

    var isPlatformSection: Bool {
        switch self {
        case .general, .appearance, .appleIntelligence, .about:
            return true
        case .worktree, .aiConfig, .fogNote:
            return false
        }
    }

    static var platformSections: [SettingsSection] {
        allCases.filter { $0.isPlatformSection }
    }

    static var miniAppSections: [SettingsSection] {
        allCases.filter { !$0.isPlatformSection }
    }
}

// MARK: - Settings Sidebar

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        List(selection: $selection) {
            // Platform section
            Section("Platform") {
                ForEach(SettingsSection.platformSections) { section in
                    SidebarRow(section: section, accentColor: settings.accentColor)
                        .tag(section)
                }
            }

            // Mini Apps section
            Section("Mini Apps") {
                ForEach(SettingsSection.miniAppSections) { section in
                    SidebarRow(section: section, accentColor: settings.accentColor)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let section: SettingsSection
    let accentColor: Color

    var body: some View {
        Label {
            Text(section.rawValue)
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(iconColor)
        }
    }

    private var iconColor: Color {
        switch section {
        case .general:
            return .blue
        case .appearance:
            return .purple
        case .appleIntelligence:
            return .indigo
        case .about:
            return .gray
        case .worktree:
            return .orange
        case .aiConfig:
            return .cyan
        case .fogNote:
            return accentColor
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsSidebar(selection: .constant(.general))
        .frame(height: 400)
}
