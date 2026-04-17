import SwiftUI

struct FogNoteView: View {
    @ObservedObject private var storage = NoteStorage.shared
    @State private var selectedNote: Note?
    @State private var isEditing: Bool = false
    @State private var searchText: String = ""

    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return storage.notes
        }
        return storage.notes.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            // Note list
            noteListView
                .frame(minWidth: 120, maxWidth: 160)

            // Note editor
            if let note = selectedNote {
                NoteEditorView(note: binding(for: note), onSave: { updatedNote in
                    storage.updateNote(updatedNote)
                })
            } else {
                emptyStateView
            }
        }
        .onAppear {
            if selectedNote == nil && !storage.notes.isEmpty {
                selectedNote = storage.notes.first
            }
        }
    }

    // MARK: - Note List

    private var noteListView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
            .padding(8)

            Divider()

            // Note list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredNotes) { note in
                        NoteRowView(
                            note: note,
                            isSelected: selectedNote?.id == note.id,
                            onSelect: {
                                selectedNote = note
                            },
                            onDelete: {
                                storage.deleteNote(note)
                                if selectedNote?.id == note.id {
                                    selectedNote = storage.notes.first
                                }
                            },
                            onPin: {
                                storage.togglePin(note)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }

            Divider()

            // New note button
            Button(action: {
                let newNote = storage.createNote()
                selectedNote = newNote
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Note")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.pink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Note Selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Button(action: {
                let newNote = storage.createNote()
                selectedNote = newNote
            }) {
                Text("Create New Note")
                    .font(.system(size: 12))
                    .foregroundColor(.pink)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func binding(for note: Note) -> Binding<Note> {
        Binding(
            get: {
                storage.notes.first { $0.id == note.id } ?? note
            },
            set: { newValue in
                if let index = storage.notes.firstIndex(where: { $0.id == note.id }) {
                    storage.notes[index] = newValue
                }
            }
        )
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.pink)
                        }

                        Text(note.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Text(note.modifiedAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()

                if isHovering {
                    HStack(spacing: 4) {
                        Button(action: onPin) {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
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
            Button(action: onPin) {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Note Editor View

struct NoteEditorView: View {
    @Binding var note: Note
    let onSave: (Note) -> Void

    @State private var content: String = ""
    @State private var showPreview: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Editor or Preview
            if showPreview {
                ScrollView {
                    Text(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                }
            } else {
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
                    .onChange(of: content) { _, newValue in
                        var updatedNote = note
                        updatedNote.update(content: newValue)
                        onSave(updatedNote)
                    }
                    .padding(12)
            }

            Divider()

            // Status bar
            HStack {
                Text("\(content.split(whereSeparator: \.isWhitespace).count) words")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)

                Spacer()

                Text("Modified \(note.modifiedAt, style: .relative)")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)

                Spacer()

                // Preview toggle
                Button(action: { showPreview.toggle() }) {
                    Image(systemName: showPreview ? "pencil" : "eye")
                        .font(.system(size: 10))
                        .foregroundColor(showPreview ? .pink : .gray)
                }
                .buttonStyle(.plain)
                .help(showPreview ? "Edit" : "Preview Markdown")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
        }
        .onAppear {
            content = note.content
        }
        .onChange(of: note.id) { _, _ in
            content = note.content
            showPreview = false  // Reset to edit mode when switching notes
        }
    }
}

#Preview {
    FogNoteView()
        .frame(width: 400, height: 250)
        .background(Color.black)
}
