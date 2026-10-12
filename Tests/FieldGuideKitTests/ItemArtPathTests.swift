import Testing
@testable import FieldGuideKit

@Suite struct ItemArtPathTests {
    @Test func readsBackWhatItWrites() {
        let item = ItemArtPath(system: .pathfinder, name: "Bag of Holding (Type I/II)",
                               fallback: "rexard/Bags/bag 1.webp")
        #expect(item.path == "item/pf2e/Bag of Holding (Type I/II)?fallback=rexard/Bags/bag 1.webp")
        #expect(ItemArtPath(path: item.path) == item)
        #expect(ItemArtPath(path: "item/sf2e/Laser Pistol")?.fallback == "")
    }

    @Test func leavesOtherPathsAlone() {
        #expect(ItemArtPath(path: "creature/pf2e.pack.id") == nil)
        #expect(ItemArtPath(path: "item/dnd5e/Sword") == nil)
        #expect(ItemArtPath(path: "item/pf2e") == nil)
    }
}
