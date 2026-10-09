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
        var result: [EntrySummary] = []
        let sql = """
            SELECT id, name, level, subtitle, image, facets FROM entries
            WHERE system = ? AND category = ? ORDER BY name COLLATE NOCASE
            """
        try database.query(sql, [.text(system.rawValue), .text(category.rawValue)]) { row in
            result.append(EntrySummary(
                id: row.text(0), system: system, category: category, name: row.text(1), level: row.integer(2),
                subtitle: row.text(3), image: row.text(4), facets: Self.facets(fromJSON: row.text(5))
            ))
        }
        return result
    }

    /// The entry's page body as HTML, or nil when there is no such entry.
    public func page(of id: String) throws -> EntryPage? {
        var page: EntryPage?
        try database.query("SELECT name, system, html FROM entries WHERE id = ?", [.text(id)]) { row in
            page = EntryPage(id: id, name: row.text(0), system: GameSystem(rawValue: row.text(1)) ?? .pathfinder,
                             html: row.text(2))
        }
        return page
    }

    /// The IDs of a category's entries whose name or text contains every word of `text`.
    public func search(_ text: String, in category: EntryCategory, of system: GameSystem) throws -> Set<String> {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        guard !words.isEmpty else { return [] }
        let match = words.map { "\"\($0)\"*" }.joined(separator: " ")
        var ids: Set<String> = []
        let sql = """
            SELECT entries.id FROM search JOIN entries ON entries.rowid = search.rowid
            WHERE search MATCH ? AND entries.system = ? AND entries.category = ?
            """
        try database.query(sql, [.text(match), .text(system.rawValue), .text(category.rawValue)]) {
            ids.insert($0.text(0))
        }
        return ids
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
}
