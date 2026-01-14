import SwiftUI
import AppKit

struct AIConfigView: View {
    @StateObject private var scanner = AIConfigScanner()
    @State private var selectedItem: AIConfigItem?
    @State private var searchText: String = ""
    @State private var selectedToolFilter: AIToolType?
    @State private var showPreview: Bool = false

    var filteredItems: [AIConfigItem] {
        var items = scanner.allItems

        // Filter by tool type
        if let toolFilter = selectedToolFilter {
            items = items.filter { $0.toolType == toolFilter }
        }

        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.shortPath.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            headerView

            Divider()

            // Content
            if scanner.isScanning {
                scanningView
            } else if scanner.allItems.isEmpty {
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
        .onAppear {
            if scanner.allItems.isEmpty {
                scanner.scan()
            }
        }
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
                Button(action: { scanner.scan() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .disabled(scanner.isScanning)
                .help("Refresh")
            }

            // Tool filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedToolFilter == nil,
                        count: scanner.allItems.count
                    ) {
                        selectedToolFilter = nil
                    }

                    ForEach(scanner.toolGroups) { group in
                        FilterChip(
                            title: group.name,
                            isSelected: selectedToolFilter == group.toolType,
                            count: group.items.count,
                            color: Color(hex: group.toolType.color)
                        ) {
                            selectedToolFilter = selectedToolFilter == group.toolType ? nil : group.toolType
                        }
                    }
                }
            }
        }
        .padding(8)
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

            Button(action: { scanner.scan() }) {
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
                Image(systemName: item.fileType.toolType.icon)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: item.fileType.toolType.color))

                Text(item.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)

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

            // Preview content
            if let content = scanner.previewContent(for: item) {
                ScrollView {
                    Text(content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    let isSelected: Bool
    let count: Int
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
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

// MARK: - AI Config Row View

struct AIConfigRowView: View {
    let item: AIConfigItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Tool icon
                Image(systemName: item.toolType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: item.toolType.color))
                    .frame(width: 20)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if item.isDirectory {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }

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
        }
        .buttonStyle(.plain)
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
