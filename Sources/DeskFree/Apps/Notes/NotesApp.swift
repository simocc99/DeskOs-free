import SwiftUI

/// Plain-text editor for files in Documents (.txt, .md). Opening a text file from Files
/// edits it in place; a new file is only created once something is typed.
final class NotesModel: NSObject, ObservableObject, KeyInputTarget, PointerInteractive, MenuContributing {
    let windowID: UUID

    @Published var fileURL: URL?
    @Published var text = ""
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    weak var textView: UITextView?
    private var pendingSave: DispatchWorkItem?

    init(windowID: UUID, url: URL?) {
        self.windowID = windowID
        super.init()
        if let url { open(url) }
    }

    static var textFiles: [URL] {
        DocumentsStore.allFiles()
            .filter { ["txt", "md"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(40)
            .map { $0 }
    }

    /// "Folder/File.txt", relative to Documents.
    static func displayName(for url: URL) -> String {
        let base = DocumentsStore.root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(base + "/") else { return url.lastPathComponent }
        return String(path.dropFirst(base.count + 1))
    }

    // MARK: Files

    func open(_ url: URL) {
        saveNow()
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        fileURL = url
        text = content
        updateTitle()
    }

    func newFile() {
        saveNow()
        fileURL = nil
        text = ""
        updateTitle()
    }

    func textDidChange(_ newText: String) {
        text = newText
        refreshUndoState()
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        if fileURL == nil {
            guard !text.isEmpty else { return }
            fileURL = DocumentsStore.uniqueURL(in: DocumentsStore.root, name: "Untitled.txt")
            updateTitle()
        }
        guard let url = fileURL else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    func export() {
        saveNow()
        if let url = fileURL { DeskSession.shared.presenter.share(url) }
    }

    private func updateTitle() {
        let title = fileURL.map(Self.displayName(for:)) ?? "Untitled"
        DeskSession.shared.windows.setTitle(windowID, title)
    }

    // MARK: Editing

    func undo() { textView?.undoManager?.undo(); syncFromView() }
    func redo() { textView?.undoManager?.redo(); syncFromView() }

    func indent() {
        guard let view = textView else { return }
        let ns = view.text as NSString
        let lineStart = ns.lineRange(for: view.selectedRange).location
        let caret = view.selectedRange
        view.selectedRange = NSRange(location: lineStart, length: 0)
        view.insertText("    ")
        view.selectedRange = NSRange(location: caret.location + 4, length: caret.length)
        syncFromView()
    }

    private func syncFromView() {
        if let view = textView { textDidChange(view.text) }
    }

    private func refreshUndoState() {
        canUndo = textView?.undoManager?.canUndo ?? false
        canRedo = textView?.undoManager?.canRedo ?? false
    }

    // MARK: Input from the trackpad

    func handle(_ key: KeyInput) {
        if let view = textView {
            switch key {
            case .text(let s): view.insertText(s)
            case .backspace: view.deleteBackward()
            case .enter: view.insertText("\n")
            }
            syncFromView()
        } else {
            switch key {
            case .text(let s): textDidChange(text + s)
            case .backspace: textDidChange(String(text.dropLast()))
            case .enter: textDidChange(text + "\n")
            }
        }
    }

    func pointerClick(at point: CGPoint) {
        if point.y > 42 { DeskSession.shared.requestKeyboard() }
    }

    func pointerScroll(by delta: CGPoint) {
        guard let view = textView else { return }
        var offset = view.contentOffset
        let maxY = max(0, view.contentSize.height - view.bounds.height)
        offset.y = min(max(offset.y - delta.y * 2, 0), maxY)
        view.setContentOffset(offset, animated: false)
    }

    // MARK: Menus

    func fileMenuEntries() -> [MenuEntry] {
        [
            MenuEntry(title: "New Text File") { [weak self] in self?.newFile() },
            MenuEntry(title: "Save", shortcut: "⌘S") { [weak self] in self?.saveNow() }
        ]
    }

    func editMenuEntries() -> [MenuEntry] {
        [
            MenuEntry(title: "Undo", shortcut: "⌘Z", enabled: canUndo) { [weak self] in self?.undo() },
            MenuEntry(title: "Redo", shortcut: "⇧⌘Z", enabled: canRedo) { [weak self] in self?.redo() },
            MenuEntry(title: "Indent") { [weak self] in self?.indent() }
        ]
    }
}

struct NotesWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: NotesModel

    init(window: DeskWindow) {
        self.window = window
        let id = window.id
        let payload = window.payload
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: id) {
            NotesModel(windowID: id, url: payload)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            TextEditorView(model: model)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Menu {
                let files = NotesModel.textFiles
                if files.isEmpty {
                    Text("No text files in Documents")
                }
                ForEach(files, id: \.self) { url in
                    Button(NotesModel.displayName(for: url)) { model.open(url) }
                }
            } label: {
                Label("Open", systemImage: "folder")
                    .font(.system(size: 13))
                    .frame(height: 30)
                    .padding(.horizontal, 6)
            }
            button("doc.badge.plus") { model.newFile() }

            Spacer()

            button("arrow.uturn.backward", enabled: model.canUndo) { model.undo() }
            button("arrow.uturn.forward", enabled: model.canRedo) { model.redo() }
            button("increase.indent") { model.indent() }
            button("square.and.arrow.up", enabled: !model.text.isEmpty) { model.export() }
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func button(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

private struct TextEditorView: UIViewRepresentable {
    @ObservedObject var model: NotesModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        view.backgroundColor = .systemBackground
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        view.delegate = context.coordinator
        view.text = model.text
        model.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        model.textView = view
        if view.text != model.text {
            view.text = model.text
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let model: NotesModel

        init(_ model: NotesModel) {
            self.model = model
        }

        func textViewDidChange(_ textView: UITextView) {
            model.textDidChange(textView.text)
        }
    }
}
