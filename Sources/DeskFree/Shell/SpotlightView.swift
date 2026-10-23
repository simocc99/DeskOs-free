import SwiftUI

/// Spotlight-style desktop search. Shown on top of the desktop; when the desktop is
/// driven from the trackpad the text comes from the phone keyboard instead.
struct SpotlightLayer: View {
    @ObservedObject var session: DeskSession
    let desktop: CGSize
    let interactive: Bool

    var body: some View {
        if session.spotlightVisible {
            SpotlightView(session: session, desktop: desktop, interactive: interactive)
                .transition(.opacity)
        }
    }
}

private struct SpotlightView: View {
    @ObservedObject var session: DeskSession
    let desktop: CGSize
    let interactive: Bool

    @FocusState private var focused: Bool

    var body: some View {
        let results = Array(session.spotlightResults().prefix(7))
        let width = min(620, desktop.width * 0.78)
        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture { session.spotlightVisible = false }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    if interactive {
                        TextField("Search apps, files, the web…", text: $session.spotlightQuery)
                            .font(.system(size: 20))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($focused)
                            .onSubmit { session.launchSelectedSpotlightResult() }
                    } else {
                        Text(session.spotlightQuery.isEmpty ? "Search apps, files, the web…" : session.spotlightQuery)
                            .font(.system(size: 20))
                            .foregroundStyle(session.spotlightQuery.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 54)

                Divider()

                VStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        row(result, selected: index == session.spotlightSelection)
                    }
                }
                .padding(8)
            }
            .frame(width: width)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
            .padding(.top, WindowMetrics.menuBarHeight + 40)
        }
        .frame(width: desktop.width, height: desktop.height)
        .onAppear { focused = interactive }
        .onChange(of: session.spotlightQuery) {
            session.spotlightSelection = 0
        }
    }

    private func row(_ result: SpotlightResult, selected: Bool) -> some View {
        Button {
            session.launch(result)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: result.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    Text(result.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
