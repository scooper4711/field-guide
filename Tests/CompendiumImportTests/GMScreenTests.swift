import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct GMScreenTests {
    @Test func pagesGetTheirSectionAndLinkEachOther() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        try repository.writeGMScreen()
        let options = ImportOptions(paths: repository.paths, combatPadGenerated: nil, output: repository.output)
        _ = try CompendiumImporter(options: options).run()
        let catalog = try Catalog(url: repository.output.appendingPathComponent("catalog.sqlite"))
        let pages = try catalog.summaries(of: .gmScreen, in: .pathfinder)
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

    @Test func areaDiagramsComeFromThePlayerCorePage() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        _ = try repository.writePlayerCore(folder: "Pathfinder Player Core")
        let region = CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25)
        let diagrams = AreaDiagrams(
            scrollkeeperFiles: repository.root.appendingPathComponent("Files"), images: repository.output,
            pages: [AreaDiagramPage(system: .pathfinder, folder: "Pathfinder Player Core", pageLabel: "2",
                                    region: region, source: "Book"),
                    AreaDiagramPage(system: .starfinder, folder: "Missing", pageLabel: "2", region: region, source: "")]
        )
        let rows = diagrams.rows()
        #expect(rows.map(\.id) == ["fieldguide.pf2e.areas"])
        let row = try #require(rows.first)
        #expect(row.category == .gmScreen && row.html.contains("Book page 2"))
        #expect(row.facets == [.section: ["Playing the Game"]])
        let image = repository.output.appendingPathComponent(row.image)
        let size = try #require(ArtScaler.pixelSize(of: image))
        #expect(size.width == 300 && size.height == 225)
        let wrongPage = AreaDiagramPage(system: .pathfinder, folder: "Pathfinder Player Core", pageLabel: "9",
                                        region: region, source: "")
        #expect(AreaDiagrams(scrollkeeperFiles: repository.root.appendingPathComponent("Files"),
                             images: repository.output, pages: [wrongPage]).rows().isEmpty)
    }
}
