import SwiftUI
import AppKit
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.notchflow.app", category: "settings")

/// A reusable component for editing a list of directory paths
struct PathListEditor: View {
    @Binding var paths: [String]
    let onSave: () -> Void

    @State private var newPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Path list
            if paths.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No directories configured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(paths, id: \.self) { path in
                            PathRow(
                                path: path,
                                onRemove: {
                                    paths.removeAll { $0 == path }
                                    onSave()
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            // Add path controls
            HStack(spacing: 8) {
                TextField("Add path...", text: $newPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addPath(newPath)
                    }

                Button("Add") {
                    addPath(newPath)
                }
                .disabled(newPath.isEmpty)

                Button("Browse...") {
                    browseForDirectory { path in
                        if let path = path {
                            addPath(path)
                        }
                    }
                }
            }
        }
    }

    private func addPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Standardize path for consistent comparison
        let standardized = (trimmed as NSString).standardizingPath

        // Check for duplicates using standardized paths
        let existingStandardized = paths.map { ($0 as NSString).standardizingPath }
        guard !existingStandardized.contains(standardized) else {
            log.info("Path already exists: \(standardized, privacy: .public)")
            return
        }

        // Validate path exists and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            log.warning("Invalid path (not a directory or doesn't exist): \(standardized, privacy: .public)")
            return
        }

        paths.append(standardized)
        onSave()
        newPath = ""
    }

    @MainActor
    private func browseForDirectory(completion: @escaping (String?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            completion(panel.url?.path)
        } else {
            completion(nil)
        }
    }
}

// MARK: - Path Row

private struct PathRow: View {
    let path: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            Text(path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(isHovering ? .red : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PathListEditor(
        paths: .constant([
            "/Users/developer/Code",
            "/Users/developer/Projects",
            "/Users/developer/GitHub"
        ]),
        onSave: {}
    )
    .padding()
    .frame(width: 400)
}
