import Testing
@testable import FieldGuideKit

@Suite struct EntrySummaryTests {
    func entry(_ name: String) -> EntrySummary {
        EntrySummary(id: name, system: .pathfinder, category: .bestiary, name: name, level: nil, subtitle: "",
                     image: "", facets: [:])
    }

    @Test func addedEntriesGoAmongTheOthersByNameKeepingTheirOrder() {
        // "Zombie, Guide" stands for an entry the catalog put out of name order, which stays where it is.
        let catalog = ["Arbiter", "Zombie, Guide", "Goblin", "Ogre"].map(entry)
        let merged = EntrySummary.merging(["Troll", "Bandit", "aardvark"].map(entry), into: catalog)
        #expect(merged.map(\.name) == ["aardvark", "Arbiter", "Bandit", "Zombie, Guide", "Goblin", "Ogre", "Troll"])
    }

    @Test func nothingAddedLeavesTheListAlone() {
        let catalog = ["Goblin", "Arbiter"].map(entry)
        #expect(EntrySummary.merging([], into: catalog) == catalog)
    }
}
