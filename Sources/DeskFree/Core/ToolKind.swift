import SwiftUI

/// Every tool (app) that can live in a desktop window.
enum ToolKind: String, CaseIterable, Identifiable, Codable {
    // Declaration order is the Dock order.
    case files, browser, preview, notes, video, calculator, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browser: return "Browser"
        case .files: return "Files"
        case .preview: return "Preview"
        case .video: return "Video Editor"
        case .notes: return "Notes"
        case .calculator: return "Calculator"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .browser: return "safari.fill"
        case .files: return "folder.fill"
        case .preview: return "doc.richtext.fill"
        case .video: return "film.fill"
        case .notes: return "note.text"
        case .calculator: return "plus.forwardslash.minus"
        case .settings: return "gearshape.fill"
        }
    }

    /// Two colours used for the Dock icon gradient.
    var gradient: [Color] {
        switch self {
        case .browser: return [Color(red: 0.25, green: 0.62, blue: 1.0), Color(red: 0.05, green: 0.35, blue: 0.9)]
        case .files: return [Color(red: 0.35, green: 0.75, blue: 1.0), Color(red: 0.1, green: 0.5, blue: 0.95)]
        case .preview: return [Color(red: 1.0, green: 0.45, blue: 0.4), Color(red: 0.85, green: 0.15, blue: 0.2)]
        case .video: return [Color(red: 0.7, green: 0.45, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.85)]
        case .notes: return [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 1.0, green: 0.65, blue: 0.1)]
        case .calculator: return [Color(red: 0.45, green: 0.45, blue: 0.5), Color(red: 0.2, green: 0.2, blue: 0.24)]
        case .settings: return [Color(red: 0.62, green: 0.65, blue: 0.7), Color(red: 0.4, green: 0.43, blue: 0.48)]
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .browser: return CGSize(width: 820, height: 520)
        case .files: return CGSize(width: 700, height: 460)
        case .preview: return CGSize(width: 760, height: 560)
        case .video: return CGSize(width: 800, height: 560)
        case .notes: return CGSize(width: 620, height: 420)
        case .calculator: return CGSize(width: 300, height: 440)
        case .settings: return CGSize(width: 560, height: 440)
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .calculator: return CGSize(width: 240, height: 360)
        case .settings: return CGSize(width: 380, height: 300)
        default: return CGSize(width: 340, height: 240)
        }
    }

    /// Extra search terms used by the Spotlight-style search.
    var keywords: [String] {
        switch self {
        case .browser: return ["web", "internet", "safari", "chrome", "www", "site", "navigate"]
        case .files: return ["finder", "folder", "documents", "file manager", "explorer"]
        case .preview: return ["pdf", "image", "photo", "annotate", "highlight", "document", "read", "sign", "picture"]
        case .video: return ["movie", "edit", "trim", "cut", "clip", "film", "export"]
        case .notes: return ["text", "write", "memo", "notepad", "editor"]
        case .calculator: return ["math", "calc", "numbers", "compute"]
        case .settings: return ["preferences", "wallpaper", "display", "options", "dock"]
        }
    }
}
