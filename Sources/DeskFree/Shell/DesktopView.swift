import SwiftUI

/// Fixed stacking order for the shell, always above any window (window z grows with use).
enum DesktopLayer {
    static let dock: Double = 1_000_000_000
    static let menuBar: Double = 1_000_000_001
    static let menuDropdown: Double = 1_000_000_002
    static let launchpad: Double = 1_000_000_003
    static let switcher: Double = 1_000_000_004
    static let spotlight: Double = 1_000_000_005
    static let pointer: Double = 1_000_000_006
}

/// The virtual desktop at its full resolution (`WindowManager.desktopSize`).
/// Use `ScaledDesktop` to fit it into a real screen.
struct DesktopView: View {
    let session: DeskSession
    @ObservedObject var windows: WindowManager
    @ObservedObject var settings: DeskSettings
    /// `false` renders lightweight placeholders instead of the real tool contents, used
    /// by the screen that is *not* the one currently hosting the live tools.
    let live: Bool
    /// The phone's touch desktop lets the full-screen background show through instead,
    /// so there is no seam around the safe area.
    var drawsWallpaper = true

    var body: some View {
        let size = windows.desktopSize
        ZStack(alignment: .topLeading) {
            Group {
                if drawsWallpaper {
                    WallpaperView(wallpaper: settings.wallpaper, revision: settings.customWallpaperRevision)
                } else {
                    Color.clear
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if session.spotlightVisible { session.spotlightVisible = false }
            }

            DesktopIconsLayer(session: session, desktop: size)

            ForEach(windows.windows) { window in
                WindowView(
                    window: window,
                    isFront: window.id == windows.frontmostID,
                    live: live,
                    windows: windows
                )
            }

            DockView(windows: windows, settings: settings)
                .zIndex(DesktopLayer.dock)

            MenuBarView(session: session, windows: windows)
                .frame(width: size.width, height: WindowMetrics.menuBarHeight)
                .zIndex(DesktopLayer.menuBar)

            MenuDropdownLayer(session: session, desktop: size)
                .zIndex(DesktopLayer.menuDropdown)

            LaunchpadLayer(session: session, desktop: size)
                .zIndex(DesktopLayer.launchpad)

            SwitcherLayer(session: session, windows: windows)
                .zIndex(DesktopLayer.switcher)

            SpotlightLayer(session: session, desktop: size, interactive: live)
                .zIndex(DesktopLayer.spotlight)

            PointerLayer(pointer: session.pointer)
                .zIndex(DesktopLayer.pointer)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .coordinateSpace(name: "desktop")
    }
}

/// Fits the virtual desktop into the space offered by its container.
struct ScaledDesktop: View {
    let session: DeskSession
    @ObservedObject var windows: WindowManager
    let live: Bool
    var drawsWallpaper = true

    var body: some View {
        GeometryReader { geo in
            let size = windows.desktopSize
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            DesktopView(session: session, windows: windows, settings: session.settings, live: live, drawsWallpaper: drawsWallpaper)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }
}

// MARK: - Pointer

struct PointerLayer: View {
    @ObservedObject var pointer: PointerModel

    var body: some View {
        if pointer.isVisible {
            CursorShape()
                .fill(Color.white)
                .overlay(CursorShape().stroke(Color.black, lineWidth: 1.4))
                .frame(width: 13, height: 20)
                .scaleEffect(pointer.isPressed ? 0.88 : 1, anchor: .topLeading)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 2)
                .offset(x: pointer.position.x, y: pointer.position.y)
                .allowsHitTesting(false)
        }
    }
}

private struct CursorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 13
        let sy = rect.height / 20
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: pt(0, 0))
        path.addLine(to: pt(0, 17))
        path.addLine(to: pt(4.2, 13.2))
        path.addLine(to: pt(7, 19.5))
        path.addLine(to: pt(9.6, 18.4))
        path.addLine(to: pt(6.9, 12.3))
        path.addLine(to: pt(12.5, 12.3))
        path.closeSubpath()
        return path
    }
}
