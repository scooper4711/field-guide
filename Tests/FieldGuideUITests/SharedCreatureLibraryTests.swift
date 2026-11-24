import Bestiary
import CreatureArt
import FieldGuideKit
import Foundation
import SharedLibraries
import Testing
@testable import FieldGuideUI

@Suite("Custom creatures and art from the shared libraries")
@MainActor
struct SharedCreatureLibraryTests {
    private let data = DataLocation(folder: FileManager.default.temporaryDirectory
        .appendingPathComponent("NoData-\(UUID())"))

    @Test("Only creatures with a stat block are read, with the row's name and size over the record's")
    func readsCreaturesWithStatBlocks() throws {
        let fixture = try SharedLibraryFixture()
        let id = try fixture.addCreature(SharedLibraryFixture.creature("Goblin Boss"), rowName: "Grizzik",
                                         size: .tiny)
        try fixture.addPawn(named: "Pawn Only")
        let contents = try CreatureLibraryContents(reading: fixture.library)
        let key = "custom.\(id.uuidString)"
        #expect(contents.creatures.keys.sorted() == [key])
        #expect(contents.creatures[key]?.name == "Grizzik")
        #expect(contents.creatures[key]?.traits.size == "Tiny")
        #expect(contents.creatures[key]?.key == key)
    }

    @Test("A record this version can't read is left out")
    func unreadableRecord() throws {
        let row = CustomCreatureRecord(id: UUID(), name: "Odd", campaignID: nil, sharedVersion: nil,
                                       record: Data("not json".utf8))
        #expect(CreatureLibraryContents.creature(from: row) == nil)
    }

    /// A custom creature of a game and kind, and the list entry it gives.
    struct SummaryCase: Sendable {
        var game: Game
        var kind: CreatureKind
        var system: GameSystem
        var category: EntryCategory
        var subtitle: String
    }

    @Test("Custom creatures list in the Bestiary, complex hazards in Hazards, each under its game", arguments: [
        SummaryCase(game: .pathfinder, kind: .creature, system: .pathfinder, category: .bestiary,
                    subtitle: "Creature 3"),
        SummaryCase(game: .starfinder, kind: .hazard, system: .starfinder, category: .hazards, subtitle: "Hazard 3")
    ])
    func summaries(of example: SummaryCase) {
        var creature = SharedLibraryFixture.creature("Trap", game: example.game, kind: example.kind)
        creature.key = "custom.abc"
        let summary = CreatureLibraryContents.summary(of: creature)
        #expect(summary.id == "custom.abc" && summary.system == example.system)
        #expect(summary.category == example.category && summary.subtitle == example.subtitle)
        #expect(summary.level == 3 && summary.image == "creature/custom.abc")
        #expect(summary.values(of: .rarity) == ["Uncommon"])
        #expect(summary.values(of: .size) == (example.kind == .hazard ? [] : ["Medium"]))
        #expect(summary.values(of: .complexity) == (example.kind == .hazard ? ["Complex"] : []))
        #expect(summary.values(of: .traits) == ["Goblin", "Humanoid"] && summary.values(of: .source) == ["Custom"])
    }

    @Test("Empty values aren't filter options")
    func emptyFacets() {
        var creature = SharedLibraryFixture.creature("Blob")
        creature.traits = TraitLine(rarity: "", size: "", traits: [])
        let summary = CreatureLibraryContents.summary(of: creature)
        #expect(Set(summary.facets.keys) == [.source])
    }

    @Test("A custom creature's page key is its own")
    func customCreatureKey() {
        #expect(CreatureView.creatureKey(ofEntry: "custom.ABC") == "custom.ABC")
    }

    @Test("The model gives custom creatures' cards, and art chosen in another app instead of art matched by name")
    func chosenArt() async throws {
        let fixture = try SharedLibraryFixture()
        let id = try fixture.addCreature(SharedLibraryFixture.creature("Grizzik"))
        let key = "custom.\(id.uuidString)"
        try fixture.addArt(for: key, pixels: 200)
        try fixture.addArt(for: "pf2e.pack.goblin", pixels: 50)
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        #expect(model.customCreatures.map(\.id) == [key])
        #expect(model.creature(key)?.name == "Grizzik")
        #expect(model.creature("custom.\(UUID().uuidString)") == nil)
        #expect(await model.picture(forCreature: key, maxPixels: 64)?.width == 64)
        #expect(await model.picture(forCreature: "pf2e.pack.goblin", maxPixels: 64)?.width == 50)
        #expect(model.missingSources(forCreature: key).isEmpty)
    }

    @Test("Chosen custom art whose image is gone falls back to the art matched by name")
    func missingChosenArt() async throws {
        let fixture = try SharedLibraryFixture()
        try fixture.library.setCreatureArt(.custom(UUID()), for: "pf2e.pack.goblin")
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        #expect(await model.picture(forCreature: "pf2e.pack.goblin", maxPixels: 64) == nil)
        #expect(model.missingSources(forCreature: "pf2e.pack.goblin").isEmpty)
    }

    @Test("The art tag changes when another app chooses different art, so views draw it again")
    func artChoiceTag() throws {
        let fixture = try SharedLibraryFixture()
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        let before = model.artChoiceTag(forCreature: "pf2e.pack.goblin")
        try fixture.addArt(for: "pf2e.pack.goblin")
        model.followSharedLibrary()
        let chosen = model.artChoiceTag(forCreature: "pf2e.pack.goblin")
        #expect(before == "matched" && chosen != before)
        try fixture.addArt(for: "pf2e.pack.goblin")
        model.followSharedLibrary()
        #expect(model.artChoiceTag(forCreature: "pf2e.pack.goblin") != chosen)
    }

    @Test("A change made between the first read and following the library isn't missed")
    func changeBeforeFollowing() throws {
        let fixture = try SharedLibraryFixture()
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        try fixture.addCreature(SharedLibraryFixture.creature("Grizzik"))
        model.startFollowingSharedLibrary()
        model.followSharedLibrary()
        #expect(model.customCreatures.map(\.name) == ["Grizzik"])
    }

    @Test("Art chosen from the art library is drawn by the art store; art it doesn't have draws nothing")
    func chosenLibraryArt() async throws {
        let fixture = try SharedLibraryFixture()
        try fixture.library.setCreatureArt(.library(UUID()), for: "pf2e.pack.goblin")
        let store = try CreatureArtStore(folder: fixture.folder.appendingPathComponent("Own"))
        for model in [ArtModel(data: data, store: nil, sharedLibrary: fixture.library),
                      ArtModel(data: data, store: store, sharedLibrary: fixture.library)] {
            #expect(await model.picture(forCreature: "pf2e.pack.goblin", maxPixels: 64) == nil)
        }
    }

    @Test("A custom creature without chosen art is matched by name, and has none in an empty art library")
    func customCreatureMatchedByName() async throws {
        let fixture = try SharedLibraryFixture()
        let key = "custom.\(try fixture.addCreature(SharedLibraryFixture.creature("Grizzik")).uuidString)"
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        #expect(model.missingSources(forCreature: key).isEmpty)
        #expect(await model.picture(forCreature: key, maxPixels: 64) == nil)
    }

    @Test("Another app's change to the creature library is read when the library says it changed")
    func followsChanges() throws {
        let fixture = try SharedLibraryFixture()
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        model.startFollowingSharedLibrary()
        #expect(model.customCreatures.isEmpty)
        try fixture.addCreature(SharedLibraryFixture.creature("Grizzik"))
        model.followSharedLibrary()
        #expect(model.customCreatures.map(\.name) == ["Grizzik"])
    }

    @Test("In the background the shared database stays closed; back in the foreground, changes made meanwhile show")
    func closesInTheBackground() async throws {
        let fixture = try SharedLibraryFixture()
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        model.startFollowingSharedLibrary()
        await model.closeSharedLibrary()
        try fixture.addCreature(SharedLibraryFixture.creature("Grizzik"))
        model.followSharedLibrary()
        #expect(model.customCreatures.isEmpty)
        model.resumeSharedLibrary()
        #expect(model.customCreatures.map(\.name) == ["Grizzik"])
        model.resumeSharedLibrary()
        #expect(model.customCreatures.count == 1)
    }

    @Test("Another app's change to the art library refreshes the art catalog")
    func artChanges() async throws {
        let fixture = try SharedLibraryFixture()
        let store = try CreatureArtStore(sharedLibraryIn: fixture.folder, app: .fieldGuide)
        let model = ArtModel(data: data, store: store, sharedLibrary: fixture.library)
        try fixture.library.watch(fixture.folder)
        model.followSharedLibrary()
        model.followSharedLibrary()
        for _ in 0..<100 where model.catalog.watchedFolders.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.catalog.watchedFolders.count == 1)
    }

    @Test("Art chosen from the art library needs its PDF when that is missing; art the library lacks needs none")
    func chosenLibraryArtMissingSources() throws {
        let fixture = try SharedLibraryFixture()
        let missing = UUID()
        try fixture.library.setCreatureArt(.library(missing), for: "pf2e.pack.goblin")
        try fixture.library.setCreatureArt(.library(UUID()), for: "pf2e.pack.orc")
        let model = ArtModel(data: data, store: nil, sharedLibrary: fixture.library)
        model.catalog = ArtCatalog(art: [LibraryArt(id: missing, name: "Goblin", game: .pathfinder,
                                                    isRemastered: true, isToken: false, isAvailable: false,
                                                    sourceTitles: ["Monster Core Pawn Box"])])
        #expect(model.missingSources(forCreature: "pf2e.pack.goblin") == ["Monster Core Pawn Box"])
        #expect(model.missingSources(forCreature: "pf2e.pack.orc").isEmpty)
    }
}

@Suite("Opening the shared libraries at launch")
struct SharedLibraryOpeningTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("Opening-\(UUID())")

    @Test("Outside the App Group the app keeps its own art library and has no creature library")
    func outsideTheGroup() {
        let opening = SharedLibraryOpening.open(groupContainer: nil, ownFolder: root.appendingPathComponent("Own"))
        #expect(opening.art != nil && opening.creatures == nil && opening.failure == nil)
    }

    @Test("In the App Group the app moves its own art library into the shared one, once")
    func movesIn() throws {
        let group = root.appendingPathComponent("Group")
        let opening = SharedLibraryOpening.open(groupContainer: group, ownFolder: root.appendingPathComponent("Own"))
        let library = try #require(opening.creatures)
        #expect(opening.art != nil && opening.failure == nil)
        #expect(try library.hasMovedIn(.fieldGuide))
        #expect(library.folder.lastPathComponent == SharedLibrary.groupFolderName)
        #expect(SharedLibraryOpening.open(groupContainer: group, ownFolder: root).failure == nil)
    }

    @Test("When the move fails the app keeps its own art library, says why, and still has the creature library")
    func moveFails() throws {
        let own = root.appendingPathComponent("Own")
        try FileManager.default.createDirectory(at: own, withIntermediateDirectories: true)
        try Data("not a library".utf8).write(to: own.appendingPathComponent("art-library.json"))
        let opening = SharedLibraryOpening.open(groupContainer: root.appendingPathComponent("Group"), ownFolder: own)
        let library = try #require(opening.creatures)
        #expect(try !library.hasMovedIn(.fieldGuide))
        #expect(opening.failure?.contains("Field Guide is using its own") == true)
    }

    @Test("When the shared library can't be opened the app keeps its own and says why")
    func failure() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("A file")
        try Data().write(to: file)
        let opening = SharedLibraryOpening.open(groupContainer: file, ownFolder: root.appendingPathComponent("Own"))
        #expect(opening.art != nil && opening.creatures == nil)
        #expect(opening.failure?.contains("Field Guide is using its own") == true)
    }
}
