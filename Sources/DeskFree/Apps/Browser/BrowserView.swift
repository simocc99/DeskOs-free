import SwiftUI
import WebKit

struct BrowserWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: BrowserModel

    init(window: DeskWindow) {
        self.window = window
        let url = window.payload
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: window.id) {
            BrowserModel(startURL: url)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            BrowserTabStrip(model: model)
            if let tab = model.selectedTab {
                BrowserToolbar(model: model, tab: tab, windowID: window.id)
                ZStack {
                    WebViewHost(webView: tab.webView)
                        .id(tab.id)
                    BrowserStartPage(model: model, tab: tab)
                }
            }
        }
    }
}

private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct BrowserTabStrip: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(model.tabs) { tab in
                        BrowserTabChip(model: model, tab: tab, selected: tab.id == model.selectedTab?.id)
                    }
                }
            }
            .frame(maxWidth: CGFloat(model.tabs.count) * BrowserMetrics.tabWidth)

            Button {
                model.openTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: BrowserMetrics.newTabWidth, height: BrowserMetrics.tabStripHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(height: BrowserMetrics.tabStripHeight)
        .background(Color(uiColor: .systemGray5))
    }
}

private struct BrowserTabChip: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var tab: BrowserTab
    let selected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if tab.isLoading {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(tab.title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                model.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: BrowserMetrics.tabStripHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .frame(width: BrowserMetrics.tabWidth, height: BrowserMetrics.tabStripHeight)
        .background(selected ? Color(uiColor: .systemBackground) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.select(tab.id) }
    }
}

private struct BrowserToolbar: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var tab: BrowserTab
    let windowID: UUID

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            navButton("chevron.left", enabled: tab.canGoBack) { tab.webView.goBack() }
            navButton("chevron.right", enabled: tab.canGoForward) { tab.webView.goForward() }
            navButton(tab.isLoading ? "xmark" : "arrow.clockwise", enabled: true) {
                if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
            }

            HStack(spacing: 6) {
                Image(systemName: tab.url?.scheme == "https" ? "lock.fill" : "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search or enter website", text: addressBinding)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit { model.commitAddress() }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.trailing, 8)
        }
        .frame(height: BrowserMetrics.toolbarHeight)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5)
                if tab.isLoading {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * tab.progress, height: 2)
                    }
                    .frame(height: 2)
                }
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { model.addressDraft = nil }
        }
        .onChange(of: tab.title) { _, title in
            DeskSession.shared.windows.setTitle(windowID, title)
        }
        .onAppear {
            DeskSession.shared.windows.setTitle(windowID, tab.title)
        }
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.addressDraft ?? tab.url?.absoluteString ?? "" },
            set: { model.addressDraft = $0 }
        )
    }

    private func navButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: BrowserMetrics.navButtonWidth, height: BrowserMetrics.toolbarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
        .disabled(!enabled)
    }
}

/// Shown on empty tabs.
private struct BrowserStartPage: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var tab: BrowserTab

    private struct Favorite: Identifiable {
        let name: String
        let symbol: String
        let url: String
        var id: String { name }
    }

    private let favorites: [Favorite] = [
        Favorite(name: "DuckDuckGo", symbol: "magnifyingglass", url: "https://duckduckgo.com"),
        Favorite(name: "Wikipedia", symbol: "book.closed", url: "https://wikipedia.org"),
        Favorite(name: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com"),
        Favorite(name: "YouTube", symbol: "play.rectangle", url: "https://youtube.com"),
        Favorite(name: "Maps", symbol: "map", url: "https://www.openstreetmap.org"),
        Favorite(name: "News", symbol: "newspaper", url: "https://news.ycombinator.com")
    ]

    var body: some View {
        if tab.url == nil && !tab.isLoading {
            ZStack {
                Color(uiColor: .systemBackground)
                VStack(spacing: 18) {
                    Text("Favorites")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 14)], spacing: 14) {
                        ForEach(favorites) { favorite in
                            Button {
                                if let url = URL(string: favorite.url) { model.navigate(to: url) }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: favorite.symbol)
                                        .font(.system(size: 22))
                                        .frame(width: 52, height: 52)
                                        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    Text(favorite.name)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 460)
                }
            }
        }
    }
}
