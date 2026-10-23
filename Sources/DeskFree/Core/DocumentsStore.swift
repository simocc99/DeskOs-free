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

    static func customWallpaper() -> UIImage? {
        UIImage(contentsOfFile: wallpaperURL.path)
    }

    static func saveWallpaper(_ data: Data) {
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return }
        try? jpeg.write(to: wallpaperURL, options: .atomic)
    }
}
