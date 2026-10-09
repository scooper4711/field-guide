import Foundation
import Testing
@testable import CompendiumImport

@Suite struct ImageTests {
    @Test func resolvesFoundryPaths() {
        let paths = FoundryPaths(repository: URL(fileURLWithPath: "/r"), appPublic: URL(fileURLWithPath: "/a"),
                                 data: URL(fileURLWithPath: "/d"))
        #expect(paths.file(for: "systems/sf2e/icons/x.webp")?.path == "/r/static/icons/x.webp")
        #expect(paths.file(for: "icons/svg/a%20b.svg")?.path == "/a/icons/svg/a b.svg")
        #expect(paths.file(for: "modules/m/x.webp")?.path == "/d/modules/m/x.webp")
        #expect(paths.file(for: "https://example.com/x.webp") == nil && paths.file(for: "") == nil)
    }

    @Test func copiesIconsOnceAndScalesArt() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let images = ImageCollector(paths: repository.paths, output: repository.output)
        #expect(images.icon("icons/weapons/sword.webp") == "icons/weapons/sword.webp")
        #expect(images.icon("icons/weapons/sword.webp") == "icons/weapons/sword.webp")
        #expect(images.icon("systems/pf2e/icons/default.svg").isEmpty && images.icon("").isEmpty)
        #expect(images.icon("icons/none.webp").isEmpty && images.missing == ["icons/none.webp": 1])
        let art = repository.combatPad.appendingPathComponent("Art/goblin.png")
        guard ArtScaler.tool != nil else { return }
        let stored = images.art(art, key: "pf2e.pack.goblin")
        #expect(stored == "art/pf2e/pack/goblin.webp")
        let size = try #require(ArtScaler.pixelSize(of: repository.output.appendingPathComponent(stored)))
        #expect(size.width == ImageCollector.maximumArtSize && abs(size.height - 341) <= 1)
        #expect(images.art(art, key: "pf2e.pack.goblin") == stored)
        #expect(images.art(repository.root.appendingPathComponent("none.png"), key: "pf2e.pack.none").isEmpty)
    }

    @Test func artComesFromCombatPadThenTheModules() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let art = ArtSource(combatPadGenerated: repository.combatPad, foundryData: repository.data)
        #expect(art.count == 2)
        #expect(art.art(for: "pf2e.pathfinder-monster-core.goblin1")?.lastPathComponent == "goblin.png")
        #expect(art.art(for: "pf2e.hazards.trap1")?.lastPathComponent == "trap.png")
        let empty = ArtSource(combatPadGenerated: repository.root, foundryData: repository.root)
        #expect(empty.art(for: "pf2e.pathfinder-monster-core.goblin1") == nil)
        #expect(ArtSource(files: [:]).art(for: "x") == nil)
    }
}
