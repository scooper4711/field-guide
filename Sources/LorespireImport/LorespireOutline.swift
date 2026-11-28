import Foundation

/// A heading of a downloaded document that has an `id`.
struct LorespireHeading {
    let level: Int
    let id: String
    /// Where the whole `<hN>…</hN>` element is.
    let range: Range<String.Index>
    /// The HTML inside it.
    let inner: String
    /// The wiki page that the heading links to, when it links to one: that page starts here.
    let page: String?

    var title: String { LorespireText.plain(inner) }

    static func all(in html: String) -> [LorespireHeading] {
        html.matches(of: /<h([1-6])\b[^>]*\bid="([^"]+)"[^>]*>(.*?)<\/h\1>/.dotMatchesNewlines()).map {
            LorespireHeading(level: Int($0.1) ?? 1, id: String($0.2), range: $0.range, inner: String($0.3),
                             page: $0.3.firstMatch(of: /page=([^"#&]+)/).map { String($0.1) })
        }
    }
}

/// One original wiki page inside a downloaded document: from its heading to the next heading of the same or a
/// higher level, without the pages inside it.
struct LorespireSection {
    /// The wiki page's name, or `<document page>.<heading id>` for a top-level section without a page of its own.
    let key: String
    let name: String
    let level: Int
    let headingID: String
    /// The part of the guide it belongs to: Introduction, Core Guide, and so on.
    let part: String
    /// The section's own HTML, after its heading, with a link to each page inside it in that page's place.
    let html: String
    /// The ids of the headings in ``html``, and its own, for links to a heading.
    var headingIDs: [String]
    /// The keys of the empty pages just before it, which open it instead.
    var aliases: [String] = []
    /// The ids of those empty pages' headings, which open it at its top: its page doesn't show them.
    var foldedHeadingIDs: [String] = []

    var hasText: Bool { !LorespireText.plain(html).isEmpty }
}

/// Splits a document into its wiki pages (``LorespireSection``).
///
/// A heading that links to a wiki page starts that page; so does every heading at the level of the highest such
/// heading, linked or not (the Venture-Officer Handbook has unlinked top-level sections). What comes before the
/// first page, apart from its headings, goes at the top of the first page.
struct LorespireOutline {
    let document: LorespireDocument
    let content: String
    private let headings: [LorespireHeading]
    private let starts: [Int]
    /// The starts that are the first heading to link to their page.
    private let linked: Set<Int>

    init(document: LorespireDocument, content: String) {
        self.document = document
        self.content = content
        headings = LorespireHeading.all(in: content)
        linked = Self.firstLinks(in: headings)
        starts = Self.starts(in: headings, linked: linked)
    }

    /// The pages in order. A page with no text of its own (only a heading) is left out, and links to it open the
    /// next page.
    var sections: [LorespireSection] {
        var sections: [LorespireSection] = []
        var empty: [LorespireSection] = []
        for var section in starts.indices.map(section) {
            guard section.hasText else {
                empty.append(section)
                continue
            }
            section.aliases = empty.flatMap { [$0.key] + $0.aliases }
            section.foldedHeadingIDs = empty.flatMap(\.headingIDs)
            section.headingIDs += section.foldedHeadingIDs
            empty = []
            sections.append(section)
        }
        return sections
    }

    private static func firstLinks(in headings: [LorespireHeading]) -> Set<Int> {
        var seen: Set<String> = []
        return Set(headings.indices.filter { headings[$0].page.map { seen.insert($0).inserted } ?? false })
    }

    private static func starts(in headings: [LorespireHeading], linked: Set<Int>) -> [Int] {
        guard let first = linked.min(), let top = linked.map({ headings[$0].level }).min() else { return [] }
        return headings.indices.filter { $0 >= first && (linked.contains($0) || headings[$0].level <= top) }
    }

    private func section(at position: Int) -> LorespireSection {
        let heading = headings[starts[position]]
        let children = children(of: position)
        var html = position == 0 ? preamble : ""
        var cursor = heading.range.upperBound
        for child in children {
            html += content[cursor..<headings[starts[child]].range.lowerBound] + link(to: child)
            cursor = end(of: child)
        }
        html += content[cursor..<end(of: position)]
        return LorespireSection(key: key(of: starts[position]), name: heading.title, level: heading.level,
                                headingID: heading.id, part: part(of: position), html: html,
                                headingIDs: [heading.id] + LorespireHeading.all(in: html).map(\.id))
    }

    /// Where a page's span ends: at the next heading of the same or a higher level.
    private func end(of position: Int) -> String.Index {
        let index = starts[position]
        let next = headings[(index + 1)...].first { $0.level <= headings[index].level }
        return next?.range.lowerBound ?? content.endIndex
    }

    /// The pages directly inside a page.
    private func children(of position: Int) -> [Int] {
        var children: [Int] = []
        var cursor = position + 1
        while cursor < starts.count, headings[starts[cursor]].range.lowerBound < end(of: position) {
            children.append(cursor)
            cursor = starts.indices.dropFirst(cursor + 1).first {
                headings[starts[$0]].range.lowerBound >= end(of: cursor)
            } ?? starts.count
        }
        return children
    }

    private func part(of position: Int) -> String {
        if let part = document.part { return part }
        let top = starts[...position].last { headings[$0].level == headings[starts[0]].level } ?? starts[position]
        return headings[top].title
    }

    private func key(of index: Int) -> String {
        guard linked.contains(index), let page = headings[index].page else {
            return document.page + "." + headings[index].id
        }
        return page
    }

    /// In a page, where a page inside it was: a link to it, which the link rewriter points at its entry.
    private func link(to position: Int) -> String {
        let heading = headings[starts[position]]
        return "<p class=\"subpage\"><a href=\"tiki-index.php?page=\(document.page)#\(heading.id)\">"
            + "\(LorespireText.escape(heading.title))</a></p>\n"
    }

    /// What comes before the first page, without its headings and the "Single Page Layout" line.
    private var preamble: String {
        guard let first = starts.first else { return "" }
        return String(content[..<headings[first].range.lowerBound])
            .replacing(/<h([1-6])\b.*?<\/h\1>/.dotMatchesNewlines(), with: "")
            .replacing(/<p>\s*Single Page Layout\s*<\/p>/, with: "")
    }
}
