import Foundation

/// Turns whatever the user typed in an address bar into a URL (direct or a web search).
enum BrowserAddress {
    static func resolve(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return directURL(text) ?? searchURL(text)
    }

    static func isDirect(_ input: String) -> Bool {
        directURL(input.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    static func directURL(_ text: String) -> URL? {
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("file://") {
            return URL(string: text)
        }
        if lower == "localhost" || lower.hasPrefix("localhost:") || lower.hasPrefix("localhost/") {
            return URL(string: "http://" + text)
        }
        guard let url = URL(string: "https://" + text), let host = url.host else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, !labels.contains(where: { $0.isEmpty }) else { return nil }
        if labels.count == 4, labels.allSatisfy({ Int($0) != nil }) { return url }
        guard let tld = labels.last, tld.count >= 2, tld.allSatisfy({ $0.isLetter }) else { return nil }
        return url
    }

    static func searchURL(_ query: String) -> URL? {
        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
