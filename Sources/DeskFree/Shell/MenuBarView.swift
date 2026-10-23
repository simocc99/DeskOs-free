import SwiftUI

struct MenuBarView: View {
    @ObservedObject var session: DeskSession
    @ObservedObject var windows: WindowManager

    var body: some View {
        let layout = session.menuLayout()
        let menus = session.menus()
        HStack(spacing: 0) {
            Button {
                windows.activate(.settings)
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: MenuBarMetrics.logoWidth, height: WindowMetrics.menuBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(windows.frontmost?.tool.title ?? "Desktop")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .frame(width: layout.appNameWidth, alignment: .leading)

            ForEach(Array(menus.enumerated()), id: \.offset) { index, menu in
                Button {
                    session.toggleMenu(index)
                } label: {
                    Text(menu.title)
                        .font(.system(size: 13))
                        .frame(width: layout.titleFrames[index].width, height: WindowMetrics.menuBarHeight)
                        .background(session.openMenu == index ? Color.white.opacity(0.22) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            StatusIcons(session: session)
                .padding(.trailing, 6)

            Button {
                session.toggleSpotlight()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: MenuBarMetrics.searchWidth, height: WindowMetrics.menuBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ClockText()
                .frame(width: MenuBarMetrics.clockWidth - 12, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .foregroundStyle(.white)
        .frame(height: WindowMetrics.menuBarHeight)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }
}

/// The open drop-down of a menu-bar menu, plus a catcher that closes it on outside taps.
struct MenuDropdownLayer: View {
    @ObservedObject var session: DeskSession
    let desktop: CGSize

    var body: some View {
        if session.openMenu != nil {
            let layout = session.menuLayout()
            let menus = session.menus()
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { session.openMenu = nil }

                if let index = layout.openIndex, let box = layout.dropdown, menus.indices.contains(index) {
                    VStack(spacing: 0) {
                        ForEach(Array(menus[index].entries.enumerated()), id: \.offset) { row, entry in
                            if entry.isSeparator {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 8)
                                    .frame(height: MenuLayout.separatorHeight)
                            } else {
                                Button {
                                    session.runMenuEntry(menu: index, row: row)
                                } label: {
                                    HStack {
                                        Text(entry.title).lineLimit(1)
                                        Spacer(minLength: 12)
                                        if !entry.shortcut.isEmpty {
                                            Text(entry.shortcut).foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 10)
                                    .frame(height: MenuLayout.rowHeight)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!entry.enabled)
                                .opacity(entry.enabled ? 1 : 0.4)
                            }
                        }
                    }
                    .padding(MenuLayout.dropdownPadding)
                    .frame(width: box.width, height: box.height, alignment: .top)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                    .offset(x: box.minX, y: box.minY)
                }
            }
            .frame(width: desktop.width, height: desktop.height, alignment: .topLeading)
        }
    }
}

private struct ClockText: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Text(context.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct StatusIcons: View {
    @ObservedObject var session: DeskSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: 10) {
                if session.liveHost == .external {
                    Image(systemName: "display")
                }
                BatteryIcon()
            }
            .font(.system(size: 13, weight: .medium))
        }
    }
}

private struct BatteryIcon: View {
    var body: some View {
        let level = UIDevice.current.batteryLevel
        let percent = level < 0 ? nil : Int((level * 100).rounded())
        HStack(spacing: 3) {
            if let percent {
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .medium))
            }
            Image(systemName: symbol(percent))
        }
    }

    private func symbol(_ percent: Int?) -> String {
        guard let percent else { return "battery.100percent" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
