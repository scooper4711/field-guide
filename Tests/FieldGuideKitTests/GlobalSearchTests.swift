import Testing
@testable import FieldGuideKit

@Suite struct GlobalSearchTests {
    func entry(_ name: String, _ category: EntryCategory) -> EntrySummary {
        EntrySummary(id: "\(category.rawValue).\(name)", system: .pathfinder, category: category, name: name,
                     level: nil, subtitle: "", image: "", facets: [:])
    }

    /// In the catalog's order: by name.
    var search: GlobalSearch {
        GlobalSearch(entries: [
            entry("Burning Hands", .spells), entry("Élan Vital", .spells), entry("Fire Ray", .spells),
            entry("Fireball", .spells), entry("Ring of Fire", .equipment), entry("Wildfire", .feats),
            entry("Fire Mephit", .bestiary), entry("Hellfire Plume", .spells)
        ])
    }

    @Test func namesStartingWithTheTextComeFirstThenWordsStartingWithIt() {
        let groups = search.byName("fire")
        // Spells first, for Fire Ray; then Fire Mephit's Bestiary; then Ring of Fire; Wildfire last.
        #expect(groups.map(\.category) == [.spells, .bestiary, .equipment, .feats])
        let spells = groups.first { $0.category == .spells }
        #expect(spells?.entries.map(\.name) == ["Fire Ray", "Fireball", "Hellfire Plume"])
        #expect(groups.first { $0.category == .equipment }?.entries.map(\.name) == ["Ring of Fire"])
    }

    @Test func everyWordMustMatchIgnoringCaseAndAccents() {
        #expect(search.byName("ELAN vit").flatMap(\.entries).map(\.name) == ["Élan Vital"])
        #expect(search.byName("fire ball").flatMap(\.entries).map(\.name) == ["Fireball"])
        #expect(search.byName("   ").isEmpty && search.byName("dragon").isEmpty)
    }

    @Test func eachGroupShowsTheFirstFewAndCountsAll() {
        let spells = search.byName("i", limit: 2).first { $0.category == .spells }
        #expect(spells?.entries.count == 2 && spells?.total == 5)
    }

    @Test func textMatchesKeepTheCatalogsOrder() {
        let groups = search.byIDs(["spells.Fireball", "bestiary.Fire Mephit", "spells.Fire Ray", "nowhere"])
        #expect(groups.map(\.category) == [.spells, .bestiary])
        #expect(groups.first?.entries.map(\.name) == ["Fireball", "Fire Ray"] && groups.first?.id == .spells)
    }
}
