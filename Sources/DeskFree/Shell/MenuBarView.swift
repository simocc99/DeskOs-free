import SwiftUI

struct MenuBarView: View {
    let session: DeskSession
    @ObservedObject var windows: WindowManager

    var body: some View {
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

            Text(activeTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

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

    private var activeTitle: String {
        windows.frontmost?.tool.title ?? "Desktop"
    }
}

private struct ClockText: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Text(context.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
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
