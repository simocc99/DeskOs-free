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
        XCTAssertEqual(layout.entries.count, ToolKind.allCases.count)
        XCTAssertGreaterThanOrEqual(layout.background.minX, 0)
        XCTAssertLessThanOrEqual(layout.background.maxX, 390)
    }

    func testDockListsMinimisedWindowsAfterADivider() {
        let ids = [UUID(), UUID()]
        let layout = DockLayout(desktop: CGSize(width: 1280, height: 720), preferredIconSize: 52, minimized: ids)
        XCTAssertEqual(layout.entries.count, ToolKind.allCases.count + 2)
        XCTAssertNotNil(layout.dividerX)
        XCTAssertEqual(layout.entries.last?.item, .minimized(ids[1]))
    }
}
