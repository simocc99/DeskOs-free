import SwiftUI

enum MenuBarMetrics {
    static let logoWidth: CGFloat = 46
    static let clockWidth: CGFloat = 100
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
    case desktopIcon(DesktopIcon)
    case menuLogo
    case menuSearch
    case menuBar
    case menuTitle(Int)
    case menuRow(menu: Int, row: Int)
    /// Click outside an open menu: closes it.
    case menuDismiss
    case launchpadApp(ToolKind)
    case launchpadBackground
    case switcherCard(UUID)
    case switcherBackground
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
    var overlay: DesktopOverlay = .none
    var menu: MenuLayout?

    func hit(_ p: CGPoint) -> HitTarget {
        switch overlay {
        case .launchpad:
            for cell in LaunchpadLayout.frames(desktop: desktop) where cell.frame.contains(p) {
                return .launchpadApp(cell.tool)
            }
            return .launchpadBackground
        case .switcher(let ids):
            let cards = SwitcherLayout.cards(desktop: desktop, count: ids.count)
            for (index, card) in cards.enumerated() {
                let full = card.insetBy(dx: -6, dy: -6).union(CGRect(x: card.minX, y: card.maxY, width: card.width, height: SwitcherLayout.labelHeight))
                if full.contains(p) { return .switcherCard(ids[index]) }
            }
            return .switcherBackground
        case .none:
            break
        }

        if let menu, menu.openIndex != nil {
            for (index, row) in menu.rowFrames.enumerated() where row.contains(p) {
                return .menuRow(menu: menu.openIndex ?? 0, row: index)
            }
            if let dropdown = menu.dropdown, dropdown.contains(p) { return .menuBar }
            if p.y > WindowMetrics.menuBarHeight { return .menuDismiss }
        }

        if p.y <= WindowMetrics.menuBarHeight {
            if MenuBarMetrics.logoRect().contains(p) { return .menuLogo }
            if let menu {
                for (index, frame) in menu.titleFrames.enumerated() where frame.contains(p) {
                    return .menuTitle(index)
                }
            }
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

        for item in DesktopIconLayout.frames(desktop: desktop) where item.frame.contains(p) {
            return .desktopIcon(item.icon)
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
