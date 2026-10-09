import FieldGuideKit
import Foundation

/// Writes `catalog.sqlite`: the entries, a full-text index over them and the trait descriptions.
enum CatalogWriter {
    static let schema = """
        CREATE TABLE entries (
            id TEXT PRIMARY KEY, system TEXT NOT NULL, category TEXT NOT NULL, name TEXT NOT NULL,
            level INTEGER, subtitle TEXT NOT NULL, image TEXT NOT NULL, facets TEXT NOT NULL, html TEXT NOT NULL
        );
        CREATE INDEX entries_by_category ON entries (system, category);
        CREATE VIRTUAL TABLE search USING fts5(name, text, tokenize = 'unicode61 remove_diacritics 2');
        CREATE TABLE traits (
            system TEXT NOT NULL, slug TEXT NOT NULL, label TEXT NOT NULL, html TEXT NOT NULL,
            PRIMARY KEY (system, slug)
        );
        """

    struct TraitRow {
        var system: GameSystem
        var slug: String
        var label: String
        var html: String
    }

    static func write(_ rows: [EntryRow], traits: [TraitRow], to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let database = try SQLiteDatabase(url: url, readOnly: false)
        try database.execute(schema)
        try database.execute("BEGIN")
        for (index, row) in rows.enumerated() { try insert(row, rowID: index + 1, into: database) }
        for trait in traits {
            try database.query("INSERT OR REPLACE INTO traits VALUES (?, ?, ?, ?)",
                               [.text(trait.system.rawValue), .text(trait.slug), .text(trait.label), .text(trait.html)])
        }
        try database.execute("COMMIT")
        try database.execute("INSERT INTO search(search) VALUES ('optimize'); VACUUM")
    }

    private static func insert(_ row: EntryRow, rowID: Int, into database: SQLiteDatabase) throws {
        try database.query(
            "INSERT OR IGNORE INTO entries (rowid, id, system, category, name, level, subtitle, image, facets, html) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [.integer(rowID), .text(row.id), .text(row.system.rawValue), .text(row.category.rawValue), .text(row.name),
             row.level.map(SQLiteValue.integer) ?? .null, .text(row.subtitle), .text(row.image),
             .text(facetsJSON(row.facets)), .text(row.html)]
        )
        try database.query("INSERT INTO search (rowid, name, text) VALUES (?, ?, ?)",
                           [.integer(rowID), .text(row.name), .text(row.text)])
    }

    static func facetsJSON(_ facets: [Facet: [String]]) -> String {
        let object = Dictionary(uniqueKeysWithValues: facets.map { ($0.key.rawValue, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(object)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
