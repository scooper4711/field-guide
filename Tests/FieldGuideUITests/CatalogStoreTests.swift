import FieldGuideKit
import Foundation
import Testing
@testable import FieldGuideUI

@Suite("Custom creatures in the catalog's lists and searches")
@MainActor
struct CatalogStoreTests {
    @Test("Added entries list among the catalog's by name, and in a category the catalog lacks")
    func lists() throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Grizzik", .bestiary), Self.custom("Spike Pit", .hazards),
                              Self.custom("Star Wyrm", .bestiary, system: .starfinder)]
        store.category = .bestiary
        #expect(store.results.map(\.name) == ["Goblin Warrior", "Grizzik", "Ogre"])
        #expect(store.categories == [.bestiary, .hazards])
        store.category = .hazards
        #expect(store.results.map(\.name) == ["Spike Pit"])
    }

    @Test("A list's text search finds added entries by name")
    func textSearch() throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Grizzik", .bestiary)]
        store.category = .bestiary
        store.query = EntryQuery(text: "grizz", searchesText: true)
        #expect(store.results.map(\.name) == ["Grizzik"])
        store.query = EntryQuery(text: "ogre", searchesText: true)
        #expect(store.results.map(\.name) == ["Ogre"])
    }

    @Test("Search Everything finds added entries by name")
    func searchEverything() throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Grizzik", .bestiary)]
        store.globalQuery = EntryQuery(text: "griz")
        #expect(store.globalResults.flatMap(\.entries).map(\.name) == ["Grizzik"])
    }

    @Test("Search Everything in the entries' text finds added entries by name, first")
    func searchEverythingInText() async throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Big Grizzik", .bestiary)]
        store.globalQuery = EntryQuery(text: "big", searchesText: true)
        for _ in 0..<100 where store.globalResults.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(store.globalResults.flatMap(\.entries).map(\.name) == ["Big Grizzik", "Ogre"])
    }

    @Test("An added entry's page is empty, under its name; the catalog's pages are as written")
    func pages() throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Grizzik", .bestiary)]
        #expect(store.page("custom.Grizzik") == EntryPage(id: "custom.Grizzik", name: "Grizzik", system: .pathfinder,
                                                          html: ""))
        #expect(store.page("Ogre")?.html == "<p>Big.</p>")
    }

    @Test("Revealing an entry shows its category, its search cleared when that hides it; unknown ids stay put")
    func reveal() throws {
        let store = try Self.store()
        store.addedEntries = [Self.custom("Spike Pit", .hazards)]
        store.category = .hazards
        #expect(store.reveal("Ogre") && store.category == .bestiary)
        store.query = EntryQuery(text: "ogre")
        #expect(store.reveal("Ogre") && store.query.text == "ogre")
        #expect(store.reveal("Goblin") && store.query.text.isEmpty && store.results.count == 2)
        #expect(store.reveal("custom.Spike Pit") && store.category == .hazards)
        #expect(!store.reveal("Nobody") && store.category == .hazards)
    }

    static func custom(_ name: String, _ category: EntryCategory, system: GameSystem = .pathfinder) -> EntrySummary {
        EntrySummary(id: "custom.\(name)", system: system, category: category, name: name, level: 1,
                     subtitle: "Creature 1", image: "", facets: [:])
    }

    /// A store over a catalog of two Pathfinder creatures, on Pathfinder.
    static func store() throws -> CatalogStore {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Catalog-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = DataLocation(folder: folder)
        let database = try SQLiteDatabase(url: data.catalog, readOnly: false)
        try database.execute("""
            CREATE TABLE entries (id TEXT, system TEXT, category TEXT, name TEXT, level INTEGER, subtitle TEXT,
                                  image TEXT, facets TEXT, html TEXT, details TEXT, sort_name TEXT);
            CREATE VIRTUAL TABLE search USING fts5(name, text);
            INSERT INTO entries VALUES ('Goblin', 'pf2e', 'bestiary', 'Goblin Warrior', 1, 'Creature 1', '', '{}',
                                        '<p>Small.</p>', '', 'Goblin Warrior'),
                                       ('Ogre', 'pf2e', 'bestiary', 'Ogre', 3, 'Creature 3', '', '{}',
                                        '<p>Big.</p>', '', 'Ogre');
            INSERT INTO search (rowid, name, text) VALUES (1, 'Goblin Warrior', 'small'), (2, 'Ogre', 'big');
            """)
        let store = CatalogStore(data: data)
        store.system = .pathfinder
        return store
    }
}
