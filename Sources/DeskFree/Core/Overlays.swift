import SwiftUI

// MARK: - Desktop icons

enum DesktopIcon: CaseIterable, Hashable {
    case documents, applications

    var title: String {
        switch self {
        case .documents: return "Documents"
        case .applications: return "Applications"
        }
    }
}

enum DesktopIconLayout {
    static let size = CGSize(width: 88, height: 94)

    /// Shortcut icons stacked in the top-right corner of the desktop.
    static func frames(desktop: CGSize) -> [(icon: DesktopIcon, frame: CGRect)] {
        DesktopIcon.allCases.enumerated().map { index, icon in
            let frame = CGRect(
                x: desktop.width - size.width - 12,
                y: WindowMetrics.menuBarHeight + 12 + CGFloat(index) * (size.height + 6),
                width: size.width,
                height: size.height
            )
            return (icon, frame)
        }
    }
}

// MARK: - Launchpad (grid of every app)

enum LaunchpadLayout {
    static func iconSize(desktop: CGSize) -> CGFloat {
        min(88, max(40, desktop.height * 0.13))
    }

    /// Frame of each app cell (icon + label) in a centred grid.
    static func frames(desktop: CGSize) -> [(tool: ToolKind, frame: CGRect)] {
        let tools = ToolKind.allCases
        let icon = iconSize(desktop: desktop)
        let cellWidth = icon * 1.9
        let cellHeight = icon + 34
        let columns = min(4, max(2, Int(desktop.width * 0.7 / cellWidth)))
        let rows = (tools.count + columns - 1) / columns
        let gridWidth = CGFloat(columns) * cellWidth
        let gridHeight = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * 14
        let originX = (desktop.width - gridWidth) / 2
        let originY = max(WindowMetrics.menuBarHeight + 8, (desktop.height - gridHeight) / 2 - 10)

        return tools.enumerated().map { index, tool in
            let row = index / columns
            let column = index % columns
            let frame = CGRect(
                x: originX + CGFloat(column) * cellWidth,
                y: originY + CGFloat(row) * (cellHeight + 14),
                width: cellWidth,
                height: cellHeight
            )
            return (tool, frame)
        }
    }
}

// MARK: - Window switcher (all windows as cards)

enum SwitcherLayout {
    static let labelHeight: CGFloat = 26

    /// Card rectangles (without the label) for `count` windows.
    static func cards(desktop: CGSize, count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        let columns = count <= 1 ? 1 : (count <= 4 ? 2 : 3)
        let rows = (count + columns - 1) / columns
        let top = WindowMetrics.menuBarHeight + 20
        let bottom: CGFloat = 24
        let gap: CGFloat = 18
        let availableWidth = desktop.width * 0.9
        let availableHeight = desktop.height - top - bottom
        let aspect = desktop.width / desktop.height

        var width = (availableWidth - CGFloat(columns - 1) * gap) / CGFloat(columns)
        var height = width / aspect
        let neededHeight = CGFloat(rows) * (height + labelHeight) + CGFloat(rows - 1) * gap
        if neededHeight > availableHeight {
            let scale = availableHeight / neededHeight
            width *= scale
            height *= scale
        }
        let gridWidth = CGFloat(columns) * width + CGFloat(columns - 1) * gap
        let gridHeight = CGFloat(rows) * (height + labelHeight) + CGFloat(rows - 1) * gap
        let originX = (desktop.width - gridWidth) / 2
        let originY = top + max(0, (availableHeight - gridHeight) / 2)

        return (0..<count).map { index in
            let row = index / columns
            let column = index % columns
            return CGRect(
                x: originX + CGFloat(column) * (width + gap),
                y: originY + CGFloat(row) * (height + labelHeight + gap),
                width: width,
                height: height
            )
        }
    }
}

enum DesktopOverlay: Equatable {
    case none
    case launchpad
    case switcher([UUID])
}

// MARK: - Menu bar menus

struct MenuEntry {
    var title: String
    var shortcut = ""
    var enabled = true
    var isSeparator = false
    var action: () -> Void = {}

    static var separator: MenuEntry {
        MenuEntry(title: "", isSeparator: true)
    }
}

struct DesktopMenu {
    var title: String
    var entries: [MenuEntry]
}

/// Geometry of the menu bar titles and of the open drop-down. Shared by the views and
/// the pointer hit-tester.
struct MenuLayout {
    static let rowHeight: CGFloat = 28
    static let separatorHeight: CGFloat = 11
    static let dropdownWidth: CGFloat = 236
    static let dropdownPadding: CGFloat = 6

    var appNameWidth: CGFloat
    var titleFrames: [CGRect]
    var openIndex: Int?
    var dropdown: CGRect?
    /// Row rectangles of the open menu, aligned with its entries (separators included).
    var rowFrames: [CGRect]

    static func textWidth(_ text: String, bold: Bool) -> CGFloat {
        CGFloat(text.count) * (bold ? 8.0 : 7.3)
    }

    init(appName: String, menus: [DesktopMenu], openIndex: Int?, desktop: CGSize) {
        let appWidth = Self.textWidth(appName, bold: true) + 26
        var x = MenuBarMetrics.logoWidth + appWidth
        var frames: [CGRect] = []
        for menu in menus {
            let width = Self.textWidth(menu.title, bold: false) + 26
            frames.append(CGRect(x: x, y: 0, width: width, height: WindowMetrics.menuBarHeight))
            x += width
        }
        self.appNameWidth = appWidth
        self.titleFrames = frames

        if let open = openIndex, menus.indices.contains(open) {
            let entries = menus[open].entries
            let height = entries.reduce(CGFloat(0)) { $0 + ($1.isSeparator ? Self.separatorHeight : Self.rowHeight) }
                + 2 * Self.dropdownPadding
            let dropX = min(frames[open].minX, max(0, desktop.width - Self.dropdownWidth - 6))
            let box = CGRect(x: dropX, y: WindowMetrics.menuBarHeight, width: Self.dropdownWidth, height: height)
            var rows: [CGRect] = []
            var y = box.minY + Self.dropdownPadding
            for entry in entries {
                let rowHeight = entry.isSeparator ? Self.separatorHeight : Self.rowHeight
                rows.append(CGRect(x: box.minX + Self.dropdownPadding, y: y, width: box.width - 2 * Self.dropdownPadding, height: rowHeight))
                y += rowHeight
            }
            self.openIndex = open
            self.dropdown = box
            self.rowFrames = rows
        } else {
            self.openIndex = nil
            self.dropdown = nil
            self.rowFrames = []
        }
    }
}
