import FieldGuideKit
import Foundation
import SourcebookLore
import SourcebookLoreTestSupport
import Testing
@testable import FieldGuideUI

@Suite("Deity and creature lore from the user's sourcebooks")
@MainActor
struct SourcebookModelTests {
    static let book = Sourcebook(title: "Pathfinder Lost Omens Test Gods", supplies: [.deityLore])
    static let supplement = Sourcebook(title: "Web Supplement", downloadURL: URL(string: "https://example.com/w.pdf"),
                                       supplies: [.deityLore])
    static let list = SourcebookList(books: [book, supplement], deities: [
        "id.abadar": LoreSources(stats: supplement.title, prose: book.title),
        "id.arazni": LoreSources(stats: supplement.title)
    ])
    static let subjects = LoreSubjects(deityNames: ["id.abadar": "Abadar", "id.arazni": "Arazni"])

    static func page(id: String, html: String = "<h1>Abadar</h1>", details: String = "") -> EntryPage {
        EntryPage(id: id, name: "Abadar", system: .pathfinder, html: html, details: details)
    }

    @Test("A deity gets a Lore tab with its lore from the user's books")
    func deityLoreTab() {
        let tabs = PageTabs(page: Self.page(id: "Compendium.pf2e.deities.Item.ab1"), bookLore: "<p>Lore</p>")
        #expect(tabs.tabs == [.overview, .lore])
        #expect(tabs.html(for: .lore) == "<p>Lore</p>" && tabs.html(for: .overview) == "<h1>Abadar</h1>")
    }

    @Test("A deity's write-up the Paizo Blog published moves from its overview to its Lore tab")
    func keptLoreMoves() {
        let html = "<h1>Abadar</h1>" + PageDescription.section("<p>Keeper of the Vault.</p>")
            + "<footer>GM Core</footer>"
        let tabs = PageTabs(page: Self.page(id: "Compendium.pf2e.deities.Item.ab1", html: html), bookLore: nil)
        #expect(tabs.tabs == [.overview, .lore])
        #expect(tabs.html(for: .overview) == "<h1>Abadar</h1><footer>GM Core</footer>")
        #expect(tabs.html(for: .lore).contains("Keeper of the Vault."))
    }

    @Test("An ancestry's Details show the lore from its book where the import left room for it")
    func detailsLore() {
        let page = Self.page(id: "Compendium.pf2e.ancestries.Item.el1",
                             details: "<p>Intro</p>\(DetailsPage.loreMarker)<h2>Elf Mechanics</h2>")
        let tabs = PageTabs(page: page, bookLore: nil, detailsLore: "<p>Lore</p>")
        #expect(tabs.html(for: .details) == "<p>Intro</p><p>Lore</p><h2>Elf Mechanics</h2>")
        #expect(PageTabs(page: page, bookLore: nil).html(for: .details) == "<p>Intro</p><h2>Elf Mechanics</h2>")
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

    @Test("Processing a sourcebook lists it as processed and gives its deities' lore")
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
        #expect(model.rows.map(\.counts.deities) == [1, 2])
        #expect(model.rows.map(\.supplies) == ["Deity lore: 1 deity", "Deity lore: 2 deities"])
        await model.addFiles([file], subjects: Self.subjects)
        #expect(model.message == "Processed Pathfinder Lost Omens Test Gods.")
        #expect(model.rows.map(\.isRead) == [true, false])
        #expect(model.lore(of: "id.abadar")?.paragraphs == ["Abadar keeps the First Vault."])
        #expect(model.lore(of: "id.arazni") == nil)
        await model.addFiles([file], subjects: Self.subjects)
        #expect(model.message == "No new sourcebooks found.")
        await model.importFolder(folder, subjects: Self.subjects)
        await model.refresh(addingNew: true, subjects: Self.subjects)
        #expect(model.progress == nil)
    }

    @Test("A book gives its write-up to every deity it's assigned with the name, not one picked at random")
    func readsADeityTwoEntriesShare() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sourcebooks-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Pathfinder Lost Omens Test Gods.pdf")
        let pdf = PDFFixture(pages: [[
            PDFFixture.text("Abadar", at: 80, 700, font: PDFFixture.bold, size: 34),
            PDFFixture.text("Abadar keeps the First Vault.", at: 80, 660)
        ]])
        #expect(pdf.document()?.write(to: file) == true)
        let list = SourcebookList(books: [Self.book], deities: [
            "id.abadar": LoreSources(prose: Self.book.title), "id.abadar.other": LoreSources(prose: Self.book.title)
        ])
        let model = SourcebookModel(store: try LoreStore(folder: folder.appendingPathComponent("Store"), list: list),
                                    list: list)
        await model.addFiles([file], subjects: LoreSubjects(deityNames: ["id.abadar": "Abadar",
                                                                         "id.abadar.other": "Abadar"]))
        #expect(model.lore(of: "id.abadar")?.paragraphs == ["Abadar keeps the First Vault."])
        #expect(model.lore(of: "id.abadar.other")?.paragraphs == ["Abadar keeps the First Vault."])
    }

    @Test("Processing says which book it processes")
    func readingMessage() {
        let book = URL(filePath: "/Books/Pathfinder Lost Omens Test Gods.pdf")
        #expect(SourcebookModel.readingMessage(for: [book], list: Self.list)
            == "Processing Pathfinder Lost Omens Test Gods…")
        #expect(SourcebookModel.readingMessage(for: [URL(filePath: "/Books/Notes.pdf")], list: Self.list)
            == "Processing Notes…")
        #expect(SourcebookModel.readingMessage(for: [book, book], list: Self.list) == "Processing sourcebooks…")
    }

    @Test("Without a store there is no lore and nothing to read")
    func noStore() async {
        let model = SourcebookModel(store: nil, list: Self.list)
        await model.refresh(addingNew: true, subjects: Self.subjects)
        await model.addFiles([], subjects: Self.subjects)
        #expect(model.lore(of: "id.abadar") == nil && model.books.isEmpty)
    }

    @Test("The sample sourcebooks give creatures and deities placeholder lore, after any real book's")
    func readsTheSamples() async throws {
        let (model, folder) = try await Self.modelReadingTheSamples()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(model.detailsHTML(of: Sample.fighter.id)?.contains("<h2>During Combat Encounters...</h2>") == true)
        let note = "Add your copy of Pathfinder Player Core in Sourcebooks to read the lore for Wizard."
        #expect(model.detailsHTML(of: Sample.wizard.id) == "<p class=\"note\"><em>\(note)</em></p>")
        #expect(model.detailsHTML(of: "id.other") == nil)
        #expect(model.message == "Processed 2 sourcebooks.")
        #expect(model.creatureLore(of: Sample.warrior.id)?.family == "Goblin")
        #expect(model.creatureLore(of: Sample.warrior.id)?.paragraphs.first?.hasPrefix(SampleSourcebook.marker) == true)
        #expect(model.creatureLore(of: Sample.hunter.id)?.family == "Kholo")
        #expect(model.creatureLore(of: Sample.alloid.id)?.family == "Alloid")
        #expect(model.lore(of: Sample.pathfinderAbadar)?.statLines.contains { $0.label == "Edicts" } == true)
        #expect(model.rows.allSatisfy { $0.supplies == "Placeholder lore for trying Field Guide" })
    }

    @Test("Each game's sample gives its lore only to that game's entries, whatever the dictionaries' order")
    func eachSampleGivesLoreToItsOwnGame() async throws {
        let (model, folder) = try await Self.modelReadingTheSamples()
        defer { try? FileManager.default.removeItem(at: folder) }
        let pathfinder = try #require(model.lore(of: Sample.pathfinderAbadar)?.paragraphs)
        let starfinder = try #require(model.lore(of: Sample.starfinderAbadar)?.paragraphs)
        #expect(pathfinder != starfinder)
        #expect(pathfinder.first?.hasPrefix(SampleSourcebook.marker) == true)
        #expect(starfinder.first?.hasPrefix(SampleSourcebook.marker) == true)
        #expect(model.lore(of: Sample.aakriti)?.paragraphs.isEmpty == false)
        // Angradd is only in the Starfinder sample, and Aakriti only in the Pathfinder one.
        #expect(model.lore(of: Sample.starfinderAngradd)?.paragraphs.isEmpty == false)
        #expect(model.lore(of: Sample.pathfinderAngradd) == nil)
        #expect(model.creatureLore(of: Sample.pathfinderTroll.id) == nil)
        #expect(model.creatureLore(of: Sample.troll.id)?.paragraphs.first?.hasPrefix(SampleSourcebook.marker) == true)
        #expect(model.detailsHTML(of: Sample.android.id)?.contains(SampleSourcebook.marker) == true)
    }

    /// Entries of both games that the samples print, or don't.
    enum Sample {
        static let warrior = creature("pf2e", "Goblin Warrior", "Pathfinder Monster Core")
        static let hunter = creature("pf2e", "Kholo Hunter", "Pathfinder Monster Core")
        static let alloid = creature("sf2e", "Alloid (Ship Stealer)", "Starfinder Alien Core")
        static let troll = creature("sf2e", "Mutant Troll", "Starfinder Alien Core")
        static let pathfinderTroll = creature("pf2e", "Mutant Troll", "Pathfinder Monster Core")
        static let fighter = details("pf2e", "Fighter", "Pathfinder Player Core")
        static let wizard = details("pf2e", "Wizard", "Pathfinder Player Core")
        static let android = details("sf2e", "Android", "Starfinder Player Core")
        static let pathfinderAbadar = "Compendium.pf2e.deities.Item.abadar"
        static let starfinderAbadar = "Compendium.sf2e.deities.Item.abadar"
        static let aakriti = "Compendium.pf2e.deities.Item.aakriti"
        static let pathfinderAngradd = "Compendium.pf2e.deities.Item.angradd"
        static let starfinderAngradd = "Compendium.sf2e.deities.Item.angradd"
        static let subjects = LoreSubjects(
            deityNames: [pathfinderAbadar: "Abadar", starfinderAbadar: "Abadar", aakriti: "Aakriti",
                         pathfinderAngradd: "Angradd", starfinderAngradd: "Angradd"],
            creatures: [warrior, hunter, alloid, troll, pathfinderTroll],
            details: [fighter, wizard, android])

        static func creature(_ game: String, _ name: String, _ credited: String) -> EntryReference {
            EntryReference(id: "Compendium.\(game).bestiary.Actor.\(name)", name: name, credited: credited)
        }

        static func details(_ game: String, _ name: String, _ credited: String) -> EntryReference {
            EntryReference(id: "Compendium.\(game).classes.Item.\(name)", name: name, credited: credited)
        }
    }

    /// A model that has read both samples, and the temporary folder that holds them.
    static func modelReadingTheSamples() async throws -> (SourcebookModel, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sample-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = SampleSourcebook.all.map { folder.appendingPathComponent("\($0.title).pdf") }
        for (sample, file) in zip(SampleSourcebook.all, files) {
            #expect(sample.document()?.write(to: file) == true)
        }
        let list = SourcebookList(books: SourcebookList.samples)
        let model = SourcebookModel(store: try LoreStore(folder: folder.appendingPathComponent("Store"), list: list),
                                    list: list)
        await model.addFiles(files, subjects: Sample.subjects)
        return (model, folder)
    }
}
