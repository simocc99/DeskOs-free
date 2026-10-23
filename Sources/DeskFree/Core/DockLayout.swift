import SwiftUI

enum DockItem: Hashable {
    case tool(ToolKind)
    case launchpad
    case minimized(UUID)
}

struct DockEntry: Identifiable {
    let item: DockItem
    let frame: CGRect
    var id: DockItem { item }
}

/// Pure geometry of the Dock. Used by the Dock view *and* by the pointer hit-tester,
/// so both always agree on where each icon is.
struct DockLayout {
    static let padding: CGFloat = 10
    static let spacing: CGFloat = 8
    static let dividerWidth: CGFloat = 12
    static let bottomMargin: CGFloat = 8
    static let verticalPadding: CGFloat = 8

    let iconSize: CGFloat
    let entries: [DockEntry]
    let background: CGRect
    /// X position of the divider between pinned items and minimised windows.
    let dividerX: CGFloat?

    init(desktop: CGSize, preferredIconSize: CGFloat, minimized: [UUID]) {
        let pinned: [DockItem] = ToolKind.allCases.map { DockItem.tool($0) } + [DockItem.launchpad]
        let minis = minimized.map { DockItem.minimized($0) }
        let items = pinned + minis
        let count = CGFloat(items.count)
        let divider: CGFloat = minis.isEmpty ? 0 : Self.dividerWidth
        let gaps = Self.spacing * (count - 1)
        let available = max(120, desktop.width - 2 * Self.padding - 24)

        var icon = Self.effectiveIconSize(preferred: preferredIconSize, desktop: desktop)
        if count * icon + gaps + divider > available {
            icon = max(22, (available - gaps - divider) / count)
        }

        let total = 2 * Self.padding + count * icon + gaps + divider
        let startX = (desktop.width - total) / 2
        let iconY = desktop.height - Self.bottomMargin - Self.verticalPadding - icon

        var x = startX + Self.padding
        var result: [DockEntry] = []
        var dividerPosition: CGFloat?
        for (index, item) in items.enumerated() {
            if index == pinned.count, !minis.isEmpty {
                dividerPosition = x + divider / 2 - 2
                x += divider
            }
            result.append(DockEntry(item: item, frame: CGRect(x: x, y: iconY, width: icon, height: icon)))
            x += icon + Self.spacing
        }

        self.iconSize = icon
        self.entries = result
        self.dividerX = dividerPosition
        self.background = CGRect(
            x: startX,
            y: iconY - Self.verticalPadding,
            width: total,
            height: icon + 2 * Self.verticalPadding
        )
    }

    /// Short desktops (a phone in landscape) get a smaller Dock so windows keep their room.
    static func effectiveIconSize(preferred: CGFloat, desktop: CGSize) -> CGFloat {
        min(preferred, max(32, desktop.height * 0.115))
    }

    /// Space the Dock occupies at the bottom of the desktop.
    static func reservedHeight(forIcon size: CGFloat) -> CGFloat {
        bottomMargin + 2 * verticalPadding + size + 6
    }

    func frame(of item: DockItem) -> CGRect? {
        entries.first { $0.item == item }?.frame
    }
}
