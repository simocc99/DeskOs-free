import SwiftUI
import WebKit

enum BrowserMetrics {
    static let tabStripHeight: CGFloat = 32
    static let toolbarHeight: CGFloat = 42
    static let tabWidth: CGFloat = 150
    static let newTabWidth: CGFloat = 34
    static let navButtonWidth: CGFloat = 40
    static var chromeHeight: CGFloat { tabStripHeight + toolbarHeight }
}

final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let webView: WKWebView

    @Published var title = "New Tab"
    @Published var url: URL?
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false

    /// Called when a page tries to open a pop-up / `target=_blank` link.
    var onOpenInNewTab: ((URL) -> Void)?

    private var observers: [NSKeyValueObservation] = []

    init(url: URL? = nil) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observe()
        if let url { load(url) }
    }

    func load(_ url: URL) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    private func observe() {
        observers = [
            webView.observe(\.title) { [weak self] web, _ in
                guard let self else { return }
                if let title = web.title, !title.isEmpty {
                    self.title = title
                } else if let host = web.url?.host {
                    self.title = host
                }
            },
            webView.observe(\.url) { [weak self] web, _ in self?.url = web.url },
            webView.observe(\.isLoading) { [weak self] web, _ in self?.isLoading = web.isLoading },
            webView.observe(\.estimatedProgress) { [weak self] web, _ in self?.progress = web.estimatedProgress },
            webView.observe(\.canGoBack) { [weak self] web, _ in self?.canGoBack = web.canGoBack },
            webView.observe(\.canGoForward) { [weak self] web, _ in self?.canGoForward = web.canGoForward }
        ]
    }

    // MARK: WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            onOpenInNewTab?(url)
        }
        return nil
    }
}

final class BrowserModel: ObservableObject, PointerInteractive, KeyInputTarget {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedID: UUID?
    /// Text typed in the address bar but not submitted yet.
    @Published var addressDraft: String?

    init(startURL: URL?) {
        openTab(startURL)
    }

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedID } ?? tabs.first
    }

    func openTab(_ url: URL? = nil) {
        let tab = BrowserTab(url: url)
        tab.onOpenInNewTab = { [weak self] url in self?.openTab(url) }
        tabs.append(tab)
        selectedID = tab.id
        addressDraft = nil
    }

    func select(_ id: UUID) {
        selectedID = id
        addressDraft = nil
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            openTab()
        } else if selectedID == id {
            selectedID = tabs[min(index, tabs.count - 1)].id
        }
        addressDraft = nil
    }

    func commitAddress() {
        defer { addressDraft = nil }
        guard let draft = addressDraft, let tab = selectedTab, let url = BrowserAddress.resolve(draft) else { return }
        tab.load(url)
    }

    func navigate(to url: URL) {
        selectedTab?.load(url)
        addressDraft = nil
    }

    // MARK: PointerInteractive

    func pointerClick(at point: CGPoint) {
        guard let tab = selectedTab else { return }
        if point.y < BrowserMetrics.tabStripHeight {
            let index = Int(point.x / BrowserMetrics.tabWidth)
            if index < tabs.count {
                // Right part of a tab chip is its close button.
                let local = point.x - CGFloat(index) * BrowserMetrics.tabWidth
                if local > BrowserMetrics.tabWidth - 28 { closeTab(tabs[index].id) } else { select(tabs[index].id) }
            } else if point.x < CGFloat(tabs.count) * BrowserMetrics.tabWidth + BrowserMetrics.newTabWidth {
                openTab()
            }
        } else if point.y < BrowserMetrics.chromeHeight {
            let slot = Int(point.x / BrowserMetrics.navButtonWidth)
            switch slot {
            case 0: tab.webView.goBack()
            case 1: tab.webView.goForward()
            case 2: if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
            default:
                addressDraft = ""
                DeskSession.shared.requestKeyboard()
            }
        } else {
            let x = point.x
            let y = point.y - BrowserMetrics.chromeHeight
            let script = """
            (function(x, y) {
              var el = document.elementFromPoint(x, y);
              if (!el) { return; }
              if (el.focus) { el.focus(); }
              el.click();
            })(\(Int(x)), \(Int(y)));
            """
            tab.webView.evaluateJavaScript(script)
        }
    }

    func pointerScroll(by delta: CGPoint) {
        guard let scrollView = selectedTab?.webView.scrollView else { return }
        var offset = scrollView.contentOffset
        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        offset.y = min(max(offset.y - delta.y * 2, minY), maxY)
        scrollView.setContentOffset(offset, animated: false)
    }

    // MARK: KeyInputTarget

    func handle(_ key: KeyInput) {
        switch key {
        case .text(let s): addressDraft = (addressDraft ?? "") + s
        case .backspace:
            if var draft = addressDraft, !draft.isEmpty {
                draft.removeLast()
                addressDraft = draft
            }
        case .enter: commitAddress()
        }
    }
}
