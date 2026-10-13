import Testing
@testable import FieldGuideKit

@Suite struct EntryPageTests {
    func page(_ html: String) -> EntryPage {
        EntryPage(id: "id", name: "Aapoph Granitescale", system: .pathfinder, html: html)
    }

    @Test func loreIsTheDescriptionWithoutTheStatBlockOrSource() {
        let lore = PageDescription.section("<p>Granitescales carve their shed scales.</p>")
        let html = "<header>…</header><section class=\"stat-block\"><p>AC 24</p></section><hr>" + lore
            + "<footer class=\"source\">Pathfinder Monster Core</footer>"
        #expect(page(html).lore
                == "<section class=\"description\"><p>Granitescales carve their shed scales.</p></section>")
    }

    @Test func loreKeepsSectionsInsideIt() {
        let lore = PageDescription.section("<p>Lore</p><section class=\"aside\"><p>More</p></section>")
        #expect(page("<section>Stats</section><hr>" + lore).lore == lore)
    }

    @Test func aPageWithoutADescriptionHasNoLore() {
        #expect(page("<section class=\"stat-block\"><p>AC 24</p></section>").lore.isEmpty)
        #expect(page("<section class=\"description\"><p>Unclosed").lore.isEmpty)
    }
}

@Suite struct EntryLinkTests {
    @Test func detailsLinksReadBackAsTheirEntry() {
        let target = EntryLink.details(of: "Compendium.pf2e.classes.Item.fi1")
        #expect(target == "Compendium.pf2e.classes.Item.fi1#details")
        #expect(EntryLink.entry(of: target) == ("Compendium.pf2e.classes.Item.fi1", true))
        #expect(EntryLink.entry(of: "Compendium.pf2e.classes.Item.fi1") == ("Compendium.pf2e.classes.Item.fi1", false))
    }

    @Test func newCategoriesHaveTheirOwnTitles() {
        #expect(EntryCategory.remasterChanges.title == "Remaster Changes")
        #expect(EntryCategory.remasterChanges.singularTitle == "Remaster Change")
        #expect(EntryCategory.archetypes.singularTitle == "Archetype" && !EntryCategory.domains.hasLevels)
    }
}
