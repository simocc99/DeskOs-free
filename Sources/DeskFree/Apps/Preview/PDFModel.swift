import SwiftUI
import PDFKit

enum PDFTool: String, CaseIterable, Identifiable {
    case select, highlight, underline, strikeout, pen, text, eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "Select"
        case .highlight: return "Highlight"
        case .underline: return "Underline"
        case .strikeout: return "Strikethrough"
        case .pen: return "Pen"
        case .text: return "Text"
        case .eraser: return "Eraser"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikeout: return "strikethrough"
        case .pen: return "pencil.tip"
        case .text: return "textformat"
        case .eraser: return "eraser"
        }
    }

    var isMarkup: Bool {
        self == .highlight || self == .underline || self == .strikeout
    }

    /// Tools that need to capture touches on top of the page.
    var usesOverlay: Bool {
        self == .pen || self == .text || self == .eraser
    }

    var usesColor: Bool {
        self != .select && self != .eraser
    }
}

struct PDFPalette {
    static let colors: [(name: String, color: UIColor)] = [
        ("Yellow", UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)),
        ("Green", UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1)),
        ("Pink", UIColor(red: 1.0, green: 0.45, blue: 0.7, alpha: 1)),
        ("Blue", UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1)),
        ("Red", UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)),
        ("Black", UIColor.black)
    ]
}

final class PDFModel: NSObject, ObservableObject, PointerInteractive {
    let pdfView = PDFView()
    let windowID: UUID

    @Published var fileURL: URL?
    @Published var hasDocument = false
    @Published var tool: PDFTool = .select
    @Published var colorIndex = 0
    @Published var pageIndex = 0
    @Published var pageCount = 0
    @Published var hasSelection = false
    @Published var isDirty = false
    @Published var showSidebar = false
    @Published var pendingTextPoint: CGPoint?
    @Published var pendingText = ""
    @Published var message: String?
    @Published var penWidth: CGFloat = 3

    private var undoStack: [(page: PDFPage, annotation: PDFAnnotation)] = []
    private var tokens: [NSObjectProtocol] = []

    init(windowID: UUID) {
        self.windowID = windowID
        super.init()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemGray5

        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { [weak self] _ in
            self?.syncPage()
        })
        tokens.append(center.addObserver(forName: .PDFViewSelectionChanged, object: pdfView, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.hasSelection = !(self.pdfView.currentSelection?.string ?? "").isEmpty
        })
    }

    deinit {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    var color: UIColor { PDFPalette.colors[colorIndex].color }

    var markupColor: UIColor {
        tool == .highlight ? color.withAlphaComponent(0.5) : color
    }

    // MARK: Document

    func open(url: URL) {
        guard let data = try? Data(contentsOf: url), let document = PDFDocument(data: data) else {
            message = "Couldn't open this PDF."
            return
        }
        pdfView.document = document
        fileURL = url
        hasDocument = true
        pageCount = document.pageCount
        pageIndex = 0
        isDirty = false
        undoStack.removeAll()
        updateTitle()
    }

    func pickDocument() {
        DeskSession.shared.presenter.importFiles(types: [.pdf]) { [weak self] urls in
            guard let url = urls.first, let local = try? DocumentsStore.importCopy(of: url) else { return }
            self?.open(url: local)
        }
    }

    func save() {
        guard let document = pdfView.document, let url = fileURL else { return }
        if document.write(to: url) {
            isDirty = false
            message = "Saved"
        } else {
            message = "Couldn't save the file."
        }
        updateTitle()
    }

    func saveCopy() {
        guard let document = pdfView.document, let url = fileURL else { return }
        let name = url.deletingPathExtension().lastPathComponent + " (annotated).pdf"
        let destination = DocumentsStore.uniqueURL(in: url.deletingLastPathComponent(), name: name)
        message = document.write(to: destination) ? "Saved a copy: \(destination.lastPathComponent)" : "Couldn't save the copy."
    }

    func share() {
        guard let url = fileURL else { return }
        if isDirty { save() }
        DeskSession.shared.presenter.share(url)
    }

    private func updateTitle() {
        guard let url = fileURL else { return }
        DeskSession.shared.windows.setTitle(windowID, url.lastPathComponent + (isDirty ? " •" : ""))
    }

    private func syncPage() {
        guard let page = pdfView.currentPage, let document = pdfView.document else { return }
        pageIndex = document.index(for: page)
    }

    func previousPage() { pdfView.goToPreviousPage(nil) }
    func nextPage() { pdfView.goToNextPage(nil) }

    // MARK: Annotations

    private func register(_ annotation: PDFAnnotation, on page: PDFPage) {
        page.addAnnotation(annotation)
        undoStack.append((page, annotation))
        isDirty = true
        updateTitle()
    }

    func applyMarkupToSelection() {
        guard tool.isMarkup, let selection = pdfView.currentSelection else { return }
        let subtype: PDFAnnotationSubtype
        switch tool {
        case .underline: subtype = .underline
        case .strikeout: subtype = .strikeOut
        default: subtype = .highlight
        }
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let bounds = line.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: subtype, withProperties: nil)
                annotation.color = markupColor
                register(annotation, on: page)
            }
        }
        pdfView.clearSelection()
        hasSelection = false
    }

    /// `points` are in the PDF view's coordinate space.
    func commitInk(_ points: [CGPoint]) {
        guard points.count > 1, let first = points.first,
              let page = pdfView.page(for: first, nearest: true) else { return }
        let pagePoints = points.map { pdfView.convert($0, to: page) }
        let path = UIBezierPath()
        path.move(to: pagePoints[0])
        for point in pagePoints.dropFirst() {
            path.addLine(to: point)
        }
        let bounds = path.bounds.insetBy(dx: -penWidth, dy: -penWidth)
        path.apply(CGAffineTransform(translationX: -bounds.origin.x, y: -bounds.origin.y))

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = color
        let border = PDFBorder()
        border.lineWidth = penWidth
        annotation.border = border
        annotation.add(path)
        register(annotation, on: page)
    }

    func handleTap(at point: CGPoint) {
        switch tool {
        case .text:
            pendingText = ""
            pendingTextPoint = point
        case .eraser:
            erase(at: point)
        default:
            break
        }
    }

    func commitText() {
        defer {
            pendingTextPoint = nil
            pendingText = ""
        }
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let point = pendingTextPoint, !text.isEmpty,
              let page = pdfView.page(for: point, nearest: true) else { return }
        let pagePoint = pdfView.convert(point, to: page)
        let font = UIFont.systemFont(ofSize: 14)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let bounds = CGRect(x: pagePoint.x, y: pagePoint.y - size.height, width: size.width + 14, height: size.height + 8)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font
        annotation.fontColor = color
        annotation.color = .clear
        annotation.alignment = .left
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        register(annotation, on: page)
    }

    private func erase(at point: CGPoint) {
        guard let page = pdfView.page(for: point, nearest: false) else { return }
        let pagePoint = pdfView.convert(point, to: page)
        guard let annotation = page.annotation(at: pagePoint) else { return }
        let kind = annotation.type ?? ""
        let removable = ["Highlight", "Underline", "StrikeOut", "Ink", "FreeText"].contains { kind.contains($0) }
        guard removable else { return }
        page.removeAnnotation(annotation)
        undoStack.removeAll { $0.annotation === annotation }
        isDirty = true
        updateTitle()
    }

    var canUndo: Bool { !undoStack.isEmpty }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        last.page.removeAnnotation(last.annotation)
        isDirty = true
        updateTitle()
        objectWillChange.send()
    }

    // MARK: PointerInteractive

    func pointerClick(at point: CGPoint) {}

    func pointerScroll(by delta: CGPoint) {
        guard let scrollView = Self.findScrollView(in: pdfView) else { return }
        var offset = scrollView.contentOffset
        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        offset.y = min(max(offset.y - delta.y * 2, minY), maxY)
        scrollView.setContentOffset(offset, animated: false)
    }

    private static func findScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) { return found }
        }
        return nil
    }
}
