import FieldGuideKit
import Foundation
import SourcebookLore
import SourcebookLoreTestSupport
import Testing
@testable import FieldGuideUI

@Suite("Deity lore from the user's sourcebooks")
@MainActor
struct SourcebookModelTests {
    static let book = Sourcebook(title: "Pathfinder Lost Omens Test Gods", supplies: [.deityLore])
    static let supplement = Sourcebook(title: "Web Supplement", downloadURL: URL(string: "https://example.com/w.pdf"),
                                       supplies: [.deityLore])
    static let list = SourcebookList(books: [book, supplement], deities: [
        "id.abadar": LoreSources(stats: supplement.title, prose: book.title),
        "id.arazni": LoreSources(stats: supplement.title)
    ])
    static let names = ["id.abadar": "Abadar", "id.arazni": "Arazni"]

    static func page(id: String, html: String = "<h1>Abadar</h1>", details: String = "") -> EntryPage {
        EntryPage(id: id, name: "Abadar", system: .pathfinder, html: html, details: details)
    }

    @Test("A deity gets a Lore tab with its lore from the user's books")
    func deityLoreTab() {
        let tabs = PageTabs(page: Self.page(id: "Compendium.pf2e.deities.Item.ab1"), bookLore: "<p>Lore</p>")
        #expect(tabs.tabs == [.overview, .lore])
        #expect(tabs.html(for: .lore) == "<p>Lore</p>" && tabs.html(for: .overview) == "<h1>Abadar</h1>")
    }

    @Test("In a build that kept the lore, a deity's write-up moves from its overview to its Lore tab")
    func keptLoreMoves() {
        let html = "<h1>Abadar</h1>" + PageDescription.section("<p>Keeper of the Vault.</p>")
            + "<footer>GM Core</footer>"
        let tabs = PageTabs(page: Self.page(id: "Compendium.pf2e.deities.Item.ab1", html: html), bookLore: nil)
        #expect(tabs.tabs == [.overview, .lore])
        #expect(tabs.html(for: .overview) == "<h1>Abadar</h1><footer>GM Core</footer>")
        #expect(tabs.html(for: .lore).contains("Keeper of the Vault."))
    }

    @Test("Other pages keep their Details tab or have none")
    func otherPages() {
        let deity = PageTabs(page: Self.page(id: "Compendium.pf2e.deities.Item.ab1"), bookLore: nil)
        #expect(deity.tabs.isEmpty && deity.html(for: .lore) == "<h1>Abadar</h1>")
        let elf = PageTabs(page: Self.page(id: "Compendium.pf2e.ancestries.Item.el1", details: "<p>Elves</p>"),
                           bookLore: "<p>Ignored</p>")
        #expect(elf.tabs == [.overview, .details] && elf.html(for: .details) == "<p>Elves</p>")
        let spell = PageTabs(page: Self.page(id: "Compendium.pf2e.spells-srd.Item.fb1"), bookLore: "<p>Lore</p>")
        #expect(spell.tabs.isEmpty)
    }

    @Test("Reading a sourcebook lists it as read and gives its deities' lore")
    func readsABook() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sourcebooks-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Pathfinder Lost Omens Test Gods.pdf")
        let pdf = PDFFixture(pages: [[
            PDFFixture.text("Abadar", at: 80, 700, font: PDFFixture.bold, size: 34),
            PDFFixture.text("Abadar keeps the First Vault.", at: 80, 660)
        ]])
        #expect(pdf.document()?.write(to: file) == true)
        let model = SourcebookModel(store: try LoreStore(folder: folder.appendingPathComponent("Store"),
                                                         list: Self.list), list: Self.list)
        #expect(model.rows.map(\.isRead) == [false, false])
        #expect(model.rows.map(\.deityCount) == [1, 2])
        await model.addFiles([file], names: Self.names)
        #expect(model.message == "Read Pathfinder Lost Omens Test Gods.")
        #expect(model.rows.map(\.isRead) == [true, false])
        #expect(model.lore(of: "id.abadar")?.paragraphs == ["Abadar keeps the First Vault."])
        #expect(model.lore(of: "id.arazni") == nil)
        await model.addFiles([file], names: Self.names)
        #expect(model.message == "No new sourcebooks found.")
        await model.importFolder(folder, names: Self.names)
        await model.refresh(addingNew: true, names: Self.names)
        #expect(model.progress == nil)
    }

    @Test("Without a store there is no lore and nothing to read")
    func noStore() async {
        let model = SourcebookModel(store: nil, list: Self.list)
        await model.refresh(addingNew: true, names: Self.names)
        await model.addFiles([], names: Self.names)
        #expect(model.lore(of: "id.abadar") == nil && model.books.isEmpty)
    }
}
