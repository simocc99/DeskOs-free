import UIKit

/// Launch arguments used by CI to take screenshots of the app in the simulator:
///   -deskfree-demo             enable demo mode
///   -deskfree-landscape        ask the scene to rotate to landscape first
///   -deskfree-scene <name>     windows (default), browser, files, pdf, notes,
///                              calculator, settings, video, spotlight
enum DemoMode {
    private static var didRun = false

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-deskfree-demo")
    }

    private static var scene: String {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-deskfree-scene"), index + 1 < arguments.count else {
            return "windows"
        }
        return arguments[index + 1]
    }

    static func runIfRequested(session: DeskSession) {
        guard isEnabled, !didRun else { return }
        didRun = true

        if ProcessInfo.processInfo.arguments.contains("-deskfree-landscape") {
            let windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
        }

        let pdfURL = seedSampleFiles()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let windows = session.windows
            switch scene {
            case "browser":
                windows.toggleMaximize(windows.open(.browser))
            case "files":
                windows.toggleMaximize(windows.open(.files))
            case "pdf":
                windows.toggleMaximize(windows.open(.preview, payload: pdfURL, title: "Welcome.pdf"))
            case "notes":
                windows.toggleMaximize(windows.open(.notes))
            case "calculator":
                windows.toggleMaximize(windows.open(.calculator))
            case "settings":
                windows.toggleMaximize(windows.open(.settings))
            case "video":
                windows.toggleMaximize(windows.open(.video))
            case "spotlight":
                windows.open(.files)
                session.toggleSpotlight()
                session.spotlightQuery = "no"
            default:
                windows.open(.files)
                windows.open(.notes)
                windows.open(.calculator)
                windows.open(.browser)
            }
        }
    }

    /// Creates a few files so that the Files app and PDF Studio have something to show.
    private static func seedSampleFiles() -> URL {
        let fm = FileManager.default
        let root = DocumentsStore.root
        try? fm.createDirectory(at: root.appendingPathComponent("Projects"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: root.appendingPathComponent("Pictures"), withIntermediateDirectories: true)
        try? "Buy milk\nCall Anna\nSketch the new desk layout".write(
            to: root.appendingPathComponent("Todo.txt"), atomically: true, encoding: .utf8
        )

        let pdfURL = root.appendingPathComponent("Welcome.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try? renderer.writePDF(to: pdfURL) { context in
            for page in 1...3 {
                context.beginPage()
                let title = "DeskFree sample document — page \(page)"
                title.draw(at: CGPoint(x: 72, y: 72), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 26)])
                let body = """
                Annotate this PDF with the highlighter, underline, pen and text tools.
                Select some text, choose a marker and press Apply.

                The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.
                """
                body.draw(
                    in: CGRect(x: 72, y: 130, width: 468, height: 400),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 16)]
                )
            }
        }
        return pdfURL
    }
}
