import Foundation
import UIKit

/// Locations inside the app sandbox. `Documents` is exposed in the Files app
/// (UIFileSharingEnabled) so the user can drop files in and out of DeskFree.
enum DocumentsStore {
    static var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DeskFree", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var exportsDirectory: URL {
        let dir = root.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var trashDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("Trash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A standard sub-folder of Documents (Desktop, Downloads), created on demand.
    static func standardFolder(_ name: String) -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let recentsKey = "recentFiles"

    static func addRecent(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(30)), forKey: recentsKey)
    }

    static func recentFiles() -> [URL] {
        (UserDefaults.standard.stringArray(forKey: recentsKey) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static var wallpaperURL: URL {
        supportDirectory.appendingPathComponent("wallpaper.jpg")
    }

    /// Returns a URL in `directory` that does not exist yet ("name 2.ext", "name 3.ext"...).
    static func uniqueURL(in directory: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        repeat {
            let newName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            n += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    /// Copies a file picked with the system file importer into Documents.
    static func importCopy(of source: URL, into directory: URL? = nil) throws -> URL {
        let target = directory ?? root
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        // Already inside our sandbox: no need to copy.
        if source.path.hasPrefix(root.path) { return source }
        let destination = uniqueURL(in: target, name: source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Files (not folders) under Documents, used by desktop search. Bounded for speed.
    static func allFiles(limit: Int = 800) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: Set(keys)).isDirectory) ?? false
            if !isDir { files.append(url) }
            if files.count >= limit { break }
        }
        return files
    }

    /// Creates (once) a short text file explaining the basics; returns its URL.
    @discardableResult
    static func ensureWelcomeFile() -> URL {
        let url = root.appendingPathComponent("Welcome to DeskFree.txt")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? welcomeText.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    private static let welcomeText = """
    Welcome to DeskFree
    Your iPhone, with a desktop.

    - Tap a Dock icon to open an app; tap it again to minimise.
    - Drag a window by its title bar, resize it from the edges.
    - Green button (or double-tap the title bar) maximises.
    - Magnifier in the menu bar: search apps, files and the web.
    - Launchpad (last Dock icon) shows every app.
    - Plug in a display (USB-C / HDMI / AirPlay): your phone becomes a trackpad.
    """

    static func customWallpaper() -> UIImage? {
        UIImage(contentsOfFile: wallpaperURL.path)
    }

    static func saveWallpaper(_ data: Data) {
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return }
        try? jpeg.write(to: wallpaperURL, options: .atomic)
    }
}
