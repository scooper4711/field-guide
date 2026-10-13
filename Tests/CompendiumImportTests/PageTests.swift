import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct PageTests {
    @Test func spellPagesShowTheirDetailsAndEnrichedText() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let html = try imported.page("Compendium.pf2e.spells-srd.Item.fb1")
        #expect(html.contains("<h1>Fireball <span class=\"action-glyph\">\u{E901}</span></h1>"))
        #expect(html.contains("<strong>Traditions</strong> arcane, primal"))
        #expect(html.contains("<strong>Cost</strong> a pinch of sulfur")
            && html.contains("<strong>Area</strong> 20-foot burst"))
        #expect(html.contains("<strong>Defense</strong> basic Reflex"))
        #expect(html.contains("20-foot burst of fire deals <span class=\"damage\">6d6 fire</span>"))
        #expect(html.contains("<span class=\"check\">DC 20 basic Reflex save</span>"))
        #expect(html.contains("<a href=\"entry:Compendium.pf2e.conditionitems.Item.fr1\">Scared</a>"))
        #expect(html.contains("for 1d4 rounds; see x and odd. Hello from the lang file"))
        #expect(html.contains("<a class=\"trait\" href=\"trait:fire\">Fire</a> <span " +
            "class=\"trait\">Manipulate</span>"))
        #expect(html.contains("<footer class=\"source\">Player Core</footer>"))
        let light = try imported.page("Compendium.pf2e.spells-srd.Item.li1")
        #expect(light.contains("<strong>Duration</strong> sustained up to 1 hour")
            && light.contains("<strong>Defense</strong> Will"))
        #expect(light.contains("<strong>Cast</strong> 1 minute") && light.contains("trait rarity-uncommon"))
    }

    @Test func itemPagesShowPriceBulkAndTheirNumbers() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let sword = try imported.page("Compendium.pf2e.equipment-srd.Item.ls1")
        for line in ["<strong>Price</strong> 1 gp, 5 sp", "<strong>Usage</strong> held in one hand",
                     "<strong>Bulk</strong> 1",
                     "<strong>Damage</strong> 1d8 slashing", "<strong>Group</strong> Sword", "<strong>Range</strong> " +
                         "30 feet",
                     "<strong>Reload</strong> 1", "Deadly d10"] {
            #expect(sword.contains(line), "\(line)")
        }
        let armor = try imported.page("Compendium.pf2e.equipment-srd.Item.la1")
        for line in ["<strong>Bulk</strong> L", "<strong>AC Bonus</strong> +1", "<strong>Dex Cap</strong> +4",
                     "<strong>Strength</strong> +10", "<strong>Check Penalty</strong> –1", "<strong>Speed " +
                         "Penalty</strong> -5 feet"] {
            #expect(armor.contains(line), "\(line)")
        }
        let shield = try imported.page("Compendium.pf2e.equipment-srd.Item.ss1")
        #expect(shield.contains("<strong>Bulk</strong> —") && shield.contains("<strong>HP</strong> 20 (BT 10)"))
        #expect(shield.contains("<strong>Price</strong> 2 sp"))
        let potion = try imported.page("Compendium.pf2e.equipment-srd.Item.po1")
        #expect(potion.contains("<strong>Price</strong> 4 cp (for 10)") && !potion.contains("Bulk"))
    }

    @Test func featsActionsAndCharacterOptions() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let feat = try imported.page("Compendium.pf2e.feats-srd.Item.pa1")
        #expect(feat.contains("<strong>Prerequisites</strong> trained in Athletics"))
        #expect(feat.contains("<strong>Frequency</strong> once per 10 minutes")
            && feat.contains("<strong>Trigger</strong> You see a foe"))
        #expect(feat.contains("<strong>Requirements</strong> You wield a weapon"))
        let fighter = try imported.page("Compendium.pf2e.classes.Item.fi1")
        #expect(fighter.contains("<strong>Key Attribute</strong> Strength or Dexterity"))
        #expect(fighter.contains("<strong>1</strong> <a href=\"entry:Compendium.pf2e.feats-srd.Item.pa1\">Power " +
            "Attack</a>, <strong>3</strong> Bravery"))
        let elf = try imported.page("Compendium.pf2e.ancestries.Item.el1")
        for line in ["<strong>Hit Points</strong> 6", "<strong>Attribute Boosts</strong> Dexterity, Intelligence, Free",
                     "<strong>Attribute Flaw</strong> Constitution", "<strong>Languages</strong> Common, Elven",
                     "<strong>Vision</strong> low-light vision", "<strong>Size</strong> Medium"] {
            #expect(elf.contains(line), "\(line)")
        }
        #expect(try imported.page("Compendium.pf2e.heritages.Item.ae1").contains("<a " +
            "href=\"entry:Compendium.pf2e.ancestries.Item.el1\">Elf</a>"))
        #expect(try imported.page("Compendium.pf2e.heritages.Item.ve1").contains("<strong>Ancestry</strong> Versatile"))
        let acolyte = try imported.page("Compendium.pf2e.backgrounds.Item.ac1")
        #expect(acolyte.contains("<strong>Attribute Boosts</strong> Intelligence or Wisdom"))
        #expect(acolyte.contains("<strong>Trained Skills</strong> Religion, Scribing Lore"))
        #expect(try imported.page("Compendium.pf2e.conditionitems.Item.fr1").contains("You're scared."))
    }

    @Test func deityPagesShowTheirDetailsAndKind() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let abadar = try imported.page("Compendium.pf2e.deities.Item.ab1")
        for line in ["<strong>Sanctification</strong> can be holy", "<strong>Divine Attribute</strong> Constitution",
                     "<strong>Favored Weapon</strong> crossbow", "<strong>Alternate Domains</strong> wealth",
                     "<strong>1</strong> <a href=\"entry:Compendium.pf2e.spells-srd.Item.li1\">Light</a>"] {
            #expect(abadar.contains(line), "\(line)")
        }
        // The deity's kind is its subtitle, not a line of its details.
        #expect(abadar.contains("<p class=\"subtitle\">Deity</p>") && !abadar.contains("EntryCategory"))
    }
}
