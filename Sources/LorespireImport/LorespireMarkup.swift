import Foundation

/// Turns Tiki Wiki's markup into plain HTML, for the app's own stylesheet: footnotes inline, each tab of a tab set
/// under a heading of its own, cards as asides, and no classes, styles or wrappers.
enum LorespireMarkup {
    static func simplify(_ html: String) -> String {
        let titles = tabTitles(in: html)
        var walker = Walker(tabTitles: titles)
        return walker.rewrite(inlineFootnotes(html))
            .replacing(/<p>\s*(<br\s*\/?>\s*)+/, with: "<p>")
            .replacing(/<p>\s*<\/p>\s*/, with: "")
    }

    /// The attributes kept on every element; the rest only style the site.
    static let keptAttributes: Set<String> = ["href", "src", "alt", "id", "rowspan", "colspan", "width", "height"]

    /// A mouseover footnote (a superscript that opens a box) as the box's text, in parentheses after its anchor.
    static func inlineFootnotes(_ html: String) -> String {
        let footnote = #/
            <a\ id="[^"]*"\ +class="plugin-mouseover-anchor">.*?</a>\s*
            <span\ id="[^"]*"\ class="plugin-mouseover"[^>]*>(.*?)</span>
            /#
        return html.replacing(footnote.dotMatchesNewlines()) { match in
            let note = String(match.1).replacing(/(<br\s*\/?>)?\s*\(click to close\)\s*$/, with: "")
                .replacing(/<br\s*\/?>/, with: "; ")
            return "<small>(\(note.trimmingCharacters(in: .whitespacesAndNewlines)))</small>"
        }
    }

    /// Each tab's title, by the `id` of the pane that holds it.
    static func tabTitles(in html: String) -> [String: String] {
        var titles: [String: String] = [:]
        for match in html.matches(of: /<a class="nav-link[^"]*" href="#([^"]+)" data-toggle="tab">(.*?)<\/a>/) {
            titles[String(match.1)] = LorespireText.plain(String(match.2))
        }
        return titles
    }

    /// Walks the tags in order, keeping a stack of what each open `<div>` becomes.
    private struct Walker {
        let tabTitles: [String: String]
        private var divs: [DivAction] = []
        private var skipping = 0

        init(tabTitles: [String: String]) {
            self.tabTitles = tabTitles
        }

        mutating func rewrite(_ html: String) -> String {
            var output = ""
            var cursor = html.startIndex
            for match in html.matches(of: /<(\/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>/) {
                if skipping == 0 { output += html[cursor..<match.range.lowerBound] }
                cursor = match.range.upperBound
                let tag = Tag(isClosing: !match.1.isEmpty, name: match.2.lowercased(), attributes: String(match.3))
                output += replacement(for: tag)
            }
            return output + (skipping == 0 ? html[cursor...] : "")
        }

        private mutating func replacement(for tag: Tag) -> String {
            if tag.name == "div" { return tag.isClosing ? closeDiv() : openDiv(tag) }
            guard skipping == 0, tag.name != "span" else { return "" }
            return tag.isClosing ? "</\(tag.name)>" : tag.simplified
        }

        private mutating func openDiv(_ tag: Tag) -> String {
            let action = DivAction(tag, tabTitles: tabTitles)
            divs.append(skipping > 0 ? .skip : action)
            if skipping > 0 || action == .skip {
                skipping += 1
                return ""
            }
            return action.opening
        }

        private mutating func closeDiv() -> String {
            guard let action = divs.popLast() else { return "" }
            if action == .skip {
                skipping -= 1
                return ""
            }
            return action.closing
        }
    }

    private struct Tag {
        let isClosing: Bool
        let name: String
        let attributes: String

        /// The opening tag with only ``LorespireMarkup/keptAttributes``.
        var simplified: String {
            let kept = attributes.matches(of: /([a-zA-Z-]+)\s*=\s*("[^"]*"|'[^']*')/)
                .filter { LorespireMarkup.keptAttributes.contains($0.1.lowercased()) }
                .map { " \($0.1.lowercased())=\"\($0.2.dropFirst().dropLast())\"" }
            let selfClosing = attributes.hasSuffix("/") ? " /" : ""
            return "<\(name)\(kept.joined())\(selfClosing)>"
        }

        func value(of attribute: String) -> String {
            attributes.matches(of: /([a-zA-Z-]+)\s*=\s*("[^"]*"|'[^']*')/).first { $0.1.lowercased() == attribute }
                .map { String($0.2.dropFirst().dropLast()) } ?? ""
        }
    }

    /// What a `<div>` becomes.
    private enum DivAction: Equatable {
        /// Left out with everything in it: a tab set's tab bar.
        case skip
        /// Only the tag goes; what is in it stays.
        case unwrap
        /// The start of a tab, under its title.
        case tab(String)
        case card, cardHeader

        init(_ tag: Tag, tabTitles: [String: String]) {
            let classes = Set(tag.value(of: "class").split(separator: " ").map(String.init))
            if let title = tabTitles[tag.value(of: "id")] {
                self = .tab(title)
            } else if classes.contains("tabs") {
                self = .skip
            } else if classes.contains("card") {
                self = .card
            } else if classes.contains("card-header") {
                self = .cardHeader
            } else {
                self = .unwrap
            }
        }

        var opening: String {
            switch self {
            case let .tab(title): "<h6 class=\"tab\">\(LorespireText.escape(title))</h6>"
            case .card: "<aside>"
            case .cardHeader: "<p class=\"card-title\">"
            case .skip, .unwrap: ""
            }
        }

        var closing: String {
            switch self {
            case .card: "</aside>"
            case .cardHeader: "</p>"
            case .skip, .unwrap, .tab: ""
            }
        }
    }
}
