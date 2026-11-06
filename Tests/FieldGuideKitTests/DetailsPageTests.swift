import FieldGuideKit
import Testing

@Suite struct DetailsPageTests {
    @Test func anAncestrysLoreRunsFromItsStartToItsMechanics() {
        let html = "<p>Elves are ancient.</p><h2>You Might...</h2><ul><li>Study.</li></ul><h2>Elf Mechanics</h2>"
            + "<p>Hit Points 6</p>"
        #expect(DetailsPage.removingLore(from: html)
            == DetailsPage.loreMarker + "<h2>Elf Mechanics</h2><p>Hit Points 6</p>")
    }

    @Test func aClassKeepsItsKeyAttributeAndProficienciesAroundItsRoleplaying() {
        let html = "<p><strong>Key Attribute: STRENGTH</strong></p><h1>Roleplaying the Fighter</h1><p>You strike.</p>"
            + "<h2>Initial Proficiencies</h2><p>Expert in Fortitude</p>"
        let details = DetailsPage.removingLore(from: html)
        #expect(details == "<p><strong>Key Attribute: STRENGTH</strong></p>" + DetailsPage.loreMarker
            + "<h2>Initial Proficiencies</h2><p>Expert in Fortitude</p>")
        #expect(DetailsPage.inserting("<p>Lore.</p>", into: details).contains("STRENGTH</strong></p><p>Lore.</p><h2>"))
    }

    @Test func aPageWithoutRulesIsAllLore() {
        #expect(DetailsPage.removingLore(from: "<p>Only lore.</p>") == DetailsPage.loreMarker)
    }
}
