import SwiftUI

/// One marketplace's worth of plugins — header with name/count, a wrap of
/// `MetaPluginCard` rows. Renders inside the outer `AIMetaView` for each
/// marketplace ID in `MetaMarketplaceStore.orderedMarketplaceIds`.
///
/// Empty-body text adapts to whether the list is genuinely empty (no
/// plugins at all) or just search-filtered to zero. The section also
/// always renders its header so remove controls and the "My Machine"
/// slot stay visible even when no plugins match.
struct MetaMarketplaceSection: View {
    let title: String
    let subtitle: String?
    /// Plugins to display — already search-filtered by the caller.
    let plugins: [MetaPlugin]
    /// Total plugin count before search filtering. Lets us tell "no
    /// matches" apart from "genuinely empty".
    let totalPluginCount: Int
    let isSearchActive: Bool
    let isLocal: Bool
    let fetchError: String?
    let onRemove: (() -> Void)?
    let onOpenPermissions: (() -> Void)?

    @State private var isHoveringHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let fetchError {
                errorBanner(fetchError)
            }
            if plugins.isEmpty {
                emptyBody
            } else {
                pluginList
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isLocal ? "internaldrive.fill" : "globe")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isLocal ? Color.green : Color.cyan)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            // Count reflects the total — search filtering is a view concern,
            // not a change to what the marketplace actually contains.
            Text("\(totalPluginCount)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if isHoveringHeader, let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove marketplace")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHoveringHeader = hovering
            }
        }
    }

    @ViewBuilder
    private var emptyBody: some View {
        if isSearchActive && totalPluginCount > 0 {
            // Plugins exist; the search just excluded them. Don't nag about
            // permissions here — that would be misleading.
            noMatchesBody
        } else if isLocal {
            localEmptyBody
        } else {
            remoteEmptyBody
        }
    }

    private var noMatchesBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("No plugins here match your search.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var localEmptyBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("No AI components found in your granted folders yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onOpenPermissions {
                    Button("Open Permissions…", action: onOpenPermissions)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var remoteEmptyBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("No plugins in this marketplace yet.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var pluginList: some View {
        VStack(spacing: 6) {
            ForEach(plugins) { plugin in
                MetaPluginCard(plugin: plugin)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MetaMarketplaceSection(
            title: "My Machine",
            subtitle: "AI components already on this Mac",
            plugins: [],
            totalPluginCount: 0,
            isSearchActive: false,
            isLocal: true,
            fetchError: nil,
            onRemove: nil,
            onOpenPermissions: {}
        )

        MetaMarketplaceSection(
            title: "example.com",
            subtitle: nil,
            plugins: [],
            totalPluginCount: 5,
            isSearchActive: true,
            isLocal: false,
            fetchError: nil,
            onRemove: {},
            onOpenPermissions: nil
        )
    }
    .padding()
    .background(Color.black)
    .frame(width: 460)
}
