import SwiftUI

enum Wallpaper: String, CaseIterable, Identifiable {
    case aurora, sunset, ocean, graphite, forest, lavender, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: return "Aurora"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .graphite: return "Graphite"
        case .forest: return "Forest"
        case .lavender: return "Lavender"
        case .custom: return "Photo"
        }
    }

    /// Base colour followed by the colours of the soft light blobs drawn on top.
    var palette: [Color] {
        switch self {
        case .aurora:
            return [Color(red: 0.04, green: 0.06, blue: 0.2), Color(red: 0.1, green: 0.8, blue: 0.7), Color(red: 0.45, green: 0.3, blue: 0.95), Color(red: 0.2, green: 0.5, blue: 1.0)]
        case .sunset:
            return [Color(red: 0.2, green: 0.05, blue: 0.25), Color(red: 1.0, green: 0.45, blue: 0.3), Color(red: 1.0, green: 0.75, blue: 0.3), Color(red: 0.85, green: 0.2, blue: 0.5)]
        case .ocean:
            return [Color(red: 0.0, green: 0.08, blue: 0.22), Color(red: 0.0, green: 0.55, blue: 0.85), Color(red: 0.2, green: 0.85, blue: 0.9), Color(red: 0.05, green: 0.3, blue: 0.7)]
        case .graphite:
            return [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.3, green: 0.32, blue: 0.38), Color(red: 0.18, green: 0.2, blue: 0.25), Color(red: 0.4, green: 0.42, blue: 0.5)]
        case .forest:
            return [Color(red: 0.02, green: 0.1, blue: 0.08), Color(red: 0.15, green: 0.6, blue: 0.35), Color(red: 0.6, green: 0.8, blue: 0.3), Color(red: 0.05, green: 0.4, blue: 0.4)]
        case .lavender:
            return [Color(red: 0.2, green: 0.12, blue: 0.4), Color(red: 0.75, green: 0.55, blue: 1.0), Color(red: 1.0, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.4, blue: 0.95)]
        case .custom:
            return Wallpaper.graphite.palette
        }
    }
}

enum DisplayResolution: String, CaseIterable, Identifiable {
    case hd720, fullHD, qhd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hd720: return "1280 × 720"
        case .fullHD: return "1920 × 1080"
        case .qhd: return "2560 × 1440"
        }
    }

    var size: CGSize {
        switch self {
        case .hd720: return CGSize(width: 1280, height: 720)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .qhd: return CGSize(width: 2560, height: 1440)
        }
    }
}

/// User preferences, persisted in `UserDefaults`.
final class DeskSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var wallpaper: Wallpaper {
        didSet { defaults.set(wallpaper.rawValue, forKey: "wallpaper") }
    }
    /// Bumped each time the custom wallpaper image is replaced, to refresh the view.
    @Published var customWallpaperRevision: Int {
        didSet { defaults.set(customWallpaperRevision, forKey: "customWallpaperRevision") }
    }
    @Published var dockIconSize: Double {
        didSet { defaults.set(dockIconSize, forKey: "dockIconSize") }
    }
    @Published var resolution: DisplayResolution {
        didSet { defaults.set(resolution.rawValue, forKey: "resolution") }
    }
    @Published var pointerSpeed: Double {
        didSet { defaults.set(pointerSpeed, forKey: "pointerSpeed") }
    }
    /// In portrait show a live preview with a trackpad instead of a tiny touch desktop.
    @Published var trackpadInPortrait: Bool {
        didSet { defaults.set(trackpadInPortrait, forKey: "trackpadInPortrait") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        wallpaper = Wallpaper(rawValue: defaults.string(forKey: "wallpaper") ?? "") ?? .aurora
        customWallpaperRevision = defaults.integer(forKey: "customWallpaperRevision")
        let dock = defaults.double(forKey: "dockIconSize")
        dockIconSize = dock == 0 ? 52 : dock
        resolution = DisplayResolution(rawValue: defaults.string(forKey: "resolution") ?? "") ?? .fullHD
        let speed = defaults.double(forKey: "pointerSpeed")
        pointerSpeed = speed == 0 ? 2.0 : speed
        trackpadInPortrait = defaults.object(forKey: "trackpadInPortrait") as? Bool ?? true
    }
}
