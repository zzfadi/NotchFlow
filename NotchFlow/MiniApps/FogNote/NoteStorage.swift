import Foundation
import Combine
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.notchflow.app", category: "fognote")

@MainActor
class NoteStorage: ObservableObject {
    /// Shared instance so notes persist across tab switches and the app can
    /// prewarm the load at launch. Views bind via `@ObservedObject` to this.
    static let shared = NoteStorage()

    @Published var notes: [Note] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    @Published var saveError: String?

    private let settings = SettingsManager.shared
    private var saveDebouncer: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    private var storageURL: URL {
        let directory = URL(fileURLWithPath: settings.fogNotesDirectory)
        return directory.appendingPathComponent("notes.json")
    }

    init() {
        setupDebouncer()
        loadNotes()
    }

    // MARK: - Setup

    private func setupDebouncer() {
        saveDebouncer = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.performSave()
            }
    }

    // MARK: - CRUD Operations

    func loadNotes() {
        isLoading = true
        loadError = nil
        let url = storageURL

        Task.detached(priority: .userInitiated) {
            var loadedNotes: [Note] = []
            var errorMessage: String?

            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let data = try Data(contentsOf: url)
                    loadedNotes = try JSONDecoder().decode([Note].self, from: data)
                } catch {
                    errorMessage = "Failed to load notes: \(error.localizedDescription)"
                }
            }

            let sortedNotes = loadedNotes.sorted { note1, note2 in
                if note1.isPinned != note2.isPinned {
                    return note1.isPinned
                }
                return note1.modifiedAt > note2.modifiedAt
            }

            await MainActor.run {
                self.notes = sortedNotes
                self.loadError = errorMessage
                self.isLoading = false
                if let errorMessage {
                    ErrorCenter.shared.surface(errorMessage, level: .error, source: "NoteStorage.load")
                }
            }
        }
    }

    func createNote() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            sortNotes()
            scheduleSave()
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        scheduleSave()
    }

    func deleteNote(at indexSet: IndexSet) {
        notes.remove(atOffsets: indexSet)
        scheduleSave()
    }

    func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].togglePin()
            sortNotes()
            scheduleSave()
        }
    }

    // MARK: - Sorting

    private func sortNotes() {
        notes.sort { note1, note2 in
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }
            return note1.modifiedAt > note2.modifiedAt
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveSubject.send()
    }

    private func performSave() {
        let notesToSave = notes
        let url = storageURL
        let directory = URL(fileURLWithPath: settings.fogNotesDirectory)

        Task.detached(priority: .utility) {
            var errorMessage: String?

            // Ensure directory exists
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                errorMessage = "Failed to create notes directory: \(error.localizedDescription)"
            }

            // Save notes (only if directory creation succeeded)
            if errorMessage == nil {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(notesToSave)
                    try data.write(to: url, options: .atomic)
                } catch {
                    errorMessage = "Failed to save notes: \(error.localizedDescription)"
                }
            }

            if let error = errorMessage {
                await MainActor.run {
                    self.saveError = error
                    ErrorCenter.shared.surface(error, level: .error, source: "NoteStorage.save")
                }
            }
        }
    }

    // MARK: - Export

    func exportNote(_ note: Note) -> URL? {
        let directory = URL(fileURLWithPath: settings.fogNotesDirectory)
        let filename = sanitizeFilename(note.title) + ".md"
        let fileURL = directory.appendingPathComponent(filename)

        do {
            try note.content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            log.error("Error exporting note: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let sanitized = name
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        // Return a default filename if the sanitized result is empty
        return sanitized.isEmpty ? "Untitled" : sanitized
    }
}
