import Foundation

struct SpotlightResult: Identifiable, Equatable {
    enum Kind: Equatable {
        case tool(ToolKind)
        case window(UUID)
        case file(URL)
        case web(String)
        case url(URL)
        case math(String)
    }

    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let kind: Kind
}

/// Desktop search: tools, open windows, files in Documents, quick maths and the web.
enum SpotlightEngine {
    static func search(_ rawQuery: String, windows: [DeskWindow], files: [URL]) -> [SpotlightResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [SpotlightResult] = []

        if query.isEmpty {
            return ToolKind.allCases.map(toolResult)
        }

        if MathEvaluator.looksLikeExpression(query), let value = MathEvaluator.evaluate(query) {
            let text = MathEvaluator.format(value)
            results.append(SpotlightResult(
                id: "math",
                title: "= \(text)",
                subtitle: "Calculation · tap to copy",
                symbol: "equal.circle.fill",
                kind: .math(text)
            ))
        }

        let needle = query.lowercased()

        let tools: [(score: Int, tool: ToolKind)] = ToolKind.allCases.compactMap { tool in
            let title = tool.title.lowercased()
            if title.hasPrefix(needle) { return (3, tool) }
            if title.contains(needle) { return (2, tool) }
            if tool.keywords.contains(where: { $0.hasPrefix(needle) }) { return (1, tool) }
            return nil
        }
        results += tools.sorted { $0.score > $1.score }.map { toolResult($0.tool) }

        for window in windows where window.title.lowercased().contains(needle) {
            results.append(SpotlightResult(
                id: "window-\(window.id.uuidString)",
                title: window.title,
                subtitle: "Open window · \(window.tool.title)",
                symbol: window.tool.symbol,
                kind: .window(window.id)
            ))
        }

        let matchingFiles = files
            .filter { $0.lastPathComponent.lowercased().contains(needle) }
            .prefix(6)
        for url in matchingFiles {
            results.append(SpotlightResult(
                id: "file-\(url.path)",
                title: url.lastPathComponent,
                subtitle: "File",
                symbol: symbol(forFile: url),
                kind: .file(url)
            ))
        }

        if BrowserAddress.isDirect(query), let url = BrowserAddress.directURL(query) {
            results.append(SpotlightResult(
                id: "url",
                title: "Open \(url.host ?? query)",
                subtitle: url.absoluteString,
                symbol: "globe",
                kind: .url(url)
            ))
        }

        results.append(SpotlightResult(
            id: "web",
            title: "Search the web for “\(query)”",
            subtitle: "Browser",
            symbol: "magnifyingglass",
            kind: .web(query)
        ))
        return results
    }

    static func symbol(forFile url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "mp4", "mov", "m4v": return "film"
        case "png", "jpg", "jpeg", "heic", "gif": return "photo"
        case "txt", "md", "rtf": return "doc.text"
        default: return "doc"
        }
    }

    private static func toolResult(_ tool: ToolKind) -> SpotlightResult {
        SpotlightResult(
            id: "tool-\(tool.rawValue)",
            title: tool.title,
            subtitle: "Application",
            symbol: tool.symbol,
            kind: .tool(tool)
        )
    }
}
