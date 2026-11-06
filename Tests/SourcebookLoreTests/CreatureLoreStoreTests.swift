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
    static let warrior = CreatureReference(id: "id.warrior", name: "Goblin Warrior", credited: bestiary.title)

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
            _ = try await store.addFiles([file], names: [:])
        }
        #expect(await store.lore(of: Self.warrior)?.paragraphs == ["From Monster Core."])
    }

    @Test func aBestiaryCreatureTakesItsNewEditionsLoreAndAnAdventureCreatureItsBestiarys() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let core = try Self.writeBook(Self.monsterCore, saying: "From Monster Core.", in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        #expect(await store.lore(of: Self.warrior) == nil)
        #expect(try await store.addFiles([core], names: [:]) == [Self.monsterCore.title])
        #expect(await store.lore(of: Self.warrior)?.paragraphs == ["From Monster Core."])
        let hydra = CreatureReference(id: "id.hydra", name: "Hooktongue Hydra", credited: Self.adventure)
        #expect(await store.lore(of: hydra)?.paragraphs == ["Hydras regrow heads."])
        let unknown = CreatureReference(id: "id.other", name: "Goblin Warrior", credited: Self.adventure)
        #expect(await store.lore(of: unknown) == nil)
    }

    @Test func theNewEditionsComeFirstThenTheBookThenTheOtherBestiaries() {
        #expect(SourcebookList.creatureBooks(for: "Pathfinder Bestiary 2") == [
            "Pathfinder Monster Core", "Pathfinder Monster Core 2", "Pathfinder Bestiary 2", "Pathfinder Bestiary",
            "Pathfinder Bestiary 3", SourcebookList.sample.title
        ])
        #expect(SourcebookList.creatureBooks(for: "Pathfinder Monster Core 2").prefix(2)
            == ["Pathfinder Monster Core", "Pathfinder Monster Core 2"])
        #expect(SourcebookList.creatureBooks(for: Self.adventure) == [Self.adventure, SourcebookList.sample.title])
    }

    @Test func readsRecordsWrittenBeforeCreatureLore() throws {
        let list = try JSONDecoder().decode(SourcebookList.self, from: Data(#"{"books": [], "deities": {}}"#.utf8))
        #expect(list.creatures.isEmpty)
        let record = #"""
            {"title": "T", "sourceDigest": "d", "readerVersion": 1, "importedAt": 0, "deities": {}}
            """#
        let book = try JSONDecoder().decode(BookLore.self, from: Data(record.utf8))
        #expect(book.creatures.isEmpty && book.location == nil && book.sourceDate == nil)
    }

    @Test func theBundledListHasTheSampleAndCreatureBooks() {
        let list = SourcebookList.bundled
        #expect(list.books.last == SourcebookList.sample)
        #expect(list.books.contains { $0.title == "Starfinder Alien Core" && $0.supplies.contains(.creatureLore) })
        #expect(!list.creatures.isEmpty)
    }
}
