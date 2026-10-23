import Foundation

struct LinkedFolder: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var bookmark: Data
}

/// Folders outside the app (iCloud Drive, "On My iPhone", other apps) the user linked with
/// "Link Folder…". Access is kept through security-scoped bookmarks.
final class LinkedFolders: ObservableObject {
    static let shared = LinkedFolders()

    @Published private(set) var folders: [LinkedFolder] = []

    private let key = "linkedFolders"
    private var openURLs: [UUID: URL] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LinkedFolder].self, from: data) {
            folders = decoded
        }
    }

    func add(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        folders.removeAll { $0.name == url.lastPathComponent }
        folders.append(LinkedFolder(name: url.lastPathComponent, bookmark: bookmark))
        save()
    }

    func remove(_ folder: LinkedFolder) {
        if let url = openURLs[folder.id] {
            url.stopAccessingSecurityScopedResource()
            openURLs[folder.id] = nil
        }
        folders.removeAll { $0.id == folder.id }
        save()
    }

    /// Resolves the bookmark and keeps the security scope open while the app runs.
    func url(for folder: LinkedFolder) -> URL? {
        if let url = openURLs[folder.id] { return url }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        _ = url.startAccessingSecurityScopedResource()
        openURLs[folder.id] = url
        return url
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
