import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

/// Imports the fake repository once per test and opens the catalog it wrote.
struct Imported {
    let repository: FakeRepository
    let report: ImportReport
    let catalog: Catalog

    init() throws {
        repository = try FakeRepository()
        let options = ImportOptions(paths: repository.paths, combatPadGenerated: repository.combatPad,
                                    output: repository.output)
        report = try CompendiumImporter(options: options).run()
        catalog = try Catalog(url: repository.output.appendingPathComponent("catalog.sqlite"))
    }

    func page(_ id: String) throws -> String { try #require(try catalog.page(of: id)).html }
}

@Suite struct ImporterTests {
    @Test func importsEachSystemsCategoriesAndSkipsEffects() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        #expect(try imported.catalog.categories(in: .pathfinder) == [
            .actions, .bestiary, .equipment, .feats, .hazards, .spells, .conditions, .ancestries, .heritages,
            .backgrounds, .classes, .deities
        ])
        #expect(try imported.catalog.categories(in: .starfinder) == [.bestiary, .spells, .conditions])
        #expect(imported.report.total == 22)
        #expect(imported.report.summary.hasPrefix("Imported 22 entries"))
        let report = try String(contentsOf: imported.repository.output.appendingPathComponent("import-report.md"),
                                encoding: .utf8)
        #expect(report.contains("- Pathfinder Equipment: 5") && report.contains("Wrong: 2"))
    }

    @Test func starfinderGetsTheListedPathfinderCopiesWithItsPublication() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let spells = try imported.catalog.summaries(of: .spells, in: .starfinder)
        #expect(spells.map(\.name) == ["Fireball"])
        #expect(spells.first?.id == "Compendium.sf2e.spells.Item.fb1")
        #expect(spells.first?.values(of: .source) == ["Starfinder Player Core"])
        let conditions = try imported.catalog.summaries(of: .conditions, in: .starfinder).map(\.name)
        #expect(conditions == ["Frightened", "Glitching"])
    }

    @Test func summariesCarryLevelsSubtitlesImagesAndFacets() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let spells = try imported.catalog.summaries(of: .spells, in: .pathfinder)
        let fireball = try #require(spells.first { $0.name == "Fireball" })
        #expect(fireball.level == 3 && fireball.subtitle == "Spell 3")
        #expect(fireball.image == "systems/pf2e/icons/spells/fireball.webp")
        #expect(fireball.values(of: .tradition) == ["Arcane", "Primal"] && fireball.values(of: .rank) == ["3"])
        #expect(fireball.values(of: .castingTime) == ["Two Actions"] && fireball.values(of: .traits) == ["Fire",
            "Manipulate"])
        let light = try #require(spells.first { $0.name == "Light" })
        #expect(light.subtitle == "Focus 1" && light.image.isEmpty && light.values(of: .rank) == ["Cantrip"])
        #expect(light.values(of: .spellKind) == ["Cantrip", "Focus", "Ritual"]
            && light.values(of: .rarity) == ["Uncommon"])
        let creature = try #require(try imported.catalog.summaries(of: .bestiary, in: .pathfinder).first)
        #expect(creature.subtitle == "Creature -1" && creature.values(of: .size) == ["Small"])
        #expect(creature.image == "art/pf2e/pathfinder-monster-core/goblin1.webp" || ArtScaler.tool == nil)
        let hazard = try #require(try imported.catalog.summaries(of: .hazards, in: .pathfinder).first)
        #expect(hazard.values(of: .complexity) == ["Complex"] && hazard.subtitle == "Hazard 2")
        let equipment = try imported.catalog.summaries(of: .equipment, in: .pathfinder)
        #expect(Set(equipment.flatMap { $0.values(of: .itemType) }) == ["Weapon", "Armor", "Shield", "Consumable",
                                                                        "Container"])
        let grab = try #require(try imported.catalog.summaries(of: .actions, in: .pathfinder).first)
        #expect(grab.level == nil && grab.subtitle == "Reaction" && grab.values(of: .actionType) == ["Reaction"])
        let feat = try #require(try imported.catalog.summaries(of: .feats, in: .pathfinder).first)
        #expect(feat.values(of: .featCategory) == ["Class Feature"] && feat.subtitle == "Class Feature 1")
    }

    @Test func searchesTextAndTraits() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let fireballID = "Compendium.pf2e.spells-srd.Item.fb1"
        #expect(try imported.catalog.search("sulfur", in: .spells, of: .pathfinder) == [fireballID])
        #expect(try imported.catalog.search("  ", in: .spells, of: .pathfinder).isEmpty)
        #expect(try imported.catalog.search("sulfur", in: .feats, of: .pathfinder).isEmpty)
        let fire = try #require(try imported.catalog.trait("fire", in: .pathfinder))
        #expect(fire.name == "Fire" && fire.html.contains("<p>Effects with this trait deal fire damage.</p>"))
        #expect(try imported.catalog.trait("fire", in: .starfinder)?.name == "Plasma")
        #expect(try imported.catalog.trait("deadly-d10", in: .pathfinder)?.html.contains("On a critical hit") == true)
        #expect(try imported.catalog.trait("manipulate", in: .pathfinder) == nil)
        #expect(try imported.catalog.page(of: "nothing") == nil)
    }

    @Test func copiesTheEntryFontsAndImages() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        let fontFolder = imported.repository.output.appendingPathComponent("Fonts")
        let fonts = try FileManager.default.contentsOfDirectory(atPath: fontFolder.path)
        #expect(Set(fonts) == ["pathfinder-2e-actions.woff2", "gelasio-regular.woff2"])
        let images = imported.repository.output.appendingPathComponent("Images")
        #expect(FileManager.default.fileExists(atPath: images.appendingPathComponent("icons/weapons/sword.webp").path))
        #expect(imported.report.missingImages["icons/missing.webp"] == 1)
    }
}
