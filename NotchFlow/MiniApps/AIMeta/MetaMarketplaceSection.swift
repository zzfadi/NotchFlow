import SwiftUI

/// One marketplace's worth of plugins — header with name/count, a wrap of
/// `MetaPluginCard` rows. Renders inside the outer `AIMetaView` for each
/// marketplace ID in `MetaMarketplaceStore.orderedMarketplaceIds`.
struct MetaMarketplaceSection: View {
    let title: String
    let subtitle: String?
    let plugins: [MetaPlugin]
    let isLocal: Bool
    let onRemove: (() -> Void)?

    @State private var isHoveringHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
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

            Text("\(plugins.count)")
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

    private var emptyBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text(isLocal
                 ? "No AI components found in your granted folders yet. Add project folders in Settings → Permissions."
                 : "No plugins in this marketplace yet.")
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

    private var pluginList: some View {
        VStack(spacing: 6) {
            ForEach(plugins) { plugin in
                MetaPluginCard(plugin: plugin)
            }
        }
    }
}

#Preview {
    MetaMarketplaceSection(
        title: "My Machine",
        subtitle: "AI components already on this Mac",
        plugins: [],
        isLocal: true,
        onRemove: nil
    )
    .padding()
    .background(Color.black)
    .frame(width: 460)
}
