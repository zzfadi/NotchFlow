import SwiftUI
import AppKit

/// Compact card for a single `MetaPlugin`. Designed for the constrained
/// width of the notch panel, so everything beyond the plugin name is kept
/// secondary (chips, source) or deferred to hover (actions).
struct MetaPluginCard: View {
    let plugin: MetaPlugin

    @State private var isHovering = false
    @State private var copiedFeedback = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            sourceBadge

            VStack(alignment: .leading, spacing: 4) {
                titleRow
                if let description = plugin.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !plugin.components.isEmpty {
                    chipsRow
                }
                sourceRow
            }

            Spacer(minLength: 0)

            if isHovering {
                actionButtons
                    .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(isHovering ? 0.12 : 0.06), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Source badge

    private var sourceBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(sourceColor.opacity(0.2))
                .frame(width: 28, height: 28)
            Image(systemName: sourceIconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(sourceColor)
        }
    }

    private var sourceIconName: String {
        switch plugin.source {
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .git: return "arrow.triangle.branch"
        case .npm: return "shippingbox.fill"
        case .url: return "link"
        case .relative: return "folder.fill"
        case .local: return "internaldrive.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var sourceColor: Color {
        switch plugin.source {
        case .github: return Color(hex: "8B5CF6") ?? .purple
        case .git: return Color(hex: "F97316") ?? .orange
        case .npm: return Color(hex: "DC2626") ?? .red
        case .url: return Color(hex: "06B6D4") ?? .cyan
        case .relative: return Color(hex: "FBBF24") ?? .yellow
        case .local: return Color(hex: "10B981") ?? .green
        case .unknown: return Color(hex: "6B7280") ?? .gray
        }
    }

    // MARK: - Title row

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(plugin.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let version = plugin.version {
                Text("v\(version)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                    )
                    .foregroundColor(.secondary)
            }

            if plugin.isInstalled {
                Text("installed")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.opacity(0.2))
                    )
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Chips

    private var chipsRow: some View {
        HStack(spacing: 4) {
            ForEach(plugin.components.chips) { chip in
                let color = Color(hex: chip.colorHex) ?? .secondary
                HStack(spacing: 3) {
                    Image(systemName: chip.systemImage)
                        .font(.system(size: 8, weight: .medium))
                    Text("\(chip.count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                .foregroundColor(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                )
                .help("\(chip.count) \(chip.label.lowercased())")
            }
        }
    }

    // MARK: - Source row

    private var sourceRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "link.circle")
                .font(.system(size: 9))
            Text(plugin.source.label)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundColor(.secondary)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 4) {
            if case .local(let url) = plugin.source {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }

            if let installCommand = plugin.source.installCommand {
                Button {
                    copyToPasteboard(installCommand)
                } label: {
                    Image(systemName: copiedFeedback ? "checkmark.circle.fill" : "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(copiedFeedback ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(copiedFeedback ? "Copied" : "Copy install command")
            }

            if let homepage = plugin.homepage {
                Button {
                    NSWorkspace.shared.open(homepage)
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Open homepage")
            }
        }
        .foregroundColor(.secondary)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        withAnimation { copiedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { copiedFeedback = false }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        MetaPluginCard(plugin: MetaPlugin(
            id: "preview:1",
            name: "my-project",
            displayName: "My Project",
            description: "A sample AI config collection for previewing.",
            version: "1.2.0",
            author: nil,
            homepage: URL(string: "https://example.com"),
            license: "MIT",
            category: "Local",
            keywords: [],
            source: .local(URL(fileURLWithPath: "/Users/demo/Projects/my-project")),
            components: ComponentSummary(rules: 3, skills: 1, prompts: 5, agents: 2, mcpServers: 1),
            marketplaceId: "local.my-machine",
            rawSource: nil,
            isInstalled: true,
            isEnabled: true
        ))

        MetaPluginCard(plugin: MetaPlugin(
            id: "preview:2",
            name: "github-copilot-setup",
            displayName: nil,
            description: "Opinionated Copilot config for TypeScript projects.",
            version: "0.3.1",
            author: nil,
            homepage: nil,
            license: nil,
            category: "Remote",
            keywords: [],
            source: .github(repo: "example/copilot-setup", ref: "main", path: nil),
            components: ComponentSummary(rules: 2, prompts: 4),
            marketplaceId: "example.com",
            rawSource: "example/copilot-setup",
            isInstalled: false,
            isEnabled: false
        ))
    }
    .padding()
    .background(Color.black)
    .frame(width: 480)
}
