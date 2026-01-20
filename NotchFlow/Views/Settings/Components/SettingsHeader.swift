import SwiftUI

/// A visually distinctive header for settings sections
struct SettingsHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color

    init(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color = .accentColor
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accentColor.gradient)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SettingsHeader(
            icon: "gear",
            title: "General",
            subtitle: "Core app preferences",
            accentColor: .blue
        )

        SettingsHeader(
            icon: "paintpalette",
            title: "Appearance",
            subtitle: "Customize how NotchFlow looks",
            accentColor: .purple
        )

        SettingsHeader(
            icon: "arrow.triangle.branch",
            title: "Worktree",
            subtitle: "Git worktree discovery settings",
            accentColor: .orange
        )
    }
    .padding()
    .frame(width: 400)
}
