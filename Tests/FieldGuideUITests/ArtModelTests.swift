import FieldGuideKit
import Foundation
import Testing
@testable import FieldGuideUI

@Suite("Creature cards, and creature and item art")
@MainActor
struct ArtModelTests {
    @Test("A creature page's id gives its bestiary key; other pages give none", arguments: [
        ("Compendium.pf2e.pathfinder-bestiary.Actor.X03vq", "pf2e.pathfinder-bestiary.X03vq"),
        ("Compendium.sf2e.alien-core.Actor.abc", "sf2e.alien-core.abc"),
        ("Compendium.pf2e.spells-srd.Item.abc", nil), ("trait", nil)
    ])
    func creatureKeys(id: String, key: String?) {
        #expect(CreatureView.creatureKey(ofEntry: id) == key)
    }

    @Test("Without imported creatures or art, there are no cards, pictures or missing PDFs")
    func emptyData() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NoData-\(UUID())")
        let model = ArtModel(data: DataLocation(folder: folder), store: nil)
        #expect(model.creature("pf2e.pack.goblin") == nil)
        #expect(await model.picture(forCreature: "pf2e.pack.goblin", maxPixels: 64) == nil)
        #expect(await model.png(forCreature: "pf2e.pack.goblin", maxPixels: 64) == nil)
        #expect(model.missingSources(forCreature: "pf2e.pack.goblin").isEmpty)
        let potion = ItemArtPath(system: .pathfinder, name: "Healing Potion", fallback: "")
        #expect(await model.picture(forItem: potion, maxPixels: 64) == nil)
        #expect(await model.png(forItem: potion, maxPixels: 64) == nil)
        await model.refresh(addingNew: true)
        #expect(model.catalog.art.isEmpty && model.progress == nil)
    }
}
