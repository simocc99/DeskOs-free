import SwiftUI
import QuickLookThumbnailing

struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date

    var id: URL { url }
    var name: String { url.lastPathComponent }

    var sizeText: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum FilesDialog: Identifiable {
    case newFolder
    case rename(FileItem)
    case delete(FileItem)

    var id: String {
        switch self {
        case .newFolder: return "new"
        case .rename(let item): return "rename-\(item.url.path)"
        case .delete(let item): return "delete-\(item.url.path)"
        }
    }
}

enum FilesPlace: Hashable {
    case recents
    case documents
    case desktop
    case downloads
    case trash
    case linked(UUID)
}

final class FilesModel: ObservableObject {
    enum ViewMode { case grid, list }

    /// Root of the current place (Documents, a linked folder...).
    @Published private(set) var root = DocumentsStore.root
    @Published private(set) var place: FilesPlace = .documents

    @Published private(set) var directory: URL
    @Published private(set) var items: [FileItem] = []
    @Published var selectedURL: URL?
    @Published var search = ""
    @Published var viewMode: ViewMode = .grid
    @Published var dialog: FilesDialog?
    @Published var dialogText = ""
    @Published var errorMessage: String?

    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    init() {
        directory = DocumentsStore.root
        reload()
    }

    // MARK: Derived

    var visibleItems: [FileItem] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var selectedItem: FileItem? {
        items.first { $0.url == selectedURL }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool {
        place != .recents && directory.standardizedFileURL.path != root.standardizedFileURL.path
    }

    var isTrash: Bool { place == .trash }

    var placeTitle: String {
        switch place {
        case .recents: return "Recents"
        case .documents: return "Documents"
        case .desktop: return "Desktop"
        case .downloads: return "Downloads"
        case .trash: return "Trash"
        case .linked(let id): return LinkedFolders.shared.folders.first { $0.id == id }?.name ?? "Folder"
        }
    }

    var relativePath: String {
        if place == .recents { return "Recents" }
        let base = root.standardizedFileURL.path
        let current = directory.standardizedFileURL.path
        guard current.hasPrefix(base) else { return directory.lastPathComponent }
        let rest = String(current.dropFirst(base.count)).split(separator: "/").map(String.init)
        return ([placeTitle] + rest).joined(separator: "  ›  ")
    }

    func show(_ newPlace: FilesPlace) {
        var newRoot: URL?
        switch newPlace {
        case .recents: newRoot = DocumentsStore.root
        case .documents: newRoot = DocumentsStore.root
        case .desktop: newRoot = DocumentsStore.standardFolder("Desktop")
        case .downloads: newRoot = DocumentsStore.standardFolder("Downloads")
        case .trash: newRoot = DocumentsStore.trashDirectory
        case .linked(let id):
            if let folder = LinkedFolders.shared.folders.first(where: { $0.id == id }) {
                newRoot = LinkedFolders.shared.url(for: folder)
            }
        }
        guard let newRoot else {
            errorMessage = "That folder is no longer available."
            return
        }
        backStack.append(directory)
        forwardStack.removeAll()
        place = newPlace
        root = newRoot
        directory = newRoot
        selectedURL = nil
        search = ""
        reload()
    }

    func linkFolder() {
        DeskSession.shared.presenter.importFiles(types: [.folder]) { [weak self] urls in
            guard let url = urls.first else { return }
            LinkedFolders.shared.add(url)
            if let folder = LinkedFolders.shared.folders.first(where: { $0.name == url.lastPathComponent }) {
                self?.show(.linked(folder.id))
            }
        }
    }

    func emptyTrash() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: DocumentsStore.trashDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in urls { try? FileManager.default.removeItem(at: url) }
        reload()
    }

    // MARK: Navigation

    func reload() {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls: [URL]
        if place == .recents {
            urls = DocumentsStore.recentFiles()
        } else {
            urls = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        let mapped = urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return FileItem(
                url: url,
                isDirectory: values?.isDirectory ?? false,
                size: Int64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate ?? .distantPast
            )
        }
        items = place == .recents ? mapped : mapped.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        if let selectedURL, !items.contains(where: { $0.url == selectedURL }) {
            self.selectedURL = nil
        }
    }

    func navigate(to url: URL, recordHistory: Bool = true) {
        if recordHistory {
            backStack.append(directory)
            forwardStack.removeAll()
        }
        directory = url
        selectedURL = nil
        search = ""
        reload()
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(directory)
        navigate(to: previous, recordHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(directory)
        navigate(to: next, recordHistory: false)
    }

    func goUp() {
        guard canGoUp else { return }
        navigate(to: directory.deletingLastPathComponent())
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            DeskSession.shared.openFile(item.url)
        }
    }

    // MARK: Operations

    func createFolder(named name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let url = DocumentsStore.uniqueURL(in: directory, name: clean)
        perform { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) }
    }

    func rename(_ item: FileItem, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != item.name, !clean.contains("/") else { return }
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(clean)
        perform { try FileManager.default.moveItem(at: item.url, to: destination) }
    }

    /// Moves to the app's Trash; items already in the Trash are deleted for good.
    func delete(_ item: FileItem) {
        if isTrash {
            perform { try FileManager.default.removeItem(at: item.url) }
        } else {
            let destination = DocumentsStore.uniqueURL(in: DocumentsStore.trashDirectory, name: item.name)
            perform { try FileManager.default.moveItem(at: item.url, to: destination) }
        }
    }

    func duplicate(_ item: FileItem) {
        let ext = item.url.pathExtension
        let base = item.url.deletingPathExtension().lastPathComponent + " copy"
        let name = ext.isEmpty ? base : "\(base).\(ext)"
        let destination = DocumentsStore.uniqueURL(in: item.url.deletingLastPathComponent(), name: name)
        perform { try FileManager.default.copyItem(at: item.url, to: destination) }
    }

    func importFiles() {
        DeskSession.shared.presenter.importFiles(types: [.item], multiple: true) { [weak self] urls in
            guard let self else { return }
            for url in urls {
                do {
                    _ = try DocumentsStore.importCopy(of: url, into: self.directory)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
            self.reload()
        }
    }

    func share(_ item: FileItem) {
        guard !item.isDirectory else { return }
        DeskSession.shared.presenter.share(item.url)
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
    }
}

/// Thumbnails from QuickLook (images, PDFs, videos, documents, folders...).
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for item: FileItem, size: CGFloat) async -> UIImage? {
        let key = "\(item.url.path)|\(Int(size))|\(item.modified.timeIntervalSince1970)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: size, height: size),
            scale: 2,
            representationTypes: .all
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        cache.setObject(representation.uiImage, forKey: key)
        return representation.uiImage
    }
}
