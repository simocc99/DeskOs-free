import SwiftUI

final class CalculatorModel: ObservableObject, KeyInputTarget {
    @Published var expression = ""
    @Published var preview = "0"
    @Published var history: [String] = []

    private var justEvaluated = false

    func press(_ key: String) {
        switch key {
        case "AC": clear()
        case "⌫": backspace()
        case "=": equals()
        case "√": append("sqrt(")
        case "π": append("pi")
        default: append(key)
        }
    }

    private func append(_ text: String) {
        let operators: Set<String> = ["+", "−", "×", "÷", "^", "%"]
        if justEvaluated {
            // Typing an operator continues from the last result; anything else starts fresh.
            if !operators.contains(text) { expression = "" }
            justEvaluated = false
        }
        expression += text
        refreshPreview()
    }

    private func backspace() {
        if justEvaluated { clear(); return }
        guard !expression.isEmpty else { return }
        if expression.hasSuffix("sqrt(") {
            expression.removeLast(5)
        } else if expression.hasSuffix("pi") {
            expression.removeLast(2)
        } else {
            expression.removeLast()
        }
        refreshPreview()
    }

    private func clear() {
        expression = ""
        preview = "0"
        justEvaluated = false
    }

    private func equals() {
        guard !expression.isEmpty else { return }
        guard let value = MathEvaluator.evaluate(expression) else {
            preview = "Error"
            return
        }
        let text = MathEvaluator.format(value)
        history.insert("\(expression) = \(text)", at: 0)
        if history.count > 30 { history.removeLast() }
        expression = text
        preview = text
        justEvaluated = true
    }

    private func refreshPreview() {
        if let value = MathEvaluator.evaluate(expression) {
            preview = MathEvaluator.format(value)
        } else if expression.isEmpty {
            preview = "0"
        }
    }

    func handle(_ key: KeyInput) {
        switch key {
        case .enter: equals()
        case .backspace: backspace()
        case .text(let s):
            for ch in s where "0123456789.+-*/()%^".contains(ch) {
                switch ch {
                case "-": press("−")
                case "*": press("×")
                case "/": press("÷")
                default: press(String(ch))
                }
            }
        }
    }
}

struct CalculatorWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: CalculatorModel

    private let rows: [[String]] = [
        ["(", ")", "^", "√"],
        ["AC", "⌫", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["π", "0", ".", "="]
    ]

    init(window: DeskWindow) {
        self.window = window
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: window.id) { CalculatorModel() })
    }

    var body: some View {
        GeometryReader { geo in
            let displayHeight = min(96, max(44, geo.size.height * 0.2))
            let keyHeight = max(22, (geo.size.height - displayHeight - 16 - 5 * 6) / 6)
            VStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 2) {
                    Spacer(minLength: 0)
                    Text(model.expression.isEmpty ? " " : model.expression)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(model.preview)
                        .font(.system(size: min(40, displayHeight * 0.45), weight: .light))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: displayHeight)
                .padding(.horizontal, 14)

                VStack(spacing: 6) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(row, id: \.self) { key in
                                keyButton(key, height: keyHeight)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func keyButton(_ key: String, height: CGFloat) -> some View {
        let isOperator = ["÷", "×", "−", "+", "="].contains(key)
        let isFunction = ["(", ")", "^", "√", "AC", "⌫", "%", "π"].contains(key)
        return Button {
            model.press(key)
        } label: {
            Text(key)
                .font(.system(size: min(20, height * 0.5), weight: isOperator ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundStyle(isOperator ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            isOperator ? Color.orange :
                                (isFunction ? Color(uiColor: .systemGray4) : Color(uiColor: .systemBackground))
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
