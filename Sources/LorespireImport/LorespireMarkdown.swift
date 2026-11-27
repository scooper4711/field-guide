import Foundation

/// Markdown from the plain HTML that ``LorespireMarkup`` makes, for a page shown as text (the licenses, on the About
/// screen): headings, paragraphs, lists, emphasis and links.
enum LorespireMarkdown {
    static func markdown(from html: String) -> String {
        var text = numberingItems(html)
        for (pattern, replacement) in blocks { text = text.replacing(pattern, with: replacement) }
        text = text.replacing(/<h([1-6])\b[^>]*>(.*?)<\/h\1>/.dotMatchesNewlines()) { match in
            "\n\n" + String(repeating: "#", count: Int(match.1) ?? 2) + " " + String(match.2) + "\n\n"
        }
        text = text.replacing(/<a\b[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/.dotMatchesNewlines()) { match in
            "[\(match.2)](\(match.1))"
        }
        let plain = LorespireText.decode(text.replacing(/<[^>]+>/, with: ""))
        return plain.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n").replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static var blocks: [(Regex<Substring>, String)] { [
        (/<\/?(?:strong|b)>/, "**"), (/<\/?(?:em|i)>/, "*"), (/<br\s*\/?>/, "  \n"), (/<p\b[^>]*>/, "\n\n"),
        (/<\/p>/, "\n\n")
    ] }

    /// List items as "1. …" in a numbered list and "- …" otherwise.
    private static func numberingItems(_ html: String) -> String {
        html.replacing(/(?s)<(ol|ul)\b[^>]*>(.*?)<\/\1>/) { list in
            var number = 0
            return String(list.2).replacing(/(?s)<li\b[^>]*>(.*?)<\/li>/) { item in
                number += 1
                let marker = list.1 == "ol" ? "\(number). " : "- "
                return "\n" + marker + item.1.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            }
        }
    }
}
