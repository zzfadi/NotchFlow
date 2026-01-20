import SwiftUI

/// Routes to the correct settings panel based on the selected section
struct SettingsDetailView: View {
    let section: SettingsSection?

    var body: some View {
        Group {
            if let section = section {
                detailView(for: section)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectBackground(material: .contentBackground)
                .ignoresSafeArea(.container, edges: .all)
        )
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsSection()
        case .appearance:
            AppearanceSettingsSection()
        case .about:
            AboutSettingsSection()
        case .worktree:
            WorktreeSettingsSection()
        case .aiConfig:
            AIConfigSettingsSection()
        case .fogNote:
            FogNoteSettingsSection()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select a setting from the sidebar")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsDetailView(section: .general)
        .frame(width: 450, height: 500)
}
