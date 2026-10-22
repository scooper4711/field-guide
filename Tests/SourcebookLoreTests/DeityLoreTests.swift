import Testing
@testable import SourcebookLore

@Suite struct DeityLoreTests {
    @Test func showsTheSettingsStatLinesInOrderThenTheWriteUp() {
        let lore = DeityLore(statLines: [
            StatLine(label: "Edicts", text: "follow the rule of law"),
            StatLine(label: "Favored Weapon", text: "crossbow"),
            StatLine(label: "Title", text: "Master of the First Vault")
        ], paragraphs: ["Abadar keeps the First Vault.", "Taxes & tithes <both>."])
        #expect(lore.html == "<section class=\"description\">"
            + "<p><strong>Title</strong> Master of the First Vault</p>"
            + "<p><strong>Edicts</strong> follow the rule of law</p>"
            + "<p>Abadar keeps the First Vault.</p><p>Taxes &amp; tithes &lt;both&gt;.</p></section>")
    }

    @Test func showsTheDivineIntercessionLastWithItsNote() {
        let lore = DeityLore(intercession: Intercession(introduction: ["Gifts of riches."],
                                                        effects: [StatLine(label: "Minor Boon", text: "Luck.")]),
                             intercessionNote: "From an older book.")
        #expect(lore.html == "<section class=\"description\"><h3>Divine Intercession</h3><p>Gifts of riches.</p>"
            + "<p><strong>Minor Boon</strong> Luck.</p><p class=\"note\"><em>From an older book.</em></p></section>")
        #expect(!lore.isEmpty)
    }

    @Test func isEmptyWithoutStatLinesOrProse() {
        #expect(DeityLore().isEmpty)
        #expect(!DeityLore(paragraphs: ["Prose."]).isEmpty)
        #expect(!DeityLore(statLines: [StatLine(label: "Edicts", text: "x")]).isEmpty)
    }

    @Test func mergesAnotherSourcesStatLinesLabelByLabel() {
        let writeup = DeityLore(statLines: [StatLine(label: "Edicts", text: "old"),
                                            StatLine(label: "Title", text: "T")], paragraphs: ["Prose."])
        let table = DeityLore(statLines: [StatLine(label: "Edicts", text: "new"),
                                          StatLine(label: "Anathema", text: "none")])
        let merged = writeup.merging(statLinesOf: table)
        #expect(merged.statLines == [StatLine(label: "Edicts", text: "new"), StatLine(label: "Title", text: "T"),
                                     StatLine(label: "Anathema", text: "none")])
        #expect(merged.paragraphs == ["Prose."])
    }
}
