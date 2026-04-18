import SwiftUI
import AppKit

struct AIConfigView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var store = AIConfigStore.shared
    @State private var selectedItem: AIConfigItem?
    @State private var searchText: String = ""
    @State private var selectedCategoryFilter: AIConfigCategory?
    @State private var selectedProviderFilter: AIProvider?
    @State private var showPreview: Bool = false
    @State private var showingMarketplace: Bool = false

    private var isActive: Bool {
        navigationState.activeApp == MiniAppRegistry.aiMeta.id
    }

    var filteredItems: [AIConfigItem] {
        var items = store.snapshot.items

        // Filter by category (primary)
        if let categoryFilter = selectedCategoryFilter {
            items = items.filter { $0.category == categoryFilter }
        }

        // Filter by provider (secondary, AND logic)
        if let providerFilter = selectedProviderFilter {
            items = items.filter { $0.provider == providerFilter }
        }

        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.shortPath.localizedCaseInsensitiveContains(searchText) ||
                $0.sourcePlugin?.identity.pluginName.localizedCaseInsensitiveContains(searchText) == true ||
                $0.sourcePlugin?.identity.marketplaceId?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return items
    }

    /// Get providers available for the current category filter
    var availableProviders: [AIProvider] {
        guard let category = selectedCategoryFilter,
              let group = store.snapshot.categoryGroups.first(where: { $0.category == category }) else {
            return []
        }
        return group.providers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerView

            Divider()

            // Content
            if store.isScanning {
                scanningView
            } else if store.snapshot.items.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    configListView
                        .frame(minWidth: 200)

                    if showPreview, let item = selectedItem {
                        previewView(for: item)
                            .frame(minWidth: 150)
                    }
                }
            }
        }
        // Gate the initial scan on being the *active* tab so TCC prompts
        // don't fire at notch-open time for every tab in the ZStack. See
        // the matching pattern in `WorktreeView` for the why.
        .onAppear { scanIfNeeded() }
        .onChange(of: navigationState.activeApp) { _, _ in scanIfNeeded() }
        .sheet(isPresented: $showingMarketplace, onDismiss: {
            MarketplaceFilter.shared.reset()
        }) {
            AIMetaView(onDismiss: { showingMarketplace = false })
                .environmentObject(navigationState)
                .frame(minWidth: 460, minHeight: 400)
        }
    }

    private func scanIfNeeded() {
        guard isActive else { return }
        store.scanIfNeeded()
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))

                    TextField("Search configs", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)

                // Preview toggle
                Button(action: { showPreview.toggle() }) {
                    Image(systemName: showPreview ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 11))
                        .foregroundColor(showPreview ? .pink : .gray)
                }
                .buttonStyle(.plain)
                .help("Toggle preview")

                // Refresh button
                Button(action: { store.scan() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .disabled(store.isScanning)
                .help("Refresh")

                // Marketplace button — opens AIMetaView in a sheet.
                // Keeps the AI Config view as the primary surface while
                // letting the user browse / install marketplace plugins
                // without losing their place.
                Button(action: { showingMarketplace = true }) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Browse marketplaces")
            }

            // Category filters (primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // "All" filter
                    FilterChip(
                        title: "All",
                        isSelected: selectedCategoryFilter == nil,
                        count: store.snapshot.items.count
                    ) {
                        selectedCategoryFilter = nil
                        selectedProviderFilter = nil
                    }

                    // Category filters
                    ForEach(store.snapshot.categoryGroups) { group in
                        FilterChip(
                            title: group.name,
                            icon: group.icon,
                            isSelected: selectedCategoryFilter == group.category,
                            count: group.items.count,
                            color: Color(hex: group.color) ?? .gray
                        ) {
                            if selectedCategoryFilter == group.category {
                                selectedCategoryFilter = nil
                                selectedProviderFilter = nil
                            } else {
                                selectedCategoryFilter = group.category
                                selectedProviderFilter = nil
                            }
                        }
                    }

                    // Provider sub-filters (when category selected)
                    if selectedCategoryFilter != nil && availableProviders.count > 1 {
                        Divider()
                            .frame(height: 16)
                            .padding(.horizontal, 4)

                        ForEach(availableProviders, id: \.self) { provider in
                            let count = filteredItemsForProvider(provider)
                            ProviderChip(
                                provider: provider,
                                isSelected: selectedProviderFilter == provider,
                                count: count
                            ) {
                                selectedProviderFilter = selectedProviderFilter == provider ? nil : provider
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
    }

    private func filteredItemsForProvider(_ provider: AIProvider) -> Int {
        guard let category = selectedCategoryFilter,
              let group = store.snapshot.categoryGroups.first(where: { $0.category == category }) else {
            return 0
        }
        return group.itemsByProvider[provider]?.count ?? 0
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Scanning for AI configs...")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text("No AI Configs Found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Text("Configure scan directories in Settings")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.7))

            Button(action: { store.scan() }) {
                Text("Scan Again")
                    .font(.system(size: 12))
                    .foregroundColor(.pink)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Config List

    private var configListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredItems) { item in
                    AIConfigRowView(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        onSelect: {
                            selectedItem = item
                            if !showPreview {
                                showPreview = true
                            }
                        },
                        onFocusPlugin: { identity in
                            MarketplaceFilter.shared.focus(identity)
                            showingMarketplace = true
                        }
                    )
                }
            }
            .padding(4)
        }
    }

    // MARK: - Preview View

    private func previewView(for item: AIConfigItem) -> some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: item.category.icon)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: item.category.color) ?? .gray)

                Text(item.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)

                if item.provider != .generic {
                    Text(item.provider.compactName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                }

                Spacer()

                Button(action: { openInEditor(item.path) }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Open in editor")
            }
            .padding(8)
            .background(Color.black.opacity(0.3))

            Divider()

            // Metadata display for skills
            if let metadata = item.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    if let description = metadata.description {
                        Text(description)
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cyan.opacity(0.05))

                Divider()
            }

            // Preview content
            if let content = AIConfigScanner.previewContent(for: item) {
                ScrollView {
                    Text(content)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                }
            } else {
                Text("Unable to preview")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Actions

    private func openInEditor(_ path: URL) {
        NSWorkspace.shared.open(path)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let count: Int
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }

                Text(title)
                    .font(.system(size: 10, weight: .medium))

                Text("\(count)")
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(3)
            }
            .foregroundColor(isSelected ? (color ?? .pink) : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? (color ?? .pink).opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? (color ?? .pink).opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Chip (Secondary Filter)

struct ProviderChip: View {
    let provider: AIProvider
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    private var providerColor: Color {
        Color(hex: provider.color) ?? .gray
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: provider.icon)
                    .font(.system(size: 8))

                Text(provider.compactName)
                    .font(.system(size: 9))

                Text("\(count)")
                    .font(.system(size: 8))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(2)
            }
            .foregroundColor(isSelected ? providerColor : Color.gray)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? providerColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? providerColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Config Row View

struct AIConfigRowView: View {
    let item: AIConfigItem
    let isSelected: Bool
    let onSelect: () -> Void
    /// Notifies the parent that the user tapped the row's plugin badge.
    /// Opens the marketplace sheet scoped to this plugin's identity.
    /// `nil` when the row doesn't need badge-tap handling (e.g. preview
    /// usage). Defaults to no-op for source compatibility.
    var onFocusPlugin: ((PluginIdentity) -> Void)? = nil

    @State private var isHovering: Bool = false

    var body: some View {
        // Row is a container (not a single Button) so Phase 2 can drop a
        // tappable provenance badge inside without running into nested-
        // Button issues in SwiftUI. Row selection is a tap gesture on the
        // background; individual actions (inline ActionButtons, the
        // context menu) retain their own targets.
        HStack(spacing: 8) {
            // Category icon (primary)
            Image(systemName: item.category.icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: item.category.color) ?? .gray)
                .frame(width: 20)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Global badge
                    if item.isGlobal {
                        Text("Global")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(3)
                    }

                    // Provider badge (secondary)
                    if item.provider != .generic {
                        Text(item.provider.compactName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(3)
                    }

                    if item.isDirectory {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }

                    // Provenance badge — indicates the file came from a
                    // plugin install rather than being hand-edited.
                    // Tap opens the marketplace sheet focused on the
                    // originating plugin.
                    if let provenance = item.sourcePlugin {
                        Button {
                            onFocusPlugin?(provenance.identity)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 7))
                                Text(provenance.identity.pluginName)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                                if let v = provenance.version {
                                    Text("v\(v)")
                                        .font(.system(size: 7, design: .monospaced))
                                        .opacity(0.7)
                                }
                            }
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.cyan.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("From plugin \(provenance.identity.pluginName)")
                    }
                }

                // Project name (or path for global configs)
                Text(item.projectName)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Actions or metadata
            if isHovering || isSelected {
                HStack(spacing: 4) {
                    ActionButton(icon: "square.and.pencil", tooltip: "Open in editor") {
                        NSWorkspace.shared.open(item.path)
                    }

                    ActionButton(icon: "folder", tooltip: "Show in Finder") {
                        NSWorkspace.shared.selectFile(item.path.path, inFileViewerRootedAtPath: item.path.deletingLastPathComponent().path)
                    }

                    ActionButton(icon: "doc.on.doc", tooltip: "Copy path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.path.path, forType: .string)
                    }
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.lastModified, style: .relative)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    if let size = item.fileSizeFormatted {
                        Text(size)
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.pink.opacity(0.2) : (isHovering ? Color.white.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(action: { NSWorkspace.shared.open(item.path) }) {
                Label("Open in Editor", systemImage: "square.and.pencil")
            }

            Button(action: {
                NSWorkspace.shared.selectFile(item.path.path, inFileViewerRootedAtPath: item.path.deletingLastPathComponent().path)
            }) {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path.path, forType: .string)
            }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

#Preview {
    AIConfigView()
        .frame(width: 400, height: 250)
        .background(Color.black)
}
