import SwiftUI

struct DeskWindow: Identifiable, Equatable {
    let id: UUID
    var tool: ToolKind
    var title: String
    var frame: CGRect
    /// Frame before the window was maximised; non-nil means "maximised".
    var restoreFrame: CGRect?
    var isMinimized: Bool = false
    var z: Int
    /// Optional resource the tool should open (a PDF, a video, a URL...).
    var payload: URL?

    var isMaximized: Bool { restoreFrame != nil }
}

enum ResizeAnchor: CaseIterable {
    case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
}

enum SnapEdge {
    case left, right, full
}

/// Layout constants shared by the window views and the pointer hit-tester so that
/// what you see is exactly what the virtual pointer can click.
enum WindowMetrics {
    static let menuBarHeight: CGFloat = 30
    static let titleBarHeight: CGFloat = 34
    static let cornerRadius: CGFloat = 12
    static let resizeMargin: CGFloat = 7
    static let trafficLightDiameter: CGFloat = 14
    static let trafficLightLeading: CGFloat = 18
    static let trafficLightSpacing: CGFloat = 22
    static let trafficLightHitRadius: CGFloat = 12

    static func trafficLightCenter(index: Int, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + trafficLightLeading + CGFloat(index) * trafficLightSpacing,
            y: frame.minY + titleBarHeight / 2
        )
    }
}

final class WindowManager: ObservableObject {
    @Published private(set) var windows: [DeskWindow] = []
    @Published private(set) var desktopSize: CGSize
    /// Preferred Dock icon size; the Dock may shrink on small desktops.
    @Published var dockIconPreference: CGFloat = 52

    private var zCounter = 0
    private var openedCount = 0

    init(desktopSize: CGSize = CGSize(width: 1280, height: 720)) {
        self.desktopSize = desktopSize
    }

    // MARK: - Queries

    /// Height reserved at the bottom for the Dock (maximised windows stop above it).
    var dockReserved: CGFloat {
        let dock = DockLayout(desktop: desktopSize, preferredIconSize: dockIconPreference, minimized: [])
        return DockLayout.reservedHeight(forIcon: dock.iconSize)
    }

    var usableArea: CGRect {
        let top = WindowMetrics.menuBarHeight
        return CGRect(
            x: 0,
            y: top,
            width: desktopSize.width,
            height: max(0, desktopSize.height - top - dockReserved)
        )
    }

    func window(_ id: UUID) -> DeskWindow? {
        windows.first { $0.id == id }
    }

    func windows(of tool: ToolKind) -> [DeskWindow] {
        windows.filter { $0.tool == tool }
    }

    var visibleWindows: [DeskWindow] { windows.filter { !$0.isMinimized } }

    var minimizedWindows: [DeskWindow] { windows.filter { $0.isMinimized } }

    var frontmost: DeskWindow? {
        visibleWindows.max { $0.z < $1.z }
    }

    var frontmostID: UUID? { frontmost?.id }

    private func index(of id: UUID) -> Int? {
        windows.firstIndex { $0.id == id }
    }

    private func nextZ() -> Int {
        zCounter += 1
        return zCounter
    }

    // MARK: - Lifecycle

    @discardableResult
    func open(_ tool: ToolKind, payload: URL? = nil, title: String? = nil) -> UUID {
        let area = usableArea
        let size = Self.fit(tool.defaultSize, minimum: tool.minimumSize, in: area)
        let step = CGFloat(openedCount % 6) * 28
        openedCount += 1
        var origin = CGPoint(x: area.minX + 28 + step, y: area.minY + 14 + step)
        origin.x = min(origin.x, max(area.minX, area.maxX - size.width))
        origin.y = min(origin.y, max(area.minY, area.maxY - size.height))
        let window = DeskWindow(
            id: UUID(),
            tool: tool,
            title: title ?? tool.title,
            frame: CGRect(origin: origin, size: size),
            z: nextZ(),
            payload: payload
        )
        windows.append(window)
        return window.id
    }

    /// Dock click behaviour: bring the tool to the front, restoring minimised windows,
    /// or open a new window when the tool is not running.
    func activate(_ tool: ToolKind) {
        let existing = windows(of: tool)
        guard !existing.isEmpty else {
            open(tool)
            return
        }
        if let front = frontmost, front.tool == tool, existing.allSatisfy({ !$0.isMinimized }) {
            // Already in front: minimise like a Dock toggle would.
            minimize(front.id)
            return
        }
        let target = existing.filter { !$0.isMinimized }.max { $0.z < $1.z } ?? existing.last!
        focus(target.id)
    }

    func focus(_ id: UUID) {
        guard let i = index(of: id) else { return }
        windows[i].isMinimized = false
        if frontmostID != id {
            windows[i].z = nextZ()
        }
    }

    func close(_ id: UUID) {
        windows.removeAll { $0.id == id }
    }

    func closeAll() {
        windows.removeAll()
    }

    /// Minimises everything, or brings everything back if the desktop is already clear.
    func toggleShowDesktop() {
        if windows.contains(where: { !$0.isMinimized }) {
            for i in windows.indices { windows[i].isMinimized = true }
        } else {
            for i in windows.indices { windows[i].isMinimized = false }
        }
    }

    func minimize(_ id: UUID) {
        guard let i = index(of: id) else { return }
        windows[i].isMinimized = true
    }

    func toggleMaximize(_ id: UUID) {
        guard let i = index(of: id) else { return }
        if let restore = windows[i].restoreFrame {
            windows[i].frame = restore
            windows[i].restoreFrame = nil
        } else {
            windows[i].restoreFrame = windows[i].frame
            windows[i].frame = usableArea
        }
        focus(id)
    }

    func snap(_ id: UUID, to edge: SnapEdge) {
        guard let i = index(of: id) else { return }
        let area = usableArea
        if windows[i].restoreFrame == nil {
            windows[i].restoreFrame = windows[i].frame
        }
        switch edge {
        case .full:
            windows[i].frame = area
        case .left:
            windows[i].frame = CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        case .right:
            windows[i].frame = CGRect(x: area.midX, y: area.minY, width: area.width / 2, height: area.height)
        }
        focus(id)
    }

    func setTitle(_ id: UUID, _ title: String) {
        guard let i = index(of: id), windows[i].title != title else { return }
        windows[i].title = title
    }

    // MARK: - Geometry

    /// Call when a drag on the title bar starts. A maximised window is restored first,
    /// keeping the grab point under the finger. Returns the frame the drag starts from.
    @discardableResult
    func beginMove(_ id: UUID, grab: CGPoint) -> CGRect {
        guard let i = index(of: id) else { return .zero }
        if let restore = windows[i].restoreFrame {
            let current = windows[i].frame
            let ratio = current.width > 0 ? (grab.x - current.minX) / current.width : 0.5
            var frame = CGRect(
                x: grab.x - restore.width * ratio,
                y: current.minY,
                width: restore.width,
                height: restore.height
            )
            frame = Self.clamped(frame, in: desktopSize)
            windows[i].frame = frame
            windows[i].restoreFrame = nil
        }
        focus(id)
        return windows[i].frame
    }

    func move(_ id: UUID, from start: CGRect, by translation: CGSize) {
        guard let i = index(of: id) else { return }
        var frame = start
        frame.origin.x += translation.width
        frame.origin.y += translation.height
        windows[i].frame = Self.clamped(frame, in: desktopSize)
    }

    func resize(_ id: UUID, anchor: ResizeAnchor, from start: CGRect, by translation: CGSize) {
        guard let i = index(of: id) else { return }
        let bounds = CGRect(
            x: 0,
            y: WindowMetrics.menuBarHeight,
            width: desktopSize.width,
            height: desktopSize.height - WindowMetrics.menuBarHeight
        )
        windows[i].frame = Self.resized(
            start,
            anchor: anchor,
            translation: translation,
            minimum: windows[i].tool.minimumSize,
            bounds: bounds
        )
        windows[i].restoreFrame = nil
    }

    /// Changes the virtual desktop resolution, scaling every window proportionally.
    func setDesktopSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0, newSize != desktopSize else { return }
        let old = desktopSize
        desktopSize = newSize
        let sx = newSize.width / max(old.width, 1)
        let sy = newSize.height / max(old.height, 1)
        let area = usableArea
        for i in windows.indices {
            if windows[i].isMaximized {
                windows[i].frame = area
                if let r = windows[i].restoreFrame {
                    windows[i].restoreFrame = Self.scaled(r, sx: sx, sy: sy, fitting: area, tool: windows[i].tool, desktop: newSize)
                }
            } else {
                windows[i].frame = Self.scaled(windows[i].frame, sx: sx, sy: sy, fitting: area, tool: windows[i].tool, desktop: newSize)
            }
        }
    }

    /// Re-applies the clamping rules, e.g. after the Dock size changed.
    func refit() {
        let area = usableArea
        for i in windows.indices {
            if windows[i].isMaximized {
                windows[i].frame = area
            } else {
                windows[i].frame = Self.clamped(windows[i].frame, in: desktopSize)
            }
        }
    }

    // MARK: - Pure helpers (unit tested)

    static func fit(_ size: CGSize, minimum: CGSize, in area: CGRect) -> CGSize {
        let maxW = max(minimum.width.clamped(to: 0...area.width), area.width * 0.92)
        let maxH = max(minimum.height.clamped(to: 0...area.height), area.height * 0.94)
        return CGSize(
            width: min(size.width, min(maxW, area.width)),
            height: min(size.height, min(maxH, area.height))
        )
    }

    /// Keeps a window reachable: the title bar can never leave the desktop.
    static func clamped(_ frame: CGRect, in desktop: CGSize) -> CGRect {
        var f = frame
        let keep: CGFloat = 80
        f.origin.x = min(max(f.origin.x, keep - f.width), desktop.width - keep)
        f.origin.y = min(max(f.origin.y, WindowMetrics.menuBarHeight), desktop.height - WindowMetrics.titleBarHeight)
        return f
    }

    static func scaled(_ frame: CGRect, sx: CGFloat, sy: CGFloat, fitting area: CGRect, tool: ToolKind, desktop: CGSize) -> CGRect {
        var size = CGSize(width: frame.width * sx, height: frame.height * sy)
        size.width = min(max(size.width, tool.minimumSize.width), max(area.width, tool.minimumSize.width))
        size.height = min(max(size.height, tool.minimumSize.height), max(area.height, tool.minimumSize.height))
        let origin = CGPoint(x: frame.minX * sx, y: WindowMetrics.menuBarHeight + (frame.minY - WindowMetrics.menuBarHeight) * sy)
        return clamped(CGRect(origin: origin, size: size), in: desktop)
    }

    static func resized(
        _ start: CGRect,
        anchor: ResizeAnchor,
        translation t: CGSize,
        minimum: CGSize,
        bounds: CGRect
    ) -> CGRect {
        var minX = start.minX, maxX = start.maxX
        var minY = start.minY, maxY = start.maxY

        switch anchor {
        case .left, .topLeft, .bottomLeft:
            minX = min(start.minX + t.width, maxX - minimum.width)
        case .right, .topRight, .bottomRight:
            maxX = max(start.maxX + t.width, minX + minimum.width)
        default:
            break
        }
        switch anchor {
        case .top, .topLeft, .topRight:
            minY = min(start.minY + t.height, maxY - minimum.height)
        case .bottom, .bottomLeft, .bottomRight:
            maxY = max(start.maxY + t.height, minY + minimum.height)
        default:
            break
        }

        minX = max(minX, bounds.minX)
        minY = max(minY, bounds.minY)
        maxX = min(maxX, bounds.maxX)
        maxY = min(maxY, bounds.maxY)

        // Respect the minimum size even after clamping to the desktop.
        if maxX - minX < minimum.width {
            if anchor == .left || anchor == .topLeft || anchor == .bottomLeft { minX = maxX - minimum.width } else { maxX = minX + minimum.width }
        }
        if maxY - minY < minimum.height {
            if anchor == .top || anchor == .topLeft || anchor == .topRight { minY = maxY - minimum.height } else { maxY = minY + minimum.height }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
