import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct StatBlockTests {
    static let goblinLines = [
        "<strong>Perception</strong> +2; darkvision; scent (imprecise) 30 feet; smell 30 feet",
        "<strong>Languages</strong> Goblin, Common; telepathy",
        "<strong>Skills</strong> Acrobatics +5, Stealth +5, Goblin Lore +4",
        "<strong>Wis</strong> –1", "<strong>Items</strong> dogslicer, javelin (4)",
        "<strong>AC</strong> 16 (18 with shield); <strong>Fort</strong> +5, <strong>Ref</strong> +7, " +
            "<strong>Will</strong> +3; +1 vs. magic",
        "<strong>HP</strong> 6, regeneration 2", "<strong>Immunities</strong> fire",
        "<strong>Weaknesses</strong> cold iron 3 (except magic)",
        "<strong>Resistances</strong> physical 5 (except adamantine) (double resistance vs. critical hits)",
        "<strong>Speed</strong> 25 feet, climb 15 feet, ignores difficult terrain",
        "dogslicer +7 (agile), <strong>Damage</strong> 1d6+2 slashing plus 1d4 fire plus 1d6 persistent bleed " +
            "plus Grab plus knockdown",
        "<strong>Ranged</strong> <span class=\"action-glyph\">\u{E902}</span> javelin –1 (range increment 30 feet), " +
            "<strong>Damage</strong> 1d6 piercing",
        "spit +3 (range 10 feet)</p>",
        "<strong>Arcane Innate Spells</strong> DC 18, attack +10; <strong>3rd</strong> <a " +
            "href=\"entry:Compendium.pf2e.spells-srd.Item.fb1\">fireball (×3)</a>",
        "<strong>Cantrips (1st)</strong> light (at will); <strong>Constant (2nd)</strong> see invisibility",
        "<strong>Arcane Prepared Spells</strong> DC 20; <strong>3rd</strong> <a " +
            "href=\"entry:Compendium.pf2e.spells-srd.Item.fb1\">fireball</a> (×2); <strong>Cantrips " +
                "(2nd)</strong> light",
        "<strong>Goblin Scuttle</strong> <span class=\"action-glyph\">\u{E904}</span> (move)",
        "<hr><section class=\"description\"><p>Goblins fight in groups.</p>"
    ]

    @Test func creaturesShowTheirStatBlockInPaizoOrder() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let html = try imported.page("Compendium.pf2e.pathfinder-monster-core.Actor.goblin1")
        for line in Self.goblinLines { #expect(html.contains(line), "\(line)") }
        let order = ["Smell", "<strong>AC</strong>", "Goblin Scuttle", "<strong>Speed</strong>", "Melee", "Innate",
                     "Grab</strong>"]
        let positions = order.compactMap { html.range(of: $0)?.lowerBound }
        #expect(positions == positions.sorted() && positions.count == order.count)
    }

    @Test func hazardsShowStealthDisableDefensesAndRoutine() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let html = try imported.page("Compendium.pf2e.hazards.Actor.trap1")
        for line in ["<strong>Stealth</strong> DC 20 (trained)", "<strong>Description</strong> Darts fly.",
                     "<strong>Disable</strong> <span class=\"check\">DC 20 Thievery check</span> to jam it",
                     "<strong>AC</strong> 18; <strong>Fort</strong> +8", "<strong>Hardness</strong> 5; " +
                         "<strong>HP</strong> 20 (BT 10)",
                     "<strong>Routine</strong> Shoots.", "<strong>Dart</strong> <span " +
                         "class=\"action-glyph\">\u{E904}</span>"] {
            #expect(html.contains(line), "\(line)")
        }
        #expect(!html.contains("Ref") && !html.contains("Reset"))
        #expect(html.contains("src=\"fieldguide:///images/creature/pf2e.hazards.trap1\""))
        #expect(html.contains("onerror=\"this.remove()\""))
    }

    @Test func aBareCreatureStillReads() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let html = try imported.page("Compendium.sf2e.starfinder-society-bestiary.Actor.robot1")
        #expect(html.contains("<strong>Perception</strong> +5") && !html.contains("Languages")
            && !html.contains("<strong>Speed</strong>"))
        #expect(html.contains("<strong>HP</strong> 30") && !html.contains("class=\"description\""))
    }
}
