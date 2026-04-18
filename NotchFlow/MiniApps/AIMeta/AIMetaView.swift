import SwiftUI
import AppKit

struct AIMetaView: View {
    @ObservedObject private var store = MetaMarketplaceStore.shared
    @ObservedObject private var synthesizer = LocalPluginSynthesizer.shared
    @ObservedObject private var filter = MarketplaceFilter.shared

    @State private var isAddingMarketplace = false
    @State private var urlInputText = ""
    @State private var urlError: String? = nil
    @FocusState private var urlFieldFocused: Bool

    /// Set when embedded in a sheet from `AIConfigView`. Allows the header
    /// to show a close control that dismisses the sheet. `nil` when
    /// rendered as a standalone view (e.g. preview, future full-tab mode).
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(Color.white.opacity(0.1))
            content
        }
        // `refreshIfNeeded()` only fetches on the very first view appearance
        // across the app lifetime. Prior versions fired `refreshAll()` on
        // every `onAppear`, which meant a remote manifest fetch happened on
        // notch-open even when the user never visited the marketplace.
        .onAppear {
            Task { await store.refreshIfNeeded() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            if isAddingMarketplace {
                addMarketplaceBar
            } else {
                searchBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.15), value: isAddingMarketplace)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            searchField
            Spacer(minLength: 0)
            addButton
            refreshButton
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close marketplace")
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            TextField("Search plugins", text: $filter.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .disabled(filter.focusedIdentity != nil)
            if let focused = filter.focusedIdentity {
                Button {
                    filter.clearFocus()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                        Text(focused.pluginName)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.cyan.opacity(0.18))
                    )
                }
                .buttonStyle(.plain)
                .help("Clear focus on \(focused.pluginName)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var addButton: some View {
        Button {
            urlInputText = ""
            urlError = nil
            isAddingMarketplace = true
            DispatchQueue.main.async { urlFieldFocused = true }
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Add marketplace URL")
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

    // MARK: - Add Marketplace Bar

    private var addMarketplaceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)

                TextField("https://example.com/marketplace.json", text: $urlInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($urlFieldFocused)
                    .onSubmit { commitAdd() }
                    .onChange(of: urlInputText) { _, _ in
                        if urlError != nil { urlError = nil }
                    }

                if let clipboard = NSPasteboard.general.string(forType: .string),
                   !clipboard.isEmpty,
                   urlInputText.isEmpty {
                    Button {
                        urlInputText = clipboard
                        urlError = nil
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Paste from clipboard")
                }

                Button(action: commitAdd) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(validatedURL(from: urlInputText) != nil ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
                .help("Add marketplace")
                .disabled(urlInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    isAddingMarketplace = false
                    urlError = nil
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                urlError != nil ? Color.red.opacity(0.5) : Color.cyan.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            )

            if let urlError {
                Text(urlError)
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func commitAdd() {
        let trimmed = urlInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let url = validatedURL(from: trimmed) else {
            withAnimation(.easeInOut(duration: 0.12)) {
                urlError = "Must be a valid http:// or https:// URL"
            }
            return
        }
        guard !store.isSubscribed(to: url) else {
            withAnimation(.easeInOut(duration: 0.12)) {
                urlError = "Already added"
            }
            return
        }
        store.addMarketplace(url)
        isAddingMarketplace = false
        urlError = nil
    }

    private func validatedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else { return nil }
        return url
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if shouldShowInitialLoading {
            loadingState
        } else {
            marketplaceList
        }
    }

    private var shouldShowInitialLoading: Bool {
        synthesizer.isScanning
            && synthesizer.plugins.isEmpty
            && store.subscribedURLs.isEmpty
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

    private var marketplaceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.orderedMarketplaceIds, id: \.self) { marketplaceId in
                    section(for: marketplaceId)
                }
            }
            .padding(12)
        }
    }

    /// Search is only "active" when the search field is visible AND
    /// text is present. Focus mode (triggered by tapping a provenance
    /// badge) sets `isSearchActive` to false even if `searchText` was
    /// non-empty prior — `MarketplaceFilter.focus(_:)` clears search.
    private var isSearchActive: Bool {
        guard !isAddingMarketplace, filter.focusedIdentity == nil else { return false }
        return !filter.searchText.isEmpty
    }

    private func section(for marketplaceId: String) -> MetaMarketplaceSection {
        let allPlugins = store.pluginsByMarketplace[marketplaceId] ?? []
        let filtered = applyFilter(to: allPlugins)
        let isLocal = marketplaceId == synthesizer.marketplace.id
        let isFetching = !isLocal && store.isFetching(marketplaceId: marketplaceId)
        let subtitle: String? = store.description(forMarketplaceId: marketplaceId)
        let fetchError: String? = store.fetchError(forMarketplaceId: marketplaceId)
        let onRemove: (() -> Void)? = removalHandler(for: marketplaceId)
        let onOpenPermissions: (() -> Void)? = permissionsHandler(for: marketplaceId)

        return MetaMarketplaceSection(
            title: store.displayName(forMarketplaceId: marketplaceId),
            subtitle: subtitle,
            plugins: filtered,
            totalPluginCount: allPlugins.count,
            isSearchActive: isSearchActive,
            isLocal: isLocal,
            isFetching: isFetching,
            fetchError: fetchError,
            onRemove: onRemove,
            onOpenPermissions: onOpenPermissions
        )
    }

    private func applyFilter(to plugins: [MetaPlugin]) -> [MetaPlugin] {
        switch filter.activePredicate {
        case .none:
            return plugins
        case .focus(let id):
            return plugins.filter { $0.identity == id }
        case .search(let text):
            return plugins.filter { plugin in
                plugin.title.localizedCaseInsensitiveContains(text)
                    || (plugin.description ?? "").localizedCaseInsensitiveContains(text)
                    || plugin.source.label.localizedCaseInsensitiveContains(text)
            }
        }
    }

    private func removalHandler(for marketplaceId: String) -> (() -> Void)? {
        guard marketplaceId != synthesizer.marketplace.id,
              let url = URL(string: marketplaceId) else {
            return nil
        }
        return { self.store.removeMarketplace(url) }
    }

    private func permissionsHandler(for marketplaceId: String) -> (() -> Void)? {
        guard marketplaceId == synthesizer.marketplace.id else { return nil }
        return { NotificationCenter.default.post(name: .showSettings, object: nil) }
    }
}

#Preview {
    AIMetaView()
        .environmentObject(NavigationState())
        .frame(width: 500, height: 400)
        .background(Color.black)
}
