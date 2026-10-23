import SwiftUI

@main
struct DeskFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden(true)
        }
    }
}
