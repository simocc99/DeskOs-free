import XCTest
@testable import DeskFree

final class HitTesterTests: XCTestCase {
    private func makeTester(_ wm: WindowManager, minimized: [UUID] = []) -> (HitTester, DockLayout) {
        let dock = DockLayout(desktop: wm.desktopSize, preferredIconSize: 52, minimized: minimized)
        return (HitTester(desktop: wm.desktopSize, windows: wm.windows, dock: dock), dock)
    }

    func testWindowChromeTargets() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let id = wm.open(.notes)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        let (tester, _) = makeTester(wm)

        XCTAssertEqual(tester.hit(WindowMetrics.trafficLightCenter(index: 0, in: frame)), .windowClose(id))
        XCTAssertEqual(tester.hit(WindowMetrics.trafficLightCenter(index: 1, in: frame)), .windowMinimize(id))
        XCTAssertEqual(tester.hit(WindowMetrics.trafficLightCenter(index: 2, in: frame)), .windowMaximize(id))
        XCTAssertEqual(tester.hit(CGPoint(x: frame.midX, y: frame.minY + 10)), .windowTitle(id))
    }

    func testContentPointIsRelativeToTheContentArea() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let id = wm.open(.notes)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        let (tester, _) = makeTester(wm)
        let point = CGPoint(x: frame.minX + 100, y: frame.minY + WindowMetrics.titleBarHeight + 50)
        XCTAssertEqual(tester.hit(point), .windowContent(id, CGPoint(x: 100, y: 50)))
    }

    func testResizeEdgesAndCorners() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let id = wm.open(.notes)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        let (tester, _) = makeTester(wm)
        XCTAssertEqual(tester.hit(CGPoint(x: frame.maxX + 2, y: frame.midY)), .windowResize(id, .right))
        XCTAssertEqual(tester.hit(CGPoint(x: frame.maxX - 2, y: frame.maxY - 2)), .windowResize(id, .bottomRight))
        XCTAssertEqual(tester.hit(CGPoint(x: frame.midX, y: frame.maxY + 2)), .windowResize(id, .bottom))
    }

    func testMaximisedWindowsHaveNoResizeHandles() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let id = wm.open(.notes)
        wm.toggleMaximize(id)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        let (tester, _) = makeTester(wm)
        let target = tester.hit(CGPoint(x: frame.maxX - 2, y: frame.midY))
        XCTAssertEqual(target, .windowContent(id, CGPoint(x: frame.width - 2, y: frame.midY - frame.minY - WindowMetrics.titleBarHeight)))
    }

    func testTheFrontWindowWinsOverlaps() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let back = wm.open(.notes)
        let front = wm.open(.files)
        let overlap = try XCTUnwrap(wm.window(front)?.frame).insetBy(dx: 40, dy: 60).origin
        guard case .windowContent(let hitID, _) = makeTester(wm).0.hit(CGPoint(x: overlap.x + 20, y: overlap.y + 20)) else {
            return XCTFail("expected window content")
        }
        XCTAssertEqual(hitID, front)
        wm.focus(back)
        guard case .windowContent(let newID, _) = makeTester(wm).0.hit(CGPoint(x: overlap.x + 20, y: overlap.y + 20)) else {
            return XCTFail("expected window content")
        }
        XCTAssertEqual(newID, back)
    }

    func testMenuBarAndDockTargets() throws {
        let wm = WindowManager(desktopSize: CGSize(width: 1280, height: 720))
        let (tester, dock) = makeTester(wm)
        XCTAssertEqual(tester.hit(CGPoint(x: 10, y: 10)), .menuLogo)
        let search = MenuBarMetrics.searchRect(desktop: wm.desktopSize)
        XCTAssertEqual(tester.hit(CGPoint(x: search.midX, y: search.midY)), .menuSearch)

        let entry = try XCTUnwrap(dock.entries.first)
        XCTAssertEqual(tester.hit(CGPoint(x: entry.frame.midX, y: entry.frame.midY)), .dock(entry.item))
        XCTAssertEqual(tester.hit(CGPoint(x: 640, y: 300)), .desktop)
    }

    func testDockShrinksIconsOnNarrowDesktops() {
        let layout = DockLayout(desktop: CGSize(width: 390, height: 700), preferredIconSize: 52, minimized: [])
        XCTAssertLessThan(layout.iconSize, 52)
        XCTAssertEqual(layout.entries.count, ToolKind.allCases.count + 1) // + Launchpad
        XCTAssertGreaterThanOrEqual(layout.background.minX, 0)
        XCTAssertLessThanOrEqual(layout.background.maxX, 390)
    }

    func testDockListsMinimisedWindowsAfterADivider() {
        let ids = [UUID(), UUID()]
        let layout = DockLayout(desktop: CGSize(width: 1280, height: 720), preferredIconSize: 52, minimized: ids)
        XCTAssertEqual(layout.entries.count, ToolKind.allCases.count + 3) // + Launchpad + 2 minimised
        XCTAssertNotNil(layout.dividerX)
        XCTAssertEqual(layout.entries.last?.item, .minimized(ids[1]))
    }

    func testLaunchpadAndSwitcherCaptureClicks() throws {
        let desktop = CGSize(width: 1280, height: 720)
        let wm = WindowManager(desktopSize: desktop)
        let id = wm.open(.notes)
        let dock = DockLayout(desktop: desktop, preferredIconSize: 52, minimized: [])

        let cell = try XCTUnwrap(LaunchpadLayout.frames(desktop: desktop).first)
        var tester = HitTester(desktop: desktop, windows: wm.windows, dock: dock, overlay: .launchpad)
        XCTAssertEqual(tester.hit(CGPoint(x: cell.frame.midX, y: cell.frame.midY)), .launchpadApp(cell.tool))
        XCTAssertEqual(tester.hit(CGPoint(x: 2, y: 2)), .launchpadBackground)

        tester.overlay = .switcher([id])
        let card = try XCTUnwrap(SwitcherLayout.cards(desktop: desktop, count: 1).first)
        XCTAssertEqual(tester.hit(CGPoint(x: card.midX, y: card.midY)), .switcherCard(id))
        XCTAssertEqual(tester.hit(CGPoint(x: 2, y: 700)), .switcherBackground)
    }

    func testMenuTitlesRowsAndDismiss() throws {
        let desktop = CGSize(width: 1280, height: 720)
        let wm = WindowManager(desktopSize: desktop)
        let dock = DockLayout(desktop: desktop, preferredIconSize: 52, minimized: [])
        let menus = [
            DesktopMenu(title: "File", entries: [MenuEntry(title: "New"), .separator, MenuEntry(title: "Close")]),
            DesktopMenu(title: "Edit", entries: [MenuEntry(title: "Undo")])
        ]
        let closed = MenuLayout(appName: "Files", menus: menus, openIndex: nil, desktop: desktop)
        var tester = HitTester(desktop: desktop, windows: [], dock: dock, menu: closed)
        let edit = closed.titleFrames[1]
        XCTAssertEqual(tester.hit(CGPoint(x: edit.midX, y: edit.midY)), .menuTitle(1))

        let open = MenuLayout(appName: "Files", menus: menus, openIndex: 0, desktop: desktop)
        tester.menu = open
        let row = open.rowFrames[2]
        XCTAssertEqual(tester.hit(CGPoint(x: row.midX, y: row.midY)), .menuRow(menu: 0, row: 2))
        XCTAssertEqual(tester.hit(CGPoint(x: 900, y: 400)), .menuDismiss)
        _ = wm
    }

    func testDesktopIconsAreClickable() throws {
        let desktop = CGSize(width: 1280, height: 720)
        let dock = DockLayout(desktop: desktop, preferredIconSize: 52, minimized: [])
        let tester = HitTester(desktop: desktop, windows: [], dock: dock)
        let item = try XCTUnwrap(DesktopIconLayout.frames(desktop: desktop).first)
        XCTAssertEqual(tester.hit(CGPoint(x: item.frame.midX, y: item.frame.midY)), .desktopIcon(item.icon))
    }
}
