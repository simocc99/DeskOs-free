import Foundation

/// Small recursive-descent calculator used by the Calculator app and by desktop search.
/// Supports + - × ÷ ^ %, parentheses, unary signs, `pi`, `e` and `sqrt(...)`.
enum MathEvaluator {
    static func evaluate(_ text: String) -> Double? {
        var parser = Parser(text)
        guard let value = parser.parseExpression(), parser.atEnd, value.isFinite else { return nil }
        return value
    }

    static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        var s = String(format: "%.10g", value)
        if s.contains("e") { return s }
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }

    /// True when the text contains digits *and* an operator, so that plain words or
    /// plain numbers are not treated as maths in search.
    static func looksLikeExpression(_ text: String) -> Bool {
        let operators = CharacterSet(charactersIn: "+-*/×÷^%()")
        let hasDigit = text.rangeOfCharacter(from: .decimalDigits) != nil
        let hasOperator = text.rangeOfCharacter(from: operators) != nil
        return hasDigit && hasOperator && evaluate(text) != nil
    }

    private struct Parser {
        private let chars: [Character]
        private var pos = 0

        init(_ text: String) {
            let normalised = text
                .replacingOccurrences(of: "×", with: "*")
                .replacingOccurrences(of: "÷", with: "/")
                .replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: ",", with: ".")
                .lowercased()
            chars = Array(normalised.filter { !$0.isWhitespace })
        }

        var atEnd: Bool { pos >= chars.count }

        private func peek() -> Character? {
            pos < chars.count ? chars[pos] : nil
        }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let c = peek(), c == "+" || c == "-" {
                pos += 1
                guard let rhs = parseTerm() else { return nil }
                value = c == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parseUnary() else { return nil }
            while let c = peek(), c == "*" || c == "/" {
                pos += 1
                guard let rhs = parseUnary() else { return nil }
                if c == "/" {
                    if rhs == 0 { return nil }
                    value /= rhs
                } else {
                    value *= rhs
                }
            }
            return value
        }

        /// Signs bind looser than `^`, so `-2^2` is `-(2^2)`.
        private mutating func parseUnary() -> Double? {
            if let c = peek(), c == "+" || c == "-" {
                pos += 1
                guard let value = parseUnary() else { return nil }
                return c == "-" ? -value : value
            }
            return parsePower()
        }

        /// Right associative: `2^3^2` is `2^(3^2)`.
        private mutating func parsePower() -> Double? {
            guard let base = parsePostfix() else { return nil }
            if peek() == "^" {
                pos += 1
                guard let exponent = parseUnary() else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        private mutating func parsePostfix() -> Double? {
            guard var value = parsePrimary() else { return nil }
            while peek() == "%" {
                pos += 1
                value /= 100
            }
            return value
        }

        private mutating func parsePrimary() -> Double? {
            guard let c = peek() else { return nil }
            if c == "(" {
                pos += 1
                guard let value = parseExpression(), peek() == ")" else { return nil }
                pos += 1
                return value
            }
            if c.isNumber || c == "." {
                return parseNumber()
            }
            if c.isLetter {
                var name = ""
                while let l = peek(), l.isLetter {
                    name.append(l)
                    pos += 1
                }
                switch name {
                case "pi": return Double.pi
                case "e": return M_E
                case "sqrt":
                    guard peek() == "(" else { return nil }
                    pos += 1
                    guard let value = parseExpression(), peek() == ")", value >= 0 else { return nil }
                    pos += 1
                    return value.squareRoot()
                default:
                    return nil
                }
            }
            return nil
        }

        private mutating func parseNumber() -> Double? {
            var text = ""
            var seenDot = false
            while let c = peek(), c.isNumber || c == "." {
                if c == "." {
                    if seenDot { return nil }
                    seenDot = true
                }
                text.append(c)
                pos += 1
            }
            return Double(text)
        }
    }
}
