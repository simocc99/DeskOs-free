import SwiftUI
import PDFKit

struct PDFWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: PDFModel

    init(window: DeskWindow) {
        self.window = window
        let id = window.id
        let payload = window.payload
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: id) {
            let created = PDFModel(windowID: id)
            if let payload { created.open(url: payload) }
            return created
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            PDFToolbar(model: model)
            Divider()
            if model.hasDocument {
                HStack(spacing: 0) {
                    if model.showSidebar {
                        PDFThumbnails(model: model)
                            .frame(width: 112)
                        Divider()
                    }
                    ZStack {
                        PDFKitHost(pdfView: model.pdfView)
                        PDFInkOverlay(model: model)
                            .allowsHitTesting(model.tool.usesOverlay)
                    }
                }
                if model.pendingTextPoint != nil {
                    textPrompt
                }
            } else {
                emptyState
            }
            if let message = model.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if model.message == message { model.message = nil }
                    }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Open a PDF to read and annotate it")
                .foregroundStyle(.secondary)
            Button("Open PDF…") { model.pickDocument() }
                .buttonStyle(.borderedProminent)
            Text("Tip: PDFs in the Files app open here with a double tap.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var textPrompt: some View {
        HStack(spacing: 8) {
            TextField("Text to place on the page", text: $model.pendingText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.commitText() }
            Button("Add") { model.commitText() }
                .buttonStyle(.borderedProminent)
            Button("Cancel") { model.pendingTextPoint = nil }
                .buttonStyle(.bordered)
        }
        .padding(8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

private struct PDFToolbar: View {
    @ObservedObject var model: PDFModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                iconButton("folder", label: "Open") { model.pickDocument() }
                iconButton("sidebar.left", selected: model.showSidebar, enabled: model.hasDocument) {
                    model.showSidebar.toggle()
                }

                divider

                ForEach(PDFTool.allCases) { tool in
                    iconButton(tool.symbol, selected: model.tool == tool, enabled: model.hasDocument) {
                        model.tool = tool
                    }
                }

                if model.tool.usesColor {
                    divider
                    ForEach(Array(PDFPalette.colors.enumerated()), id: \.offset) { index, entry in
                        Button {
                            model.colorIndex = index
                        } label: {
                            Circle()
                                .fill(Color(uiColor: entry.color))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().strokeBorder(Color.primary.opacity(model.colorIndex == index ? 0.9 : 0.15), lineWidth: model.colorIndex == index ? 2 : 1)
                                )
                                .frame(width: 28, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if model.tool.isMarkup, model.hasSelection {
                    Button("Apply") { model.applyMarkupToSelection() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                divider

                iconButton("arrow.uturn.backward", enabled: model.canUndo) { model.undo() }

                Menu {
                    Button { model.save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    Button { model.saveCopy() } label: { Label("Save a Copy", systemImage: "doc.on.doc") }
                    Button { model.share() } label: { Label("Share…", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: model.isDirty ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 32, height: 30)
                }
                .disabled(!model.hasDocument)

                divider

                iconButton("chevron.up", enabled: model.hasDocument) { model.previousPage() }
                Text(model.hasDocument ? "\(model.pageIndex + 1) / \(model.pageCount)" : "–")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 46)
                iconButton("chevron.down", enabled: model.hasDocument) { model.nextPage() }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 42)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 1, height: 20).padding(.horizontal, 2)
    }

    private func iconButton(
        _ symbol: String,
        label: String? = nil,
        selected: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                if let label {
                    Text(label).font(.system(size: 13))
                }
            }
            .frame(minWidth: 32, minHeight: 30)
            .padding(.horizontal, label == nil ? 0 : 6)
            .background(selected ? Color.accentColor.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

private struct PDFKitHost: UIViewRepresentable {
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView {
        pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private struct PDFThumbnails: UIViewRepresentable {
    let model: PDFModel

    func makeUIView(context: Context) -> PDFThumbnailView {
        let view = PDFThumbnailView()
        view.pdfView = model.pdfView
        view.thumbnailSize = CGSize(width: 72, height: 96)
        view.layoutMode = .vertical
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ uiView: PDFThumbnailView, context: Context) {}
}

// MARK: - Drawing / tap overlay

private struct PDFInkOverlay: UIViewRepresentable {
    @ObservedObject var model: PDFModel

    func makeUIView(context: Context) -> InkCanvasView {
        let view = InkCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ view: InkCanvasView, context: Context) {
        view.drawsStrokes = model.tool == .pen
        view.strokeColor = model.color
        view.lineWidth = model.penWidth
        view.onStroke = { [weak model] points in model?.commitInk(points) }
        view.onTap = { [weak model] point in model?.handleTap(at: point) }
    }
}

final class InkCanvasView: UIView {
    var drawsStrokes = false
    var strokeColor: UIColor = .red {
        didSet { shape.strokeColor = strokeColor.cgColor }
    }
    var lineWidth: CGFloat = 3 {
        didSet { shape.lineWidth = lineWidth }
    }
    var onStroke: (([CGPoint]) -> Void)?
    var onTap: ((CGPoint) -> Void)?

    private var points: [CGPoint] = []
    private var moved = false
    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shape.fillColor = nil
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.strokeColor = strokeColor.cgColor
        shape.lineWidth = lineWidth
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        points = [touch.location(in: self)]
        moved = false
        shape.path = nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        if let last = points.last, hypot(p.x - last.x, p.y - last.y) > 2 { moved = true }
        points.append(p)
        guard drawsStrokes else { return }
        let path = UIBezierPath()
        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        shape.path = path.cgPath
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            points = []
            shape.path = nil
        }
        if drawsStrokes {
            if moved { onStroke?(points) }
        } else if !moved, let p = points.first {
            onTap?(p)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        points = []
        shape.path = nil
    }
}
