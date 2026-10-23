import Foundation

struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: String
}

/// Browser bookmarks, shown on the start page of every new tab.
final class BookmarksStore: ObservableObject {
    static let shared = BookmarksStore()

    @Published private(set) var items: [Bookmark] = []

    private let key = "bookmarks"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            items = decoded
        } else {
            items = [
                Bookmark(title: "DuckDuckGo", url: "https://duckduckgo.com"),
                Bookmark(title: "Wikipedia", url: "https://wikipedia.org"),
                Bookmark(title: "GitHub", url: "https://github.com"),
                Bookmark(title: "OpenStreetMap", url: "https://www.openstreetmap.org"),
                Bookmark(title: "Hacker News", url: "https://news.ycombinator.com")
            ]
        }
    }

    func contains(_ url: URL?) -> Bool {
        guard let url else { return false }
        return items.contains { $0.url == url.absoluteString }
    }

    func toggle(title: String, url: URL) {
        if let index = items.firstIndex(where: { $0.url == url.absoluteString }) {
            items.remove(at: index)
        } else {
            items.append(Bookmark(title: title.isEmpty ? (url.host ?? "Bookmark") : title, url: url.absoluteString))
        }
        save()
    }

    func remove(_ bookmark: Bookmark) {
        items.removeAll { $0.id == bookmark.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
