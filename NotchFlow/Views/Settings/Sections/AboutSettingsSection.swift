import SwiftUI

/// About settings section - app info and links
struct AboutSettingsSection: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(
                    icon: "info.circle",
                    title: "About",
                    subtitle: "NotchFlow information",
                    accentColor: .gray
                )

                // App info card
                GroupBox {
                    VStack(spacing: 16) {
                        // App icon and name
                        HStack(spacing: 16) {
                            Image(systemName: "rectangle.topthird.inset.filled")
                                .font(.system(size: 48))
                                .foregroundStyle(.linearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("NotchFlow")
                                    .font(.title2.bold())

                                Text("Version \(appVersion)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("Build \(buildNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        Divider()

                        // Description
                        Text("A macOS menu bar app that turns your notch into a productivity hub with mini-apps for git worktrees, AI config management, and quick notes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                }

                // Links
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Links", systemImage: "link")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        LinkButton(
                            title: "GitHub Repository",
                            subtitle: "View source code and contribute",
                            icon: "chevron.left.forwardslash.chevron.right",
                            url: "https://github.com/FadiAlzuabi/NotchFlow"
                        )

                        LinkButton(
                            title: "Report an Issue",
                            subtitle: "Found a bug? Let us know",
                            icon: "ladybug",
                            url: "https://github.com/FadiAlzuabi/NotchFlow/issues"
                        )

                        LinkButton(
                            title: "Request a Feature",
                            subtitle: "Have an idea? Share it",
                            icon: "lightbulb",
                            url: "https://github.com/FadiAlzuabi/NotchFlow/discussions"
                        )
                    }
                    .padding(4)
                }

                // Credits
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Credits", systemImage: "heart")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Built with DynamicNotchKit")
                            .font(.subheadline)

                        Text("Made with love for the Mac community")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Link Button

private struct LinkButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let url: String

    @State private var isHovering = false

    var body: some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            } else {
                assertionFailure("[AboutSettings] Invalid URL string: \(url)")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    AboutSettingsSection()
        .frame(width: 450, height: 600)
}
