import SwiftUI

struct AppIconView: View {
    let tool: ToolKind
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(colors: tool.gradient, startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 0.6)
            Image(systemName: tool.symbol)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: size * 0.06, y: size * 0.04)
    }
}

private struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DockView: View {
    @ObservedObject var windows: WindowManager
    @ObservedObject var settings: DeskSettings

    var body: some View {
        let layout = DockLayout(
            desktop: windows.desktopSize,
            preferredIconSize: CGFloat(settings.dockIconSize),
            minimized: windows.minimizedWindows.map(\.id)
        )
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: layout.iconSize * 0.4, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.iconSize * 0.4, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                )
                .environment(\.colorScheme, .dark)
                .frame(width: layout.background.width, height: layout.background.height)
                .offset(x: layout.background.minX, y: layout.background.minY)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)

            if let dividerX = layout.dividerX {
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 1, height: layout.iconSize * 0.8)
                    .offset(x: dividerX, y: layout.background.minY + layout.iconSize * 0.1 + DockLayout.verticalPadding)
            }

            ForEach(layout.entries) { entry in
                entryView(entry, iconSize: layout.iconSize)
                    .offset(x: entry.frame.minX, y: entry.frame.minY)
            }
        }
        .frame(width: windows.desktopSize.width, height: windows.desktopSize.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func entryView(_ entry: DockEntry, iconSize: CGFloat) -> some View {
        switch entry.item {
        case .tool(let tool):
            Button {
                windows.activate(tool)
            } label: {
                AppIconView(tool: tool, size: iconSize)
                    .overlay(alignment: .bottom) {
                        if !windows.windows(of: tool).isEmpty {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 4, height: 4)
                                .offset(y: 7)
                        }
                    }
            }
            .buttonStyle(DockButtonStyle())
            .accessibilityLabel(tool.title)
        case .minimized(let id):
            if let window = windows.window(id) {
                Button {
                    windows.focus(id)
                } label: {
                    AppIconView(tool: window.tool, size: iconSize)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: iconSize * 0.2, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(.black.opacity(0.5), in: Circle())
                                .offset(x: 3, y: 3)
                        }
                }
                .buttonStyle(DockButtonStyle())
                .accessibilityLabel("Restore \(window.title)")
            }
        }
    }
}
