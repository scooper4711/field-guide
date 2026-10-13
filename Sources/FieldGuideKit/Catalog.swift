import Foundation

/// The imported entries, read from `catalog.sqlite`.
public final class Catalog {
    private let database: SQLiteDatabase

    public init(url: URL) throws {
        database = try SQLiteDatabase(url: url, readOnly: true)
    }

    /// The categories that have entries in `system`, in `EntryCategory` order.
    public func categories(in system: GameSystem) throws -> [EntryCategory] {
        var found: Set<EntryCategory> = []
        try database.query("SELECT DISTINCT category FROM entries WHERE system = ?", [.text(system.rawValue)]) {
            if let category = EntryCategory(rawValue: $0.text(0)) { found.insert(category) }
        }
        return EntryCategory.allCases.filter(found.contains)
    }

    /// Every entry of a category, by name.
    public func summaries(of category: EntryCategory, in system: GameSystem) throws -> [EntrySummary] {
        try summaries(where: "system = ? AND category = ?", [.text(system.rawValue), .text(category.rawValue)])
    }

    /// Every entry of every category of `system`, by name.
    public func summaries(in system: GameSystem) throws -> [EntrySummary] {
        try summaries(where: "system = ?", [.text(system.rawValue)])
    }

    private func summaries(where condition: String, _ values: [SQLiteValue]) throws -> [EntrySummary] {
        var result: [EntrySummary] = []
        let sql = """
            SELECT id, system, category, name, level, subtitle, image, facets FROM entries
            WHERE \(condition) ORDER BY name COLLATE NOCASE
            """
        try database.query(sql, values) { row in
            guard let category = EntryCategory(rawValue: row.text(2)) else { return }
            result.append(EntrySummary(
                id: row.text(0), system: GameSystem(rawValue: row.text(1)) ?? .pathfinder, category: category,
                name: row.text(3), level: row.integer(4), subtitle: row.text(5), image: row.text(6),
                facets: Self.facets(fromJSON: row.text(7))
            ))
        }
        return result
    }

    /// The entry's page body as HTML, or nil when there is no such entry.
    public func page(of id: String) throws -> EntryPage? {
        var page: EntryPage?
        try database.query("SELECT name, system, html, details FROM entries WHERE id = ?", [.text(id)]) { row in
            page = EntryPage(id: id, name: row.text(0), system: GameSystem(rawValue: row.text(1)) ?? .pathfinder,
                             html: row.text(2), details: row.text(3))
        }
        return page
    }

    /// The IDs of a category's entries whose name or text contains every word of `text`.
    public func search(_ text: String, in category: EntryCategory, of system: GameSystem) throws -> Set<String> {
        guard let match = Self.match(text) else { return [] }
        var ids: Set<String> = []
        // Matched once, then filtered: joined, SQLite runs the match again for every entry of the category, which
        // takes minutes for a one-letter prefix in the bestiary.
        let sql = """
            SELECT id FROM entries
            WHERE system = ? AND category = ? AND rowid IN (SELECT rowid FROM search WHERE search MATCH ?)
            """
        try database.query(sql, [.text(system.rawValue), .text(category.rawValue), .text(match)]) {
            ids.insert($0.text(0))
        }
        return ids
    }

    /// The IDs of `system`'s entries whose name or text contains every word of `text`, best first: a match in the
    /// name counts ten times one in the text.
    public func rankedSearch(_ text: String, in system: GameSystem) throws -> [String] {
        guard let match = Self.match(text) else { return [] }
        var ids: [String] = []
        // Materialized so the text is matched once, as in `search(_:in:of:)`.
        let sql = """
            WITH matches AS MATERIALIZED (
                SELECT rowid, bm25(search, 10.0, 1.0) AS score FROM search WHERE search MATCH ?
            )
            SELECT entries.id FROM matches JOIN entries ON entries.rowid = matches.rowid
            WHERE entries.system = ? ORDER BY matches.score, entries.name COLLATE NOCASE
            """
        try database.query(sql, [.text(match), .text(system.rawValue)]) { ids.append($0.text(0)) }
        return ids
    }

    /// A full-text query matching every word of `text` as a prefix; nil when it has no words.
    static func match(_ text: String) -> String? {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return words.isEmpty ? nil : words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// A trait's description page, or nil when the system has none for it.
    public func trait(_ slug: String, in system: GameSystem) throws -> EntryPage? {
        var page: EntryPage?
        try database.query("SELECT label, html FROM traits WHERE system = ? AND slug = ?",
                           [.text(system.rawValue), .text(slug)]) { row in
            page = EntryPage(id: "trait:\(slug)", name: row.text(0), system: system, html: row.text(1))
        }
        return page
    }

    static func facets(fromJSON json: String) -> [Facet: [String]] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: object.compactMap { key, values in
            Facet(rawValue: key).map { ($0, values) }
        })
    }
}

/// An entry's page, ready to show.
public struct EntryPage: Equatable, Sendable {
    public let id: String
    public let name: String
    public let system: GameSystem
    public let html: String
    /// An ancestry's or class's page from the rules journals, shown beside its overview; empty for others.
    public let details: String

    public init(id: String, name: String, system: GameSystem, html: String, details: String = "") {
        self.id = id
        self.name = name
        self.system = system
        self.html = html
        self.details = details
    }

    /// The page's description section: a creature's lore, without its stat block; empty when it has none.
    public var lore: String {
        PageDescription.section(in: html)
    }
}

/// How links lead to an entry's Details (`EntryPage.details`): `entry:<id>#details`.
public enum EntryLink {
    public static let detailsSuffix = "#details"

    /// The link target of `entryID`'s Details.
    public static func details(of entryID: String) -> String {
        entryID + detailsSuffix
    }

    /// The entry a link target leads to, and whether to its Details.
    public static func entry(of target: String) -> (id: String, isDetails: Bool) {
        target.hasSuffix(detailsSuffix) ? (String(target.dropLast(detailsSuffix.count)), true) : (target, false)
    }
}

/// The description section the import writes after an entry's details or stat block.
public enum PageDescription {
    static let opening = "<section class=\"description\">"
    static let closing = "</section>"

    /// `html` as the page's description section.
    public static func section(_ html: String) -> String {
        opening + html + closing
    }

    /// The description section of `page`, which comes last before the source line; empty when it has none.
    public static func section(in page: String) -> String {
        guard let start = page.range(of: opening)?.lowerBound,
              let end = page.range(of: closing, options: .backwards, range: start..<page.endIndex)?.upperBound
        else { return "" }
        return String(page[start..<end])
    }
}
