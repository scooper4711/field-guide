import Foundation

/// A wiki page's title and content, without the site's menus, modules and scripts.
public struct LorespirePage: Sendable, Equatable {
    public let title: String
    /// The page's article, cleaned of what only works on the site (see ``LorespireCleaner``).
    public let content: String

    /// Reads a Tiki Wiki page: the title from `h1.pagetitle`, the content from `div#page-data`.
    public init(html: String, page: String) throws {
        guard let start = html.firstMatch(of: /<div id="page-data"[^>]*>/)?.range.upperBound,
              let end = html[start...].range(of: "</article>")?.lowerBound,
              let close = html[start..<end].range(of: "</div>", options: .backwards)?.lowerBound else {
            throw LorespireError.missingContent(page: page)
        }
        let title = html.firstMatch(of: /<h1 class="pagetitle">\s*<a[^>]*>([^<]*)<\/a>/).map { String($0.1) }
        self.title = LorespireText.plain(title ?? page)
        content = LorespireCleaner.clean(String(html[start..<close]))
    }
}

/// Removes what only works on the live site: scripts, event handlers, the headings' link icons (the site's icon
/// font isn't downloaded) and the tab sets' "No Tabs" buttons, which reload the page on the site.
public enum LorespireCleaner {
    public static func clean(_ html: String) -> String {
        html.replacing(/<script\b[^>]*>.*?<\/script>/.dotMatchesNewlines(), with: "")
            .replacing(/<a href="#[^"]*" class="heading-link">.*?<\/a>/.dotMatchesNewlines(), with: "")
            .replacing(/<div class='float-right'><a [^>]*>No Tabs<\/a><\/div>/, with: "")
            .replacing(/\s+on[a-z]+="[^"]*"/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Text from HTML: tags removed, entities decoded, spaces collapsed.
enum LorespireText {
    static func plain(_ html: String) -> String {
        var text = html.replacing(/<[^>]+>/, with: "")
        for (entity, character) in entities { text = text.replacingOccurrences(of: entity, with: character) }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let entities = [
        ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&#039;", "'"),
        ("&amp;", "&")
    ]
}

public enum LorespireError: Error, CustomStringConvertible, Equatable {
    case missingContent(page: String)
    case httpStatus(url: URL, status: Int)

    public var description: String {
        switch self {
        case let .missingContent(page): "Downloading Lorespire failed: \(page) has no page content"
        case let .httpStatus(url, status): "Downloading Lorespire failed: \(url.absoluteString) answered \(status)"
        }
    }
}
