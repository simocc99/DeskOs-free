import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalSceneDelegate.self
        }
        return configuration
    }
}

/// Hosts the desktop on a connected HDMI / USB-C / AirPlay display as its own screen
/// instead of mirroring the phone.
final class ExternalSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: ExternalDesktopRoot())
        host.view.backgroundColor = .black
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        DeskSession.shared.externalDisplayChanged(connected: true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        DeskSession.shared.externalDisplayChanged(connected: false)
    }
}

struct ExternalDesktopRoot: View {
    @ObservedObject private var session = DeskSession.shared
    @ObservedObject private var windows = DeskSession.shared.windows

    var body: some View {
        ZStack {
            Color.black
            ScaledDesktop(session: session, windows: windows, live: session.liveHost == .external)
        }
        .ignoresSafeArea()
    }
}
