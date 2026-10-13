import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct FormattingTests {
    @Test func formatsPricesBulkAndFrequencies() {
        #expect(Formatting.price(.object(["value": .object(["pp": .number(1),
                                                            "gp": .number(1500)])])) == "1 pp, \(1500.formatted()) gp")
        #expect(Formatting.bulk(.number(0)) == "—" && Formatting.bulk(.number(0.1)) == "L"
            && Formatting.bulk(.number(2)) == "2")
        #expect(Formatting.frequency(.object(["max": .number(2), "per": .string("day")])) == "twice per day")
        #expect(Formatting.frequency(.object(["max": .number(3), "per": .string("turn")])) == "3 times per turn")
        #expect(Formatting.frequency(.object([:])).isEmpty)
    }

    @Test func namesActionsAndCastingTimes() {
        #expect(Formatting.actionTypeName(type: "action", count: 3) == "Three Actions")
        #expect(Formatting.actionTypeName(type: "free", count: nil) == "Free Action")
        #expect(Formatting.actionTypeName(type: "passive", count: nil) == "Passive")
        #expect(Formatting.actionGlyph(type: "free", count: nil) == "<span class=\"action-glyph\">F</span>")
        #expect(Formatting.actionGlyph(type: "passive", count: nil).isEmpty)
        #expect(Formatting.castingTimeName("reaction") == "Reaction"
            && Formatting.castingTimeName("free") == "Free Action")
        #expect(Formatting.castingTimeName("1") == "One Action" && Formatting.castingTimeName("3") == "Three Actions")
        #expect(Formatting.castingTimeName("10 minutes") == "10 minutes" && Formatting.castingTimeName("").isEmpty)
        #expect(Formatting.time("1 to 3") == "<span class=\"action-glyph\">1 - 3</span>")
        #expect(HTML.actionGlyph("odd") == "odd" && Words.title("low-light-vision") == "Low-light Vision")
        #expect(FacetExtractor.featCategory("pfsboon") == "PFS Boon" && FacetExtractor.itemType("ammo") == "Ammunition")
    }

    @Test func aDeitysSubtitleIsItsKind() {
        func subtitle(_ system: [String: Any]) -> String {
            let document = IconFixture.document("d1", "Gods", type: "deity", category: .deities, system: system)
            return FacetExtractor.facets(of: document, traitLabels: []).subtitle
        }
        #expect(subtitle(["category": "pantheon"]) == "Pantheon" && subtitle(["category": "deity"]) == "Deity")
        #expect(subtitle([:]) == "Deity")
    }

    @Test func plainTextDropsTagsAndEntities() {
        #expect(HTML.plainText("<p>A &amp; B</p>\n<p>C&nbsp;&lt;D&gt;</p>") == "A & B C <D>")
        #expect(HTML.imageURL("icons/a b.webp") == "fieldguide:///images/icons/a%20b.webp")
    }

    @Test func settingAPathCreatesObjects() {
        let json = JSONValue.object(["a": .number(1)]).setting("b.c", to: .string("x"))
        #expect(json[path: "b.c"].string == "x" && json["a"].int == 1)
        #expect(JSONValue.null.setting("", to: .bool(true)) == .bool(true))
    }

    @Test func traitLabelsFallBackToWords() {
        let glossary = TraitGlossary()
        #expect(glossary.label(of: "two-hand-d8", in: .pathfinder) == "Two Hand D8")
        #expect(glossary.description(of: "two-hand-d8", in: .pathfinder) == nil)
        #expect(TraitGlossary.descriptionKeys(in: "const fooDescriptions = {\n  a: \"PF2E.A\",\n};") == ["a": "PF2E.A"])
    }
}
