import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct EnricherTests {
    func enricher(documents: [SourceDocument] = []) -> Enricher {
        let localizer = Localizer(roots: [.object(["PF2E": .object(["Key": .string("localized")])])])
        return Enricher(localizer: localizer, links: LinkIndex(documents: documents))
    }

    @Test func checksSayTheirDCAndKind() {
        #expect(CheckText.text("will|dc:25") == "DC 25 Will save")
        #expect(CheckText.text("type:athletics|against:fortitude") == "Athletics check against Fortitude DC")
        #expect(CheckText.text("flat|dc:5") == "DC 5 Flat check")
        #expect(CheckText.text("reflex|basic|defense:class") == "basic Reflex save against class DC")
    }

    @Test func damageListsEachPart() {
        #expect(DamageText.text("(2d6+4)[fire],1d6[persistent,bleed]") == "2d6+4 fire plus 1d6 persistent bleed")
        #expect(DamageText.text("(1d4+(@item.level)[splash])[acid]|options:x") == "(1d4+(@item.level)[splash]) acid")
        #expect(DamageText.text("5") == "5")
        #expect(TemplateText.text("cone|distance:15") == "15-foot cone"
            && TemplateText.text("emanation") == "emanation")
    }

    @Test func labelsWinAndUnknownEnrichersAreCounted() {
        let enricher = enricher()
        #expect(enricher.enrich("@Check[will|dc:1]{Will DC 1} @Damage[1d4[fire]]{fire} @Embed[x] @Trait[fire]{Fire}")
                == "<span class=\"check\">Will DC 1</span> <span class=\"damage\">fire</span>  Fire")
        #expect(enricher.enrich("@Unknown[x]{shown} @Unknown[y]") == "shown ")
        #expect(enricher.unconverted == ["Unknown": 2])
        #expect(enricher.enrich("a@b.c and @Localize[PF2E.Key] and @Localize[PF2E.Missing]") == "a@b.c and localized " +
            "and ")
    }

    @Test func inlineRollsBecomeTheirLabelOrFormula() {
        let enricher = enricher()
        #expect(enricher.enrich("[[/r 2d6 #damage]] [[/br 1d20+5]]{attack} [[/act tumble-through skill=acrobatics]]")
                == "2d6 attack Tumble Through")
        #expect(enricher.enrich("regains [[/r 4d8[healing] #Treat Wounds]] Hit Points") == "regains 4d8 Hit Points")
        #expect(enricher.enrich("plus [[/r (2[splash])[bludgeoning]]]{2 bludgeoning splash damage}.")
                == "plus 2 bludgeoning splash damage.")
    }

    @Test func enrichersMissingTheirClosingBracketEndAtTheFirstSpace() {
        #expect(enricher().enrich("@Check[thievery|dc:28 (expert) to pick") == "<span class=\"check\">DC 28 Thievery "
            + "check</span> (expert) to pick")
        #expect(enricher().enrich("an @Check[ alone") == "an @Check[ alone")
    }

    @Test func linksLeadToImportedEntriesByIDOrName() throws {
        let pack = PackLocation(system: .pathfinder, folder: "spells", linkName: "spells-srd", documentType: "Item",
                                directory: URL(fileURLWithPath: "/"))
        let document = SourceDocument(pack: pack, json: .object(["_id": .string("abc"), "name": .string("Heal")]),
                                      category: .spells)
        let enricher = enricher(documents: [document])
        #expect(enricher.enrich("@UUID[Compendium.pf2e.spells-srd.Item.abc]")
                == "<a href=\"entry:Compendium.pf2e.spells-srd.Item.abc\">Heal</a>")
        #expect(enricher.enrich("@UUID[Compendium.pf2e.spells-srd.Item.heal]{healing}")
                == "<a href=\"entry:Compendium.pf2e.spells-srd.Item.abc\">healing</a>")
        #expect(enricher.enrich("@UUID[Compendium.pf2e.spell-effects.Item.Effect: Heal]") == "Heal")
        #expect(enricher.enrich("@UUID[Compendium.pf2e.spells-srd.Item.Harm]") == "Harm")
        #expect(enricher.unresolvedLinks == ["Compendium.pf2e.spells-srd.Item.Harm": 1])
        #expect(LinkIndex(documents: [document]).entryID(forLink: "Item.abc") == nil)
    }
}
