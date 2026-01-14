import Foundation
import Combine

class NoteStorage: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading: Bool = false

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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var loadedNotes: [Note] = []

            if FileManager.default.fileExists(atPath: self.storageURL.path) {
                do {
                    let data = try Data(contentsOf: self.storageURL)
                    loadedNotes = try JSONDecoder().decode([Note].self, from: data)
                } catch {
                    print("Error loading notes: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.notes = loadedNotes.sorted { note1, note2 in
                    if note1.isPinned != note2.isPinned {
                        return note1.isPinned
                    }
                    return note1.modifiedAt > note2.modifiedAt
                }
                self.isLoading = false
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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Ensure directory exists
            let directory = URL(fileURLWithPath: self.settings.fogNotesDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Save notes
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(self.notes)
                try data.write(to: self.storageURL, options: .atomic)
            } catch {
                print("Error saving notes: \(error)")
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
            print("Error exporting note: \(error)")
            return nil
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
    }
}
