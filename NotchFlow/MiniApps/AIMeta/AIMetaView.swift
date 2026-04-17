import SwiftUI
import AppKit

/// The "AI Meta" mini-app — NotchFlow's cross-tool AI component marketplace.
///
/// PR #3 renders a native card/rail UI powered by `MetaMarketplaceStore`.
/// The "My Machine" synthesized marketplace always shows first, with any
/// user-added remote marketplaces below it. Remote-marketplace add/fetch
/// flow lives in later PRs — the store already exposes the plumbing.
struct AIMetaView: View {
    @ObservedObject private var store = MetaMarketplaceStore.shared
    @ObservedObject private var synthesizer = LocalPluginSynthesizer.shared

    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(Color.white.opacity(0.1))
            content
        }
        .onAppear {
            Task { await store.refreshAll() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            searchField
            Spacer(minLength: 0)
            refreshButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            TextField("Search plugins", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refreshAll() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                .animation(
                    store.isRefreshing
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: store.isRefreshing
                )
        }
        .buttonStyle(.plain)
        .help("Refresh marketplaces")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if shouldShowInitialLoading {
            loadingState
        } else if isCompletelyEmpty {
            emptyState
        } else {
            marketplaceList
        }
    }

    private var shouldShowInitialLoading: Bool {
        synthesizer.isScanning && synthesizer.plugins.isEmpty
    }

    private var isCompletelyEmpty: Bool {
        store.pluginsByMarketplace.values.allSatisfy { $0.isEmpty }
            && !synthesizer.isScanning
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Scanning for AI components…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No AI components yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Grant folder access in Settings → Permissions so NotchFlow can find rules, skills, prompts, and agents in your projects.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Button("Open Permissions") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    private var marketplaceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.orderedMarketplaceIds, id: \.self) { marketplaceId in
                    let allPlugins = store.pluginsByMarketplace[marketplaceId] ?? []
                    let filtered = filter(plugins: allPlugins)
                    MetaMarketplaceSection(
                        title: store.displayName(forMarketplaceId: marketplaceId),
                        subtitle: store.description(forMarketplaceId: marketplaceId),
                        plugins: filtered,
                        isLocal: marketplaceId == synthesizer.marketplace.id,
                        onRemove: removalHandler(for: marketplaceId)
                    )
                }

                if let error = store.lastFetchError {
                    errorBanner(error)
                }
            }
            .padding(12)
        }
    }

    private func filter(plugins: [MetaPlugin]) -> [MetaPlugin] {
        guard !searchText.isEmpty else { return plugins }
        return plugins.filter { plugin in
            plugin.title.localizedCaseInsensitiveContains(searchText)
                || (plugin.description ?? "").localizedCaseInsensitiveContains(searchText)
                || plugin.source.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func removalHandler(for marketplaceId: String) -> (() -> Void)? {
        guard marketplaceId != synthesizer.marketplace.id,
              let url = URL(string: marketplaceId) else {
            return nil
        }
        return { store.removeMarketplace(url) }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.08))
        )
    }
}

#Preview {
    AIMetaView()
        .environmentObject(NavigationState())
        .frame(width: 500, height: 400)
        .background(Color.black)
}
