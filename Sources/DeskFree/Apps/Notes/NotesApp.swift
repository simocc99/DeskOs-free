import SwiftUI

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text = ""
    var modified = Date()

    var title: String {
        let line = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "New Note" : trimmed
    }

    var preview: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return "No additional text" }
        return String(lines[1]).trimmingCharacters(in: .whitespaces)
    }
}

/// Notes are shared by every Notes window and saved as JSON in Application Support.
final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published private(set) var notes: [Note] = []

    private let fileURL: URL

    init(fileURL: URL = DocumentsStore.supportDirectory.appendingPathComponent("notes.json")) {
        self.fileURL = fileURL
        load()
        if notes.isEmpty {
            notes = [Note(text: Self.welcomeText)]
            save()
        }
    }

    func note(_ id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func create(text: String = "") -> UUID {
        let note = Note(text: text)
        notes.insert(note, at: 0)
        save()
        return note.id
    }

    func update(_ id: UUID, text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        notes[i].modified = Date()
        if i != 0 {
            let note = notes.remove(at: i)
            notes.insert(note, at: 0)
        }
        save()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if notes.isEmpty { notes = [Note()] }
        save()
    }

    func importTextFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        create(text: text)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return }
        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static let welcomeText = """
    Welcome to DeskFree
    Your iPhone, with a desktop.

    • Tap a Dock icon to open an app. Tap it again to minimise.
    • Drag a window by its title bar, resize it from the edges.
    • Green button (or double-tap the title bar) maximises.
    • Search apps, files and the web with the magnifier in the menu bar.
    • Plug in a display (USB-C / HDMI / AirPlay) and your phone becomes a trackpad.
    """
}

final class NotesModel: ObservableObject, KeyInputTarget {
    @Published var selectedID: UUID?
    @Published var search = ""
    let store = NotesStore.shared

    init() {
        selectedID = store.notes.first?.id
    }

    var currentID: UUID? {
        if let id = selectedID, store.note(id) != nil { return id }
        return store.notes.first?.id
    }

    func handle(_ key: KeyInput) {
        guard let id = currentID, let note = store.note(id) else { return }
        switch key {
        case .text(let s): store.update(id, text: note.text + s)
        case .backspace: store.update(id, text: String(note.text.dropLast()))
        case .enter: store.update(id, text: note.text + "\n")
        }
    }
}

struct NotesWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: NotesModel
    @ObservedObject private var store = NotesStore.shared

    init(window: DeskWindow) {
        self.window = window
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: window.id) { NotesModel() })
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 460 {
                HStack(spacing: 0) {
                    sidebar.frame(width: 190)
                    Divider()
                    editor
                }
            } else {
                narrowLayout
            }
        }
    }

    private var filtered: [Note] {
        let q = model.search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.notes }
        return store.notes.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $model.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    model.selectedID = store.create()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            .padding(8)

            Divider()

            List(selection: Binding(get: { model.currentID }, set: { model.selectedID = $0 })) {
                ForEach(filtered) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(note.preview).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .tag(note.id)
                    .swipeActions {
                        Button(role: .destructive) { store.delete(note.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let id = model.currentID {
            VStack(spacing: 0) {
                HStack {
                    if let note = store.note(id) {
                        Text(note.modified.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        store.delete(id)
                        model.selectedID = store.notes.first?.id
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
                TextEditor(text: Binding(
                    get: { store.note(id)?.text ?? "" },
                    set: { store.update(id, text: $0) }
                ))
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
            }
        } else {
            Text("No note selected").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Narrow windows show either the list or the editor.
    @ViewBuilder
    private var narrowLayout: some View {
        if model.selectedID == nil {
            sidebar.background(Color(uiColor: .systemBackground))
        } else {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        model.selectedID = nil
                    } label: {
                        Label("Notes", systemImage: "chevron.left")
                    }
                    Spacer()
                }
                .padding(8)
                Divider()
                editor
            }
            .background(Color(uiColor: .systemBackground))
        }
    }
}
