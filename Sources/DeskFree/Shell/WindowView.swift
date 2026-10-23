import SwiftUI

struct WindowView: View {
    let window: DeskWindow
    let isFront: Bool
    let live: Bool
    @ObservedObject var windows: WindowManager

    @State private var moveStart: CGRect?

    var body: some View {
        let f = window.frame
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                titleBar
                ZStack {
                    content
                    if !isFront {
                        // First click only brings the window to the front, like on a desktop.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { windows.focus(window.id) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .frame(width: f.width, height: f.height)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: WindowMetrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WindowMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isFront ? 0.3 : 0.14), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(isFront ? 0.5 : 0.25), radius: isFront ? 30 : 14, y: isFront ? 14 : 6)

            if !window.isMaximized {
                ForEach(ResizeAnchor.allCases, id: \.self) { anchor in
                    ResizeHandle(window: window, anchor: anchor, windows: windows)
                }
            }
        }
        .frame(width: f.width, height: f.height, alignment: .topLeading)
        .scaleEffect(window.isMinimized ? 0.2 : 1, anchor: .bottom)
        .opacity(window.isMinimized ? 0 : 1)
        .allowsHitTesting(!window.isMinimized)
        .offset(x: f.minX, y: f.minY)
        .zIndex(Double(window.z))
        .animation(.snappy(duration: 0.28), value: window.isMinimized)
        .animation(.snappy(duration: 0.28), value: window.isMaximized)
    }

    // MARK: Title bar

    private var titleBar: some View {
        ZStack {
            Text(window.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFront ? Color.primary : Color.secondary)
                .lineLimit(1)
                .padding(.horizontal, 90)

            HStack(spacing: 0) {
                trafficLight(color: Color(red: 1.0, green: 0.37, blue: 0.34), glyph: "xmark") {
                    windows.close(window.id)
                }
                trafficLight(color: Color(red: 1.0, green: 0.75, blue: 0.18), glyph: "minus") {
                    windows.minimize(window.id)
                }
                trafficLight(color: Color(red: 0.16, green: 0.79, blue: 0.25), glyph: "plus") {
                    windows.toggleMaximize(window.id)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 7)
        }
        .frame(height: WindowMetrics.titleBarHeight)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            windows.toggleMaximize(window.id)
        }
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named("desktop"))
                .onChanged { value in
                    if moveStart == nil {
                        moveStart = windows.beginMove(window.id, grab: value.startLocation)
                    }
                    if let start = moveStart {
                        windows.move(window.id, from: start, by: value.translation)
                    }
                }
                .onEnded { _ in moveStart = nil }
        )
    }

    private func trafficLight(color: Color, glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isFront ? color : Color.gray.opacity(0.4))
                    .frame(width: WindowMetrics.trafficLightDiameter, height: WindowMetrics.trafficLightDiameter)
                if isFront {
                    Image(systemName: glyph)
                        .font(.system(size: 7.5, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .frame(width: WindowMetrics.trafficLightSpacing, height: WindowMetrics.titleBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if live {
            ToolContentView(window: window)
        } else {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                VStack(spacing: 10) {
                    AppIconView(tool: window.tool, size: 56)
                    Text(window.tool.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Maps a window to the view that implements its tool.
struct ToolContentView: View {
    let window: DeskWindow

    var body: some View {
        switch window.tool {
        case .browser: BrowserWindowView(window: window)
        case .files: FilesWindowView(window: window)
        case .pdf: PDFWindowView(window: window)
        case .video: VideoWindowView(window: window)
        case .notes: NotesWindowView(window: window)
        case .calculator: CalculatorWindowView(window: window)
        case .settings: SettingsWindowView(window: window)
        }
    }
}

private struct ResizeHandle: View {
    let window: DeskWindow
    let anchor: ResizeAnchor
    @ObservedObject var windows: WindowManager

    @State private var start: CGRect?

    var body: some View {
        let m = WindowMetrics.resizeMargin
        let f = window.frame
        let corner: CGFloat = 22
        let rect: CGRect = {
            switch anchor {
            case .top: return CGRect(x: corner - m, y: -m, width: f.width - 2 * (corner - m), height: 2 * m)
            case .bottom: return CGRect(x: corner - m, y: f.height - m, width: f.width - 2 * (corner - m), height: 2 * m)
            case .left: return CGRect(x: -m, y: corner - m, width: 2 * m, height: f.height - 2 * (corner - m))
            case .right: return CGRect(x: f.width - m, y: corner - m, width: 2 * m, height: f.height - 2 * (corner - m))
            case .topLeft: return CGRect(x: -m, y: -m, width: corner, height: corner)
            case .topRight: return CGRect(x: f.width + m - corner, y: -m, width: corner, height: corner)
            case .bottomLeft: return CGRect(x: -m, y: f.height + m - corner, width: corner, height: corner)
            case .bottomRight: return CGRect(x: f.width + m - corner, y: f.height + m - corner, width: corner, height: corner)
            }
        }()
        return Color.white.opacity(0.001)
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .contentShape(Rectangle())
            .offset(x: rect.minX, y: rect.minY)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("desktop"))
                    .onChanged { value in
                        if start == nil {
                            start = window.frame
                            windows.focus(window.id)
                        }
                        if let start {
                            windows.resize(window.id, anchor: anchor, from: start, by: value.translation)
                        }
                    }
                    .onEnded { _ in start = nil }
            )
    }
}
