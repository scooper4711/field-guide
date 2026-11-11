import Foundation
import PDFKit
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct CreatureLoreStoreTests {
    typealias Fixture = PDFFixture

    static let monsterCore = Sourcebook(title: "Pathfinder Monster Core", supplies: [.creatureLore])
    static let bestiary = Sourcebook(title: "Pathfinder Bestiary", supplies: [.creatureLore])
    static let adventure = "Pathfinder #999: Test Adventure"
    static let list = SourcebookList(books: [monsterCore, bestiary], creatures: [
        "id.hydra": CreatureSource(name: "Hydra", book: monsterCore.title)
    ])
    static let warrior = EntryReference(id: "id.warrior", name: "Goblin Warrior", credited: bestiary.title)

    /// A bestiary page with one creature, its paragraph saying which book it is.
    static func writeBook(_ book: Sourcebook, saying text: String, in folder: URL) throws -> URL {
        let file = folder.appendingPathComponent("\(book.title).pdf")
        // Most of a book's text is body text, which tells the reader the headings apart.
        let introduction = (0..<4).map { line in
            Fixture.text("This book introduces many creatures of the world to the reader.", at: 60,
                         700 - CGFloat(line) * 12)
        }
        let pages = [introduction + [
            Fixture.text("Goblin Warrior", at: 60, 600, font: Fixture.bold, size: 13),
            Fixture.text(text, at: 60, 580),
            Fixture.text("GOBLIN WARRIOR CREATURE –1", at: 60, 560, font: Fixture.bold, size: 12),
            Fixture.text("Hydra", at: 60, 500, font: Fixture.bold, size: 13),
            Fixture.text("Hydras regrow heads.", at: 60, 480),
            Fixture.text("HYDRA CREATURE 6", at: 60, 460, font: Fixture.bold, size: 12)
        ]]
        try #require(PDFFixture(pages: pages).document()?.write(to: file) == true)
        return file
    }

    static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test(arguments: [true, false])
    func monsterCoreLoreWinsWhicheverIsReadFirst(monsterCoreFirst: Bool) async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let core = try Self.writeBook(Self.monsterCore, saying: "From Monster Core.", in: folder)
        let old = try Self.writeBook(Self.bestiary, saying: "From the Bestiary.", in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        for file in monsterCoreFirst ? [core, old] : [old, core] {
            _ = try await store.addFiles([file], subjects: LoreSubjects())
        }
        #expect(await store.lore(of: Self.warrior)?.paragraphs == ["From Monster Core."])
    }

    @Test func aBestiaryCreatureTakesItsNewEditionsLoreAndAnAdventureCreatureItsBestiarys() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let core = try Self.writeBook(Self.monsterCore, saying: "From Monster Core.", in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        #expect(await store.lore(of: Self.warrior) == nil)
        #expect(try await store.addFiles([core], subjects: LoreSubjects()) == [Self.monsterCore.title])
        #expect(await store.lore(of: Self.warrior)?.paragraphs == ["From Monster Core."])
        let hydra = EntryReference(id: "id.hydra", name: "Hooktongue Hydra", credited: Self.adventure)
        #expect(await store.lore(of: hydra)?.paragraphs == ["Hydras regrow heads."])
        let unknown = EntryReference(id: "id.other", name: "Goblin Warrior", credited: Self.adventure)
        #expect(await store.lore(of: unknown) == nil)
    }

    @Test func anAncestrysDetailsComeFromItsBookElseTheSample() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sample = SampleSourcebook.pathfinder
        let file = folder.appendingPathComponent("\(sample.title).pdf")
        try #require(sample.document()?.write(to: file) == true)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"),
                                  list: SourcebookList(books: [sample.book]))
        let elf = EntryReference(id: "Compendium.pf2e.ancestries.Item.elf", name: "Elf",
                                 credited: "Pathfinder Player Core")
        // Another game's ancestry with the name gets none of this sample's lore.
        let starfinderElf = EntryReference(id: "Compendium.sf2e.ancestries.Item.elf", name: "Elf",
                                           credited: "Starfinder Player Core")
        #expect(await store.details(of: elf) == nil)
        _ = try await store.addFiles([file], subjects: LoreSubjects(details: [elf, starfinderElf]))
        #expect(await store.details(of: elf)?.sections.map(\.heading).contains("Society") == true)
        #expect(await store.details(of: starfinderElf) == nil)
        let goblin = EntryReference(id: "Compendium.pf2e.ancestries.Item.goblin", name: "Goblin",
                                    credited: "Pathfinder Player Core")
        #expect(await store.details(of: goblin) == nil)
    }

    @Test func theNewEditionsComeFirstThenTheBookThenTheOtherBestiaries() {
        #expect(SourcebookList.creatureBooks(for: "Pathfinder Bestiary 2") == [
            "Pathfinder Monster Core", "Pathfinder Monster Core 2", "Pathfinder Bestiary 2", "Pathfinder Bestiary",
            "Pathfinder Bestiary 3"
        ])
        #expect(SourcebookList.creatureBooks(for: "Pathfinder Monster Core 2").prefix(2)
            == ["Pathfinder Monster Core", "Pathfinder Monster Core 2"])
        #expect(SourcebookList.creatureBooks(for: Self.adventure) == [Self.adventure])
    }

    @Test func aCompilationsCreaturesTakeLoreFromItsVolumesAndABooksOtherTitleFindsIt() {
        let list = SourcebookList(books: [
            Sourcebook(title: "Pathfinder Adventure Path #217: Death Sails", aliases: ["Pathfinder #217: Death Sails"],
                       supplies: [.creatureLore])
        ], volumes: ["Season of Ghosts Compilation": ["#196", "#197"]])
        #expect(list.creatureBookTitles(for: "Season of Ghosts Compilation")
            == ["Season of Ghosts Compilation", "#196", "#197"])
        #expect(list.creatureBookTitles(for: "Pathfinder #217: Death Sails").first
            == "Pathfinder Adventure Path #217: Death Sails")
        #expect(list.title(of: "Unlisted") == "Unlisted")
    }

    @Test func readsRecordsWrittenBeforeCreatureLore() throws {
        let list = try JSONDecoder().decode(SourcebookList.self, from: Data(#"{"books": [], "deities": {}}"#.utf8))
        #expect(list.creatures.isEmpty && list.volumes.isEmpty)
        let record = #"""
            {"title": "T", "sourceDigest": "d", "readerVersion": 1, "importedAt": 0, "deities": {}}
            """#
        let book = try JSONDecoder().decode(BookLore.self, from: Data(record.utf8))
        #expect(book.creatures.isEmpty && book.location == nil && book.sourceDate == nil)
    }

    @Test func theBundledListHasTheSamplesAndCreatureBooks() {
        let list = SourcebookList.bundled
        #expect(Array(list.books.suffix(2)) == SourcebookList.samples)
        #expect(list.books.contains { $0.title == "Starfinder Alien Core" && $0.supplies.contains(.creatureLore) })
        #expect(!list.creatures.isEmpty)
    }
}
