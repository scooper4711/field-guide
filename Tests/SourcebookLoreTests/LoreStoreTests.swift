import Foundation
import PDFKit
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct LoreStoreTests {
    typealias Fixture = PDFFixture

    static let book = Sourcebook(title: "Pathfinder Lost Omens Test Gods", sku: "PZO99999E",
                                 aliases: ["Pathfinder Lost Omens- Test Gods"], supplies: [.deityLore])
    static let list = SourcebookList(books: [book], deities: [
        "id.abadar": LoreSources(stats: book.title, prose: book.title),
        "id.chavazvug": LoreSources(stats: "Web Supplement", prose: book.title)
    ])
    static let names = ["id.abadar": "Abadar", "id.chavazvug": "Chavazvug", "id.other": "Other"]

    /// A book with Abadar's write-up and Chavazvug's prose, and a copyright line on its last page.
    static let pages = DeityWriteupsTests.pages + [[
        Fixture.text("Pathfinder Lost Omens Test Gods © 2024, Paizo Inc.", at: 80, 400)
    ]]

    static func writeBook(named name: String, in folder: URL) throws -> URL {
        let file = folder.appendingPathComponent(name)
        try #require(PDFFixture(pages: pages).document()?.write(to: file) == true)
        return file
    }

    static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test func readsAChosenSourcebookOnceAndKeepsItsLore() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try Self.writeBook(named: "Pathfinder Lost Omens- Test Gods PDF - Single File.pdf", in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        #expect(try await store.addFiles([file], names: Self.names) == [Self.book.title])
        #expect(try await store.addFiles([file], names: Self.names).isEmpty)
        let abadar = try #require(await store.lore(of: "id.abadar"))
        #expect(abadar.statLines.first == StatLine(label: "Title", text: "Master of the First Vault"))
        #expect(abadar.paragraphs.count == 2)
        // Chavazvug's stat lines come from a book not read yet; its prose is there.
        #expect(await store.lore(of: "id.chavazvug")?.statLines == [])
        #expect(await store.lore(of: "id.chavazvug")?.paragraphs.count == 2)
        #expect(await store.lore(of: "id.other") == nil)
        let reopened = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        let stored = try #require(await reopened.books[Self.book.title])
        #expect(stored.readerVersion == BookReader.version && stored.sourceDigest.count == 64)
    }

    @Test func knowsARenamedPDFByItsCopyrightLine() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try Self.writeBook(named: "gods.pdf", in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        #expect(try await store.addFiles([file], names: Self.names) == [Self.book.title])
    }

    @Test func readsAWatchedFoldersSourcebooksByName() async throws {
        let folder = try Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let downloads = folder.appendingPathComponent("Files/Pathfinder Lost Omens- Test Gods")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        _ = try Self.writeBook(named: "gods.pdf", in: downloads)
        _ = try Self.writeBook(named: "Unrelated.pdf", in: folder.appendingPathComponent("Files"))
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: Self.list)
        #expect(try await store.importFolder(folder.appendingPathComponent("Files"), names: Self.names)
                == [Self.book.title])
        #expect(await store.watchedFolders.count == 1)
        #expect(try await store.addNewFiles(names: Self.names).isEmpty)
        try await store.unwatch(await store.watchedFolders[0])
        #expect(await store.watchedFolders.isEmpty)
    }

    @Test func identifiesBooksByNameFolderOrSKU() {
        let identifier = SourcebookIdentifier(list: Self.list)
        let folder = URL(filePath: "/Files/Pathfinder Lost Omens- Test Gods/whatever.pdf")
        #expect(identifier.book(namedBy: folder) == Self.book)
        #expect(identifier.book(namedBy: URL(filePath: "/x/PZO99999E Gods.pdf")) == Self.book)
        #expect(identifier.book(namedBy: URL(filePath: "/x/Pathfinder Lost Omens Test Gods.pdf")) == Self.book)
        #expect(identifier.book(namedBy: URL(filePath: "/x/PZO11111E Other.pdf")) == nil)
        #expect(identifier.book(namedBy: URL(filePath: "/x/notes.pdf")) == nil)
    }
}
