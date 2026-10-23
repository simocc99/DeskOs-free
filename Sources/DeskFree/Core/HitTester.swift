import SwiftUI

enum MenuBarMetrics {
    static let logoWidth: CGFloat = 46
    static let clockWidth: CGFloat = 150
    static let searchWidth: CGFloat = 36

    static func logoRect() -> CGRect {
        CGRect(x: 0, y: 0, width: logoWidth, height: WindowMetrics.menuBarHeight)
    }

    static func searchRect(desktop: CGSize) -> CGRect {
        CGRect(
            x: desktop.width - clockWidth - searchWidth,
            y: 0,
            width: searchWidth,
            height: WindowMetrics.menuBarHeight
        )
    }
}

enum HitTarget: Equatable {
    case desktop
    case menuLogo
    case menuSearch
    case menuBar
    case dock(DockItem)
    case dockBackground
    case windowClose(UUID)
    case windowMinimize(UUID)
    case windowMaximize(UUID)
    case windowTitle(UUID)
    case windowResize(UUID, ResizeAnchor)
    /// `point` is relative to the top-left corner of the window content area.
    case windowContent(UUID, CGPoint)
}

/// Resolves what is under a point of the virtual desktop. Drives the software pointer
/// of the trackpad, so every clickable thing on the desktop is described analytically.
struct HitTester {
    var desktop: CGSize
    var windows: [DeskWindow]
    var dock: DockLayout

    func hit(_ p: CGPoint) -> HitTarget {
        if p.y <= WindowMetrics.menuBarHeight {
            if MenuBarMetrics.logoRect().contains(p) { return .menuLogo }
            if MenuBarMetrics.searchRect(desktop: desktop).contains(p) { return .menuSearch }
            return .menuBar
        }

        if dock.background.insetBy(dx: -4, dy: -4).contains(p) {
            for entry in dock.entries {
                let area = entry.frame.insetBy(dx: -DockLayout.spacing / 2, dy: -DockLayout.verticalPadding)
                if area.contains(p) { return .dock(entry.item) }
            }
            return .dockBackground
        }

        let ordered = windows.filter { !$0.isMinimized }.sorted { $0.z > $1.z }
        for window in ordered {
            if let target = hit(window, at: p) { return target }
        }
        return .desktop
    }

    private func hit(_ w: DeskWindow, at p: CGPoint) -> HitTarget? {
        let f = w.frame
        let m = WindowMetrics.resizeMargin
        let reach = w.isMaximized ? f : f.insetBy(dx: -m, dy: -m)
        guard reach.contains(p) else { return nil }

        if f.contains(p) {
            let lights: [HitTarget] = [.windowClose(w.id), .windowMinimize(w.id), .windowMaximize(w.id)]
            for (index, target) in lights.enumerated() {
                let c = WindowMetrics.trafficLightCenter(index: index, in: f)
                if hypot(p.x - c.x, p.y - c.y) <= WindowMetrics.trafficLightHitRadius { return target }
            }
        }

        if !w.isMaximized {
            let l = p.x < f.minX + m, r = p.x > f.maxX - m
            let t = p.y < f.minY + m, b = p.y > f.maxY - m
            var anchor: ResizeAnchor?
            if t && l { anchor = .topLeft }
            else if t && r { anchor = .topRight }
            else if b && l { anchor = .bottomLeft }
            else if b && r { anchor = .bottomRight }
            else if l { anchor = .left }
            else if r { anchor = .right }
            else if t { anchor = .top }
            else if b { anchor = .bottom }
            if let anchor { return .windowResize(w.id, anchor) }
        }

        guard f.contains(p) else { return nil }
        if p.y < f.minY + WindowMetrics.titleBarHeight { return .windowTitle(w.id) }
        return .windowContent(w.id, CGPoint(x: p.x - f.minX, y: p.y - f.minY - WindowMetrics.titleBarHeight))
    }
}
