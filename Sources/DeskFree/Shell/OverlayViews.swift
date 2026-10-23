import SwiftUI

/// Colourful grid icon used for Launchpad (not tied to any tool).
struct LaunchpadIconView: View {
    let size: CGFloat

    var body: some View {
        let colors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.72)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 0.6)
            VStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: size * 0.06) {
                        ForEach(0..<3, id: \.self) { column in
                            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                                .fill(colors[row * 3 + column])
                                .frame(width: size * 0.2, height: size * 0.2)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: size * 0.06, y: size * 0.04)
    }
}

struct DesktopIconsLayer: View {
    let session: DeskSession
    let desktop: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(DesktopIconLayout.frames(desktop: desktop), id: \.icon) { item in
                Button {
                    session.openDesktopIcon(item.icon)
                } label: {
                    VStack(spacing: 4) {
                        switch item.icon {
                        case .documents:
                            Image(systemName: "folder.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))
                                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                                .frame(width: 56, height: 56)
                        case .applications:
                            LaunchpadIconView(size: 52)
                                .frame(width: 56, height: 56)
                        }
                        Text(item.icon.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                    .frame(width: item.frame.width, height: item.frame.height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: item.frame.minX, y: item.frame.minY)
            }
        }
        .frame(width: desktop.width, height: desktop.height, alignment: .topLeading)
    }
}

struct LaunchpadLayer: View {
    @ObservedObject var session: DeskSession
    let desktop: CGSize

    var body: some View {
        if session.launchpadVisible {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(Color.black.opacity(0.25))
                    .contentShape(Rectangle())
                    .onTapGesture { session.launchpadVisible = false }

                let icon = LaunchpadLayout.iconSize(desktop: desktop)
                ForEach(LaunchpadLayout.frames(desktop: desktop), id: \.tool) { cell in
                    Button {
                        session.openApplication(cell.tool)
                    } label: {
                        VStack(spacing: 8) {
                            AppIconView(tool: cell.tool, size: icon)
                            Text(cell.tool.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(width: cell.frame.width, height: cell.frame.height, alignment: .top)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: cell.frame.minX, y: cell.frame.minY)
                }
            }
            .frame(width: desktop.width, height: desktop.height, alignment: .topLeading)
            .transition(.opacity)
        }
    }
}

struct SwitcherLayer: View {
    @ObservedObject var session: DeskSession
    @ObservedObject var windows: WindowManager

    var body: some View {
        if session.switcherVisible {
            let desktop = windows.desktopSize
            let items = windows.windows
            let cards = SwitcherLayout.cards(desktop: desktop, count: items.count)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(Color.black.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture { session.switcherVisible = false }

                if items.isEmpty {
                    Text("No open windows")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: desktop.width, height: desktop.height)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, window in
                    if index < cards.count {
                        card(window, rect: cards[index], desktop: desktop)
                    }
                }
            }
            .frame(width: desktop.width, height: desktop.height, alignment: .topLeading)
            .transition(.opacity)
        }
    }

    private func card(_ window: DeskWindow, rect: CGRect, desktop: CGSize) -> some View {
        let scale = rect.width / max(desktop.width, 1)
        let mini = CGRect(
            x: window.frame.minX * scale,
            y: window.frame.minY * scale,
            width: window.frame.width * scale,
            height: window.frame.height * scale
        )
        return Button {
            session.switcherVisible = false
            windows.focus(window.id)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(uiColor: .systemBackground).opacity(window.isMinimized ? 0.5 : 0.95))
                        .overlay(
                            Image(systemName: window.tool.symbol)
                                .font(.system(size: max(10, mini.width * 0.22)))
                                .foregroundStyle(Color.secondary)
                        )
                        .frame(width: max(mini.width, 8), height: max(mini.height, 8))
                        .offset(x: mini.minX, y: mini.minY)
                }
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(window.id == windows.frontmostID ? 0.9 : 0.25), lineWidth: window.id == windows.frontmostID ? 2 : 1)
                )
                Text(window.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: rect.width, height: SwitcherLayout.labelHeight - 6)
            }
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY)
    }
}
