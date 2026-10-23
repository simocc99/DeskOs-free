import UIKit

/// Launch arguments used by CI to take screenshots of the app in the simulator:
///   -deskfree-demo       open a few windows once the UI is up
///   -deskfree-landscape  ask the scene to rotate to landscape first
enum DemoMode {
    private static var didRun = false

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-deskfree-demo")
    }

    static func runIfRequested(session: DeskSession) {
        guard isEnabled, !didRun else { return }
        didRun = true
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-deskfree-landscape") {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let windows = session.windows
            windows.open(.files)
            windows.open(.notes)
            windows.open(.calculator)
            windows.open(.browser)
        }
    }
}
