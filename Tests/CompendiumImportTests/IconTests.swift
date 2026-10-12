import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct DifferenceHashTests {
    @Test func samePictureAtAnotherSizeIsNear() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let sword = fixture.packs.appendingPathComponent("Weapons/sword.png")
        let large = try #require(RexardIcons.hashes(of: sword).first)
        let small = ImageHashing.hash(of: try #require(ImageHashing.gray(
            of: fixture.appPublic.appendingPathComponent("icons/weapons/sword.webp"), background: 1)))
        let other = try #require(RexardIcons.hashes(of: fixture.packs.appendingPathComponent("Potions/red.png")).first)
        #expect(large.distance(to: small) <= 2)
        #expect(large.distance(to: other) > 200)
        #expect(RexardIcons.hashes(of: fixture.packs.appendingPathComponent("Misc/broken.png")).isEmpty)
    }

    @Test func readsBackItsHex() {
        let hash = DifferenceHash(words: [1, 2, 3, .max])
        #expect(DifferenceHash(hex: hash.hex) == hash)
        #expect(DifferenceHash(hex: "12") == nil)
        #expect(DifferenceHash(hex: String(repeating: "z", count: 64)) == nil)
    }
}

@Suite struct RexardIconsTests {
    @Test func matchesAndCachesThePacksPictures() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let icons = RexardIcons.load(folder: fixture.packs, cache: fixture.cache)
        #expect(icons.files == ["Misc/stripes.png", "Potions/red.png", "Weapons/sword.png"])
        let match = try #require(icons.bestMatch(for: fixture.appPublic.appendingPathComponent(
            "icons/weapons/sword.webp")))
        #expect(match.file == "Weapons/sword.png" && match.distance <= 2)
        #expect(icons.bestMatch(for: fixture.root.appendingPathComponent("none.webp")) == nil)
        // Unreadable pictures are cached too, without hashes, and files that are gone are dropped.
        #expect(HashCache.read(from: fixture.cache).files.count == 4)
        try FileManager.default.removeItem(at: fixture.packs.appendingPathComponent("Misc/stripes.png"))
        #expect(RexardIcons.load(folder: fixture.packs, cache: fixture.cache).files.count == 2)
        #expect(HashCache.read(from: fixture.root).files.isEmpty)
    }
}

@Suite struct IconMapTests {
    @Test func picksOverridesMatchesBaseItemsAndLearnedIcons() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let potion: [String: Any] = ["category": "potion", "traits": ["value": ["consumable", "potion"]]]
        let documents = [
            IconFixture.document("ls", "Longsword", type: "weapon", img: "icons/weapons/sword.webp",
                                 system: ["baseItem": "longsword", "group": "sword"]),
            IconFixture.document("fl", "Flaming Longsword", type: "weapon", img: "systems/pf2e/icons/fl.webp",
                                 system: ["baseItem": "longsword"]),
            IconFixture.document("p1", "Healing Potion", type: "consumable", img: "icons/potion.webp", system: potion),
            IconFixture.document("p2", "Elixir", type: "consumable", img: "icons/potion.webp", system: potion),
            IconFixture.document("p3", "Antidote", type: "consumable", img: "icons/potion.webp", system: potion),
            IconFixture.document("p4", "Paizo Potion", type: "consumable", img: "systems/pf2e/p.webp", system: potion),
            IconFixture.document("ft", "Power Attack", type: "feat", img: "icons/feats/other.webp", category: .feats),
            IconFixture.document("gb", "Goblin", type: "npc", img: "icons/weapons/sword.webp", category: .bestiary)
        ]
        let map = IconMap(documents: documents, sources: fixture.sources(overrides: [
            "icons/potion.webp": "Potions/red.png", documents[6].uuid: "Misc/stripes.png"
        ]))
        let choices = documents.map { map.choice(for: $0) }
        #expect(choices.map { $0?.file } == ["Weapons/sword.png", "Weapons/sword.png", "Potions/red.png",
                                             "Potions/red.png", "Potions/red.png", "Potions/red.png",
                                             "Misc/stripes.png", nil])
        #expect(choices.map { $0?.rule } == [.match, .baseItem, .override, .override, .override, .learned,
                                             .override, nil])
        #expect(map.counts == [.match: 1, .baseItem: 1, .override: 4, .learned: 1] && map.unresolved.isEmpty)
        let table = map.table(of: documents).split(separator: "\n")
        #expect(table.count == 8 && table[1].contains("\tWeapons/sword.png\tmatch\t"))
    }

    @Test func leavesEntriesWithoutIconsWhenNothingFits() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let feat = IconFixture.document("ft", "Power Attack", type: "feat", img: "systems/pf2e/x.webp",
                                        category: .feats)
        let map = IconMap(documents: [feat], sources: fixture.sources())
        #expect(map.choice(for: feat) == nil && map.unresolved == ["systems/pf2e/x.webp": 1])
        let none = IconMap(documents: [feat], sources: IconSources(paths: fixture.paths, rexard: nil))
        #expect(none.choice(for: feat) == nil && none.unresolved.isEmpty)
    }

    @Test func learnsFromTheMostSpecificKeyWithEnoughEntries() {
        let spell = IconFixture.document("sp", "Fireball", type: "spell", category: .spells,
                                         system: ["traits": ["value": ["fire"], "traditions": ["arcane"]]])
        #expect(LearnedIcons.keys(of: spell) == [["pf2e.spells.trait:fire", "pf2e.spells.trait:arcane"]])
        let sword = IconFixture.document("ls", "Longsword", type: "weapon", system: ["group": "sword"])
        #expect(LearnedIcons.keys(of: sword) == [["pf2e.equipment.group:weapon.sword"],
                                                 ["pf2e.equipment.type:weapon"]])
    }

    @Test func learnsOnlyIconsTheEntriesShare() {
        func feat(_ id: String) -> SourceDocument {
            IconFixture.document(id, id, type: "feat", category: .feats, system: ["traits": ["value": ["fighter"]]])
        }
        let known = ["a", "b", "c"].map(feat)
        let unknown = feat("d")
        func choices(_ files: [String]) -> [String: IconMap.Choice] {
            Dictionary(uniqueKeysWithValues: zip(known, files).map {
                ($0.uuid, IconMap.Choice(file: $1, rule: .match))
            })
        }
        #expect(LearnedIcons(documents: known, choices: choices(["x", "y", "z"])).choice(for: unknown) == nil)
        let learned = LearnedIcons(documents: known, choices: choices(["x", "y", "y"])).choice(for: unknown)
        #expect(learned?.file == "y" && learned?.detail == "pf2e.feats.trait:fighter")
    }

    @Test func slugsNamesAsPF2EDoes() {
        #expect(IconMap.slug("Hand Crossbow") == "hand-crossbow")
        #expect(IconMap.slug("Alchemist's Fire (Lesser)") == "alchemists-fire-lesser")
    }

    @Test func readsOverrides() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let url = fixture.root.appendingPathComponent("icon-overrides.json")
        #expect(try IconSources.overrides(in: url).isEmpty)
        try Data(#"{"icons/a.webp": "Misc/stripes.png"}"#.utf8).write(to: url)
        #expect(try IconSources.overrides(in: url) == ["icons/a.webp": "Misc/stripes.png"])
    }
}
