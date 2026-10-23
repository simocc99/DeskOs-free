import XCTest
@testable import DeskFree

final class MathEvaluatorTests: XCTestCase {
    func testPrecedenceAndParentheses() {
        XCTAssertEqual(MathEvaluator.evaluate("2+3*4"), 14)
        XCTAssertEqual(MathEvaluator.evaluate("(2+3)*4"), 20)
        XCTAssertEqual(MathEvaluator.evaluate("10/4"), 2.5)
        XCTAssertEqual(MathEvaluator.evaluate("2×3÷6"), 1)
    }

    func testPowerIsRightAssociativeAndSignsBindLooser() {
        XCTAssertEqual(MathEvaluator.evaluate("2^3^2"), 512)
        XCTAssertEqual(MathEvaluator.evaluate("-2^2"), -4)
        XCTAssertEqual(MathEvaluator.evaluate("2^-1"), 0.5)
        XCTAssertEqual(MathEvaluator.evaluate("-5+2"), -3)
    }

    func testPercentAndFunctions() throws {
        XCTAssertEqual(MathEvaluator.evaluate("50%"), 0.5)
        XCTAssertEqual(MathEvaluator.evaluate("sqrt(16)"), 4)
        XCTAssertEqual(try XCTUnwrap(MathEvaluator.evaluate("pi")), Double.pi, accuracy: 1e-12)
    }

    func testInvalidInputIsRejected() {
        XCTAssertNil(MathEvaluator.evaluate("1/0"))
        XCTAssertNil(MathEvaluator.evaluate("2+"))
        XCTAssertNil(MathEvaluator.evaluate("abc"))
        XCTAssertNil(MathEvaluator.evaluate("(1+2"))
        XCTAssertNil(MathEvaluator.evaluate("1.2.3"))
        XCTAssertNil(MathEvaluator.evaluate("sqrt(-4)"))
    }

    func testFormatting() {
        XCTAssertEqual(MathEvaluator.format(14), "14")
        XCTAssertEqual(MathEvaluator.format(2.5), "2.5")
        XCTAssertEqual(MathEvaluator.format(0.1 + 0.2), "0.3")
        XCTAssertEqual(MathEvaluator.format(-3), "-3")
    }

    func testLooksLikeExpression() {
        XCTAssertTrue(MathEvaluator.looksLikeExpression("2+2"))
        XCTAssertFalse(MathEvaluator.looksLikeExpression("42"))
        XCTAssertFalse(MathEvaluator.looksLikeExpression("safari"))
    }
}

final class BrowserAddressTests: XCTestCase {
    func testDomainsBecomeHTTPSURLs() {
        XCTAssertEqual(BrowserAddress.resolve("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(BrowserAddress.resolve("https://foo.bar/x?y=1")?.absoluteString, "https://foo.bar/x?y=1")
        XCTAssertEqual(BrowserAddress.resolve("localhost:8080")?.absoluteString, "http://localhost:8080")
        XCTAssertTrue(BrowserAddress.isDirect("192.168.1.1"))
    }

    func testEverythingElseIsASearch() {
        XCTAssertEqual(
            BrowserAddress.resolve("hello world")?.absoluteString,
            "https://duckduckgo.com/?q=hello%20world"
        )
        XCTAssertFalse(BrowserAddress.isDirect("3.14"))
        XCTAssertFalse(BrowserAddress.isDirect("swift"))
        XCTAssertNil(BrowserAddress.resolve("   "))
    }
}

final class SpotlightEngineTests: XCTestCase {
    func testEmptyQueryListsEveryTool() {
        let results = SpotlightEngine.search("", windows: [], files: [])
        XCTAssertEqual(results.count, ToolKind.allCases.count)
    }

    func testToolsMatchByTitleAndKeyword() {
        XCTAssertEqual(SpotlightEngine.search("note", windows: [], files: []).first?.kind, .tool(.notes))
        XCTAssertEqual(SpotlightEngine.search("trim", windows: [], files: []).first?.kind, .tool(.video))
    }

    func testMathComesFirst() {
        let first = SpotlightEngine.search("2+2", windows: [], files: []).first
        XCTAssertEqual(first?.title, "= 4")
        XCTAssertEqual(first?.kind, .math("4"))
    }

    func testUnknownQueriesFallBackToTheWeb() {
        let results = SpotlightEngine.search("zzzz qqqq", windows: [], files: [])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.kind, .web("zzzz qqqq"))
    }

    func testFilesAndWindowsAreSearched() {
        let wm = WindowManager()
        let id = wm.open(.pdf, title: "Invoice.pdf")
        let files = [URL(fileURLWithPath: "/tmp/Holiday.mov"), URL(fileURLWithPath: "/tmp/Invoice.pdf")]
        let results = SpotlightEngine.search("invoice", windows: wm.windows, files: files)
        XCTAssertTrue(results.contains { $0.kind == .window(id) })
        XCTAssertTrue(results.contains { $0.kind == .file(URL(fileURLWithPath: "/tmp/Invoice.pdf")) })
        XCTAssertFalse(results.contains { $0.kind == .file(URL(fileURLWithPath: "/tmp/Holiday.mov")) })
    }
}

final class NotesStoreTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("notes-\(UUID().uuidString).json")
    }

    func testCreateUpdateAndPersist() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = NotesStore(fileURL: url)
        let welcomeCount = store.notes.count
        XCTAssertEqual(welcomeCount, 1)

        let id = store.create(text: "Shopping\nMilk")
        XCTAssertEqual(store.notes.first?.id, id)
        XCTAssertEqual(store.notes.first?.title, "Shopping")
        XCTAssertEqual(store.notes.first?.preview, "Milk")

        store.update(id, text: "Shopping list\nMilk\nEggs")
        let reloaded = NotesStore(fileURL: url)
        XCTAssertEqual(reloaded.notes.count, welcomeCount + 1)
        XCTAssertEqual(reloaded.note(id)?.text, "Shopping list\nMilk\nEggs")
    }

    func testDeletingTheLastNoteLeavesAnEmptyOne() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = NotesStore(fileURL: url)
        for note in store.notes { store.delete(note.id) }
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes.first?.title, "New Note")
    }
}

final class SettingsTests: XCTestCase {
    func testDefaultsAndPersistence() throws {
        let suite = "deskfree-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = DeskSettings(defaults: defaults)
        XCTAssertEqual(settings.wallpaper, .aurora)
        XCTAssertEqual(settings.dockIconSize, 52)
        XCTAssertEqual(settings.resolution, .fullHD)

        settings.wallpaper = .ocean
        settings.dockIconSize = 64
        settings.resolution = .hd720

        let again = DeskSettings(defaults: defaults)
        XCTAssertEqual(again.wallpaper, .ocean)
        XCTAssertEqual(again.dockIconSize, 64)
        XCTAssertEqual(again.resolution, .hd720)
    }
}

final class PointerTests: XCTestCase {
    func testClickingADockIconOpensTheTool() throws {
        let session = DeskSession()
        let frame = try XCTUnwrap(session.dockLayout().frame(of: .tool(.notes)))
        session.pointer.position = CGPoint(x: frame.midX, y: frame.midY)
        session.pointerClick()
        XCTAssertEqual(session.windows.windows(of: .notes).count, 1)
    }

    func testClickingTheCloseButtonClosesTheWindow() throws {
        let session = DeskSession()
        let id = session.windows.open(.notes)
        let frame = try XCTUnwrap(session.windows.window(id)?.frame)
        session.pointer.position = WindowMetrics.trafficLightCenter(index: 0, in: frame)
        session.pointerClick()
        XCTAssertNil(session.windows.window(id))
    }

    func testDraggingTheTitleBarMovesTheWindow() throws {
        let session = DeskSession()
        let id = session.windows.open(.notes)
        let start = try XCTUnwrap(session.windows.window(id)?.frame)
        session.pointer.position = CGPoint(x: start.midX, y: start.minY + 10)
        session.pointerDown()
        let speed = CGFloat(session.settings.pointerSpeed)
        session.pointerMove(by: CGPoint(x: 50 / speed, y: 0))
        session.pointerUp()
        let moved = try XCTUnwrap(session.windows.window(id)?.frame)
        XCTAssertEqual(moved.minX, start.minX + 50, accuracy: 0.5)
        XCTAssertEqual(moved.minY, start.minY, accuracy: 0.5)
    }

    func testSpotlightLaunchesTheBestMatch() {
        let session = DeskSession()
        session.toggleSpotlight()
        session.spotlightQuery = "calc"
        session.launchSelectedSpotlightResult()
        XCTAssertFalse(session.spotlightVisible)
        XCTAssertEqual(session.windows.windows(of: .calculator).count, 1)
    }

    func testPointerStaysOnTheDesktop() {
        let session = DeskSession()
        session.pointerMove(by: CGPoint(x: 100_000, y: 100_000))
        XCTAssertEqual(session.pointer.position.x, session.windows.desktopSize.width, accuracy: 0.01)
        XCTAssertEqual(session.pointer.position.y, session.windows.desktopSize.height, accuracy: 0.01)
        session.pointerMove(by: CGPoint(x: -100_000, y: -100_000))
        XCTAssertEqual(session.pointer.position, .zero)
    }
}
