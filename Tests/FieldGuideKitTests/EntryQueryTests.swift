import Testing
@testable import FieldGuideKit

func summary(_ name: String, level: Int? = 1, facets: [Facet: [String]] = [:]) -> EntrySummary {
    EntrySummary(id: "id.\(name)", system: .pathfinder, category: .spells, name: name, level: level,
                 subtitle: "Spell", image: "", facets: facets)
}

@Suite struct EntryQueryTests {
    let entries = [
        summary("Fireball", level: 3, facets: [.traits: ["Fire", "Manipulate"], .rarity: ["Common"]]),
        summary("Élan Vital", level: 5, facets: [.traits: ["Healing"], .rarity: ["Uncommon"]]),
        summary("Light", level: 1, facets: [.traits: ["Light", "Manipulate"], .rarity: ["Common"]]),
        summary("Rest", level: nil)
    ]

    @Test func matchesEveryWordOfTheNameIgnoringCaseAndAccents() {
        var query = EntryQuery(text: "elan")
        #expect(query.apply(to: entries).map(\.name) == ["Élan Vital"])
        query.text = "fire BALL"
        #expect(query.apply(to: entries).map(\.name) == ["Fireball"])
        query.text = ""
        #expect(query.apply(to: entries).count == 4 && !query.isFiltered)
    }

    @Test func searchingTextUsesTheCatalogsMatches() {
        let query = EntryQuery(text: "burst", searchesText: true)
        #expect(query.apply(to: entries, textMatches: ["id.Light"]).map(\.name) == ["Light"])
        #expect(EntryQuery(text: "", searchesText: true).apply(to: entries, textMatches: []).count == 4)
    }

    @Test func keepsLevelsInRangeAndDropsEntriesWithoutALevel() {
        var query = EntryQuery()
        query.minimumLevel = 2
        #expect(query.apply(to: entries).map(\.name) == ["Fireball", "Élan Vital"])
        query.maximumLevel = 4
        #expect(query.apply(to: entries).map(\.name) == ["Fireball"] && query.isFiltered)
    }

    @Test func traitsMustAllMatchWhileOtherFacetsNeedOne() {
        var query = EntryQuery()
        query.chosen[.traits] = ["Manipulate", "Fire"]
        #expect(query.apply(to: entries).map(\.name) == ["Fireball"])
        query.chosen = [.rarity: ["Common", "Uncommon"]]
        #expect(query.apply(to: entries).count == 3)
        query.chosen = [.rarity: []]
        #expect(query.apply(to: entries).count == 4)
    }

    @Test func sortsByLevelThenNameWithUnleveledLast() {
        var query = EntryQuery()
        query.sort = .level
        let more = entries + [summary("Acid Splash", level: 1)]
        #expect(query.apply(to: more).map(\.name) == ["Acid Splash", "Light", "Fireball", "Élan Vital", "Rest"])
    }
}

@Suite struct FacetOptionsTests {
    @Test func countsValuesAndOrdersThemTheGamesWay() {
        let entries = [
            summary("A", level: 2, facets: [.rarity: ["Rare"], .rank: ["10", "2"]]),
            summary("B", level: 7, facets: [.rarity: ["Common"], .rank: ["Cantrip"]]),
            summary("C", level: nil, facets: [.rarity: ["Common"], .source: ["Player Core 2", "Player Core"]])
        ]
        let options = FacetOptions(entries: entries, facets: [.rarity, .rank, .source])
        #expect(options.values(of: .rarity) == ["Common", "Rare"])
        #expect(options.values(of: .rank) == ["Cantrip", "2", "10"])
        #expect(options.values(of: .source) == ["Player Core", "Player Core 2"])
        #expect(options.count(of: "Common", in: .rarity) == 2 && options.count(of: "Unique", in: .rarity) == 0)
        #expect(FacetOptions.levelRange(of: entries) == 2...7)
        #expect(FacetOptions.levelRange(of: []) == nil)
    }

    @Test func sizesAndActionsFollowTheirOrder() {
        #expect(Facet.size.sorted(["Large", "Tiny", "Odd", "Medium"]) == ["Tiny", "Medium", "Large", "Odd"])
        #expect(Facet.actionType.sorted(["Passive", "Reaction", "One Action"]) == ["One Action", "Reaction", "Passive"])
    }
}

@Suite struct CategoryTests {
    @Test func everyCategoryHasATitleSymbolAndSingular() {
        for category in EntryCategory.allCases {
            #expect(!category.title.isEmpty && !category.symbol.isEmpty && !category.singularTitle.isEmpty)
        }
        #expect(EntryCategory.campaignFeatures.title == "Campaign Features")
        #expect(EntryCategory.deities.singularTitle == "Deity" && EntryCategory.spells.singularTitle == "Spell")
        #expect(EntryCategory.bestiary.singularTitle == "Creature"
            && EntryCategory.ancestries.singularTitle == "Ancestry")
        #expect(EntryCategory.classes.singularTitle == "Class")
    }

    @Test func categoriesKnowTheirFiltersAndLevels() {
        #expect(EntryCategory.spells.facets == [.rank, .spellKind, .tradition, .castingTime])
        #expect(EntryCategory.actions.facets == [.actionType] && !EntryCategory.actions.hasLevels)
        #expect(EntryCategory.bestiary.facets == [.size] && EntryCategory.bestiary.hasLevels)
        #expect(EntryCategory.feats.facets == [.featCategory]
            && EntryCategory.campaignFeatures.facets == [.featCategory])
        #expect(EntryCategory.equipment.facets == [.itemType] && EntryCategory.hazards.facets == [.complexity])
        #expect(EntryCategory.deities.facets.isEmpty && EntryCategory.gmScreen.facets == [.section])
        #expect(EntryCategory.gmScreen.title == "GM Screen" && EntryCategory.gmScreen.singularTitle == "GM Screen")
        #expect(!EntryCategory.gmScreen.hasLevels)
        #expect(Facet.allCases.allSatisfy { !$0.title.isEmpty } && Facet.traits.matchesAll && !Facet.rarity.matchesAll)
        #expect(GameSystem.pathfinder.title == "Pathfinder" && GameSystem.starfinder.title == "Starfinder")
    }
}
