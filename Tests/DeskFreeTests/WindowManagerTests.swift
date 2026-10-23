import XCTest
@testable import DeskFree

final class WindowManagerTests: XCTestCase {
    private func makeManager() -> WindowManager {
        WindowManager(desktopSize: CGSize(width: 1280, height: 720))
    }

    func testOpenCascadesAndFocusesTheNewestWindow() {
        let wm = makeManager()
        let a = wm.open(.notes)
        let b = wm.open(.notes)
        XCTAssertNotEqual(wm.window(a)?.frame.origin, wm.window(b)?.frame.origin)
        XCTAssertEqual(wm.frontmostID, b)
    }

    func testOpenKeepsTheWindowInsideTheUsableArea() {
        let wm = makeManager()
        let id = wm.open(.browser)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        XCTAssertTrue(wm.usableArea.contains(frame))
    }

    func testFocusBringsAWindowToTheFront() {
        let wm = makeManager()
        let a = wm.open(.notes)
        _ = wm.open(.files)
        wm.focus(a)
        XCTAssertEqual(wm.frontmostID, a)
    }

    func testActivateOpensWhenNotRunning() {
        let wm = makeManager()
        wm.activate(.calculator)
        XCTAssertEqual(wm.windows(of: .calculator).count, 1)
    }

    func testActivateMinimisesTheFrontmostWindowAndRestoresItNextTime() {
        let wm = makeManager()
        let id = wm.open(.notes)
        wm.activate(.notes)
        XCTAssertEqual(wm.window(id)?.isMinimized, true)
        XCTAssertNil(wm.frontmostID)
        wm.activate(.notes)
        XCTAssertEqual(wm.window(id)?.isMinimized, false)
        XCTAssertEqual(wm.frontmostID, id)
    }

    func testMaximiseAndRestore() throws {
        let wm = makeManager()
        let id = wm.open(.notes)
        let original = try XCTUnwrap(wm.window(id)?.frame)
        wm.toggleMaximize(id)
        XCTAssertEqual(wm.window(id)?.frame, wm.usableArea)
        XCTAssertEqual(wm.window(id)?.isMaximized, true)
        wm.toggleMaximize(id)
        XCTAssertEqual(wm.window(id)?.frame, original)
        XCTAssertEqual(wm.window(id)?.isMaximized, false)
    }

    func testMoveNeverLosesTheTitleBar() throws {
        let wm = makeManager()
        let id = wm.open(.notes)
        let start = try XCTUnwrap(wm.window(id)?.frame)

        wm.move(id, from: start, by: CGSize(width: 5000, height: 5000))
        var frame = try XCTUnwrap(wm.window(id)?.frame)
        XCTAssertEqual(frame.minX, 1280 - 80, accuracy: 0.01)
        XCTAssertEqual(frame.minY, 720 - WindowMetrics.titleBarHeight, accuracy: 0.01)

        wm.move(id, from: start, by: CGSize(width: -5000, height: -5000))
        frame = try XCTUnwrap(wm.window(id)?.frame)
        XCTAssertEqual(frame.maxX, 80, accuracy: 0.01)
        XCTAssertEqual(frame.minY, WindowMetrics.menuBarHeight, accuracy: 0.01)
    }

    func testBeginMoveRestoresAMaximisedWindowUnderTheFinger() throws {
        let wm = makeManager()
        let id = wm.open(.notes)
        let original = try XCTUnwrap(wm.window(id)?.frame)
        wm.toggleMaximize(id)
        let start = wm.beginMove(id, grab: CGPoint(x: 640, y: 40))
        XCTAssertEqual(start.size, original.size)
        XCTAssertEqual(start.minX, 640 - original.width / 2, accuracy: 0.01)
        XCTAssertEqual(wm.window(id)?.isMaximized, false)
    }

    func testResizeHonoursTheMinimumSize() {
        let start = CGRect(x: 100, y: 100, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 30, width: 1280, height: 690)
        let result = WindowManager.resized(
            start,
            anchor: .bottomRight,
            translation: CGSize(width: -1000, height: -1000),
            minimum: CGSize(width: 340, height: 240),
            bounds: bounds
        )
        XCTAssertEqual(result.origin, start.origin)
        XCTAssertEqual(result.size, CGSize(width: 340, height: 240))
    }

    func testResizeFromTheTopLeftMovesTheOrigin() {
        let start = CGRect(x: 100, y: 100, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 30, width: 1280, height: 690)
        let result = WindowManager.resized(
            start,
            anchor: .topLeft,
            translation: CGSize(width: -50, height: -20),
            minimum: CGSize(width: 340, height: 240),
            bounds: bounds
        )
        XCTAssertEqual(result, CGRect(x: 50, y: 80, width: 450, height: 320))
    }

    func testResizeStaysInsideTheDesktop() {
        let start = CGRect(x: 100, y: 100, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 30, width: 1280, height: 690)
        let result = WindowManager.resized(
            start,
            anchor: .right,
            translation: CGSize(width: 5000, height: 0),
            minimum: CGSize(width: 340, height: 240),
            bounds: bounds
        )
        XCTAssertEqual(result.maxX, 1280, accuracy: 0.01)
    }

    func testSnapLeftTakesHalfOfTheUsableArea() throws {
        let wm = makeManager()
        let id = wm.open(.files)
        wm.snap(id, to: .left)
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        XCTAssertEqual(frame.width, wm.usableArea.width / 2, accuracy: 0.01)
        XCTAssertEqual(frame.minX, 0, accuracy: 0.01)
    }

    func testChangingTheDesktopSizeKeepsMaximisedWindowsMaximised() {
        let wm = makeManager()
        let id = wm.open(.notes)
        wm.toggleMaximize(id)
        wm.setDesktopSize(CGSize(width: 852, height: 390))
        XCTAssertEqual(wm.desktopSize, CGSize(width: 852, height: 390))
        XCTAssertEqual(wm.window(id)?.frame, wm.usableArea)
    }

    func testChangingTheDesktopSizeKeepsWindowsReachable() throws {
        let wm = makeManager()
        let id = wm.open(.browser)
        wm.setDesktopSize(CGSize(width: 852, height: 390))
        let frame = try XCTUnwrap(wm.window(id)?.frame)
        XCTAssertLessThanOrEqual(frame.minX, 852 - 80)
        XCTAssertLessThanOrEqual(frame.minY, 390 - WindowMetrics.titleBarHeight)
        XCTAssertGreaterThanOrEqual(frame.minY, WindowMetrics.menuBarHeight)
    }

    func testShowDesktopMinimisesEverythingThenRestoresIt() {
        let wm = makeManager()
        wm.open(.notes)
        wm.open(.files)
        wm.toggleShowDesktop()
        XCTAssertTrue(wm.visibleWindows.isEmpty)
        wm.toggleShowDesktop()
        XCTAssertEqual(wm.visibleWindows.count, 2)
    }

    func testCloseRemovesTheWindow() {
        let wm = makeManager()
        let id = wm.open(.notes)
        wm.close(id)
        XCTAssertNil(wm.window(id))
    }
}
