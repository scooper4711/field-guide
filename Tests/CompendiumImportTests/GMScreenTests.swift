import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct GMScreenTests {
    @Test func pagesGetTheirSectionAndLinkEachOther() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        try repository.writeGMScreen()
        let options = ImportOptions(paths: repository.paths, output: repository.output,
                                    workFolder: repository.root.appendingPathComponent("work"))
        _ = try CompendiumImporter(options: options).run()
        let catalog = try Catalog(url: repository.output.appendingPathComponent("catalog.sqlite"))
        let pages = try catalog.summaries(of: .gmScreen, in: .pathfinder).filter { $0.name != "Areas" }
        #expect(pages.map(\.name) == ["DCs by Level", "Simple DCs"])
        #expect(pages.allSatisfy { $0.subtitle == "Running the Game" })
        #expect(pages.allSatisfy { $0.values(of: .section) == ["Running the Game"] })
        let dcs = try #require(try catalog.page(of: "Compendium.pf2e.journals.JournalEntry.gm1.JournalEntryPage.p3"))
        #expect(dcs.html.contains("<a href=\"entry:Compendium.pf2e.journals.JournalEntry.gm1.JournalEntryPage.p2\">"
                                  + "Simple DCs</a>"))
        #expect(try catalog.search("trained", in: .gmScreen, of: .pathfinder).count == 1)
    }

    @Test func pageLinksIgnoreHeadingAnchors() {
        var links = LinkIndex()
        links.add(JournalPage(system: .starfinder, journalID: "j", pageID: "p", name: "Light", section: "", html: ""))
        let uuid = "Compendium.sf2e.journals.JournalEntry.j.JournalEntryPage.p"
        #expect(links.entryID(forLink: uuid + "#dim-light") == uuid && links.name(of: uuid) == "Light")
        #expect(GMScreen.pages(repository: URL(fileURLWithPath: "/nowhere"), system: .pathfinder).isEmpty)
    }
}
