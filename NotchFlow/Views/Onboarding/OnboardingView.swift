import SwiftUI
import AppKit

/// First-launch onboarding: greets the user, seeds safe defaults, and lets
/// them explicitly grant access to the project folders NotchFlow will scan.
///
/// Presenting the `NSOpenPanel` here (instead of on first tab-click) is the
/// whole point — the OS treats a user-initiated panel pick as consent, so
/// macOS never pops a TCC dialog mid-scan later on.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case folders
        case finish

        var title: String {
            switch self {
            case .welcome: return "Welcome to NotchFlow"
            case .folders: return "Choose your project folders"
            case .finish: return "You're all set"
            }
        }
    }

    @State private var step: Step = .welcome
    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    /// Called when the user finishes onboarding (or skips). Host is responsible
    /// for closing the onboarding window and revealing the notch.
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.15)

            Group {
                switch step {
                case .welcome: welcomeStep
                case .folders: foldersStep
                case .finish: finishStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)

            Divider()
                .opacity(0.15)

            footer
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 460, idealHeight: 520)
        .background(VisualEffectBackground(material: .contentBackground))
        .onAppear {
            // Seed safe defaults eagerly — they don't need consent and showing
            // them populated on the Folders step reassures the user that
            // common tool-config paths are already being picked up.
            permissions.seedToolConfigDefaults()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(settings.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.headline)
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            stepIndicator
        }
        .padding(20)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s.rawValue <= step.rawValue ? settings.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Welcome step

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NotchFlow lives in your menu bar and brings quick-access tools to the notch.")
                .font(.title3)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(
                    icon: "arrow.triangle.branch",
                    color: .orange,
                    title: "Worktrees",
                    body: "Browse and clean up git worktrees across your repos."
                )
                featureRow(
                    icon: "square.grid.3x3.fill",
                    color: .cyan,
                    title: "AI Meta",
                    body: "Discover and install AI plugins across Claude Code, Cursor, Copilot, and VS Code — in one place."
                )
                featureRow(
                    icon: "note.text",
                    color: settings.accentColor,
                    title: "Fog Notes",
                    body: "Quick notes that live in the notch."
                )
            }

            Spacer(minLength: 0)

            Text("To scan your code and configs, NotchFlow needs read access to the folders you care about. You'll pick them next — we'll only ever read what you grant.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(body).font(.system(size: 12)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Folders step

    private var foldersStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick folders NotchFlow may scan. You can change these any time in Settings.")
                .font(.callout)
                .foregroundColor(.secondary)

            quickAddRow

            Divider().opacity(0.2)

            if permissions.grantedFolders.isEmpty {
                emptyGrantsPlaceholder
            } else {
                grantedFoldersList
            }

            Spacer(minLength: 0)

            Button {
                permissions.requestAccessViaPanel(multiSelect: true)
            } label: {
                Label("Add folders…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.accentColor)
        }
    }

    private var quickAddRow: some View {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let quickPicks: [(String, String)] = [
            ("~/Developer", "\(home)/Developer"),
            ("~/Projects", "\(home)/Projects"),
            ("~/Code", "\(home)/Code"),
            ("~/GitHub", "\(home)/GitHub"),
            ("~/Repos", "\(home)/Repos")
        ]

        return VStack(alignment: .leading, spacing: 6) {
            Text("Quick picks (only shown if they exist on your Mac)")
                .font(.caption)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(quickPicks, id: \.1) { pick in
                    if FileManager.default.fileExists(atPath: pick.1) {
                        quickPickChip(label: pick.0, path: pick.1)
                    }
                }
            }
        }
    }

    private func quickPickChip(label: String, path: String) -> some View {
        let url = URL(fileURLWithPath: path)
        let isGranted = permissions.grantedFolders.contains { $0.url.path == url.standardizedFileURL.path }

        return Button {
            _ = permissions.addGrant(for: url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isGranted ? settings.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            )
            .foregroundColor(isGranted ? settings.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .disabled(isGranted)
    }

    private var emptyGrantsPlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No folders granted yet")
                    .font(.system(size: 13, weight: .medium))
                Text("Use the quick picks above or click “Add folders…” below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var grantedFoldersList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Granted (\(permissions.grantedFolders.count))")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(permissions.grantedFolders) { folder in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(settings.accentColor)
                                .font(.system(size: 12))

                            Text(folder.displayPath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button {
                                permissions.revoke(folder)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help("Remove this folder")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }

    // MARK: - Finish step

    private var finishStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(settings.accentColor)

            Text("You're ready")
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text("NotchFlow can read \(permissions.grantedFolders.count) folder\(permissions.grantedFolders.count == 1 ? "" : "s").")
                    .font(.callout)
                Text("The notch will appear when you close this window. Click the menu-bar icon any time to show it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") { goBack() }
                    .keyboardShortcut(.cancelAction)
            }

            Spacer()

            if step == .folders && permissions.grantedFolders.isEmpty {
                Text("You can finish without granting folders — NotchFlow will only see global tool configs.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button(primaryButtonLabel) { goForward() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(settings.accentColor)
        }
        .padding(20)
    }

    private var primaryButtonLabel: String {
        switch step {
        case .welcome: return "Continue"
        case .folders: return permissions.grantedFolders.isEmpty ? "Skip for now" : "Continue"
        case .finish: return "Open NotchFlow"
        }
    }

    private func goForward() {
        switch step {
        case .welcome:
            step = .folders
        case .folders:
            step = .finish
        case .finish:
            settings.onboardingComplete = true
            onFinish()
        }
    }

    private func goBack() {
        switch step {
        case .welcome: break
        case .folders: step = .welcome
        case .finish: step = .folders
        }
    }
}

// MARK: - FlowLayout

/// Minimal wrap-on-overflow layout so the quick-pick chips wrap cleanly
/// without forcing us to pull in a third-party dependency.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, x - spacing)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, x - spacing)
        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onFinish: {})
        .frame(width: 600, height: 520)
}
