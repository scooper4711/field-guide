import Foundation
import Testing
@testable import LorespireImport

@Suite("Lorespire library")
struct LorespireLibraryTests {
    func entries(_ system: LorespireDocument.System) throws -> [LorespireEntry] {
        let library = try LorespireFixtures.library()
        defer { try? FileManager.default.removeItem(at: library.folder) }
        return try library.entries(for: system)
    }

    func entry(_ id: String, in entries: [LorespireEntry]) throws -> LorespireEntry {
        try #require(entries.first { $0.id == id })
    }

    @Test("A system gets its own guide's pages, then the pages of the guides for both, in order")
    func order() throws {
        let entries = try entries(.pathfinder)
        #expect(entries.map(\.id) == [
            "lorespire.pf2e.demo._.Intro", "lorespire.pf2e.demo._.Making-Heroes", "lorespire.pf2e.demo._.Rules",
            "lorespire.pf2e.demo._.Two", "lorespire.pf2e.demo._.Book-Start", "lorespire.pf2e.demo._.Book.Appendix"
        ])
        #expect(entries.map(\.order) == Array(0..<6))
        #expect(entries.last?.part == "Handbook")
        #expect(try self.entries(.starfinder).map(\.id) == [
            "lorespire.sf2e.other._.O", "lorespire.sf2e.demo._.Book-Start", "lorespire.sf2e.demo._.Book.Appendix"
        ])
    }

    @Test("Links open the system's entries: by page, by heading, and empty pages open the next one")
    func entryLinks() throws {
        let entries = try entries(.pathfinder)
        let intro = try entry("lorespire.pf2e.demo._.Intro", in: entries).html
        #expect(intro.contains("<a href=\"entry:lorespire.pf2e.demo._.Making-Heroes\">Making Heroes</a>"))
        let heroes = try entry("lorespire.pf2e.demo._.Making-Heroes", in: entries).html
        #expect(heroes.contains("href=\"entry:lorespire.pf2e.demo._.Intro\">the basics"))
        #expect(heroes.contains("href=\"entry:lorespire.pf2e.demo._.Intro\">the tail"))
        #expect(heroes.contains("href=\"entry:lorespire.pf2e.demo._.Rules\">Empty"))
        let start = try entry("lorespire.pf2e.demo._.Book-Start", in: entries).html
        #expect(start.contains("href=\"entry:lorespire.pf2e.demo._.Rules\">the rules"))
    }

    @Test("Pages that aren't in the system's guides, and attachments, open Lorespire; images show the download")
    func otherLinks() throws {
        let start = try entry("lorespire.sf2e.demo._.Book-Start", in: entries(.starfinder)).html
        #expect(start.contains("href=\"https://lorespire.paizo.com/tiki-index.php?page=demo._.Rules\""))
        #expect(start.contains("href=\"https://lorespire.paizo.com/tiki-index.php?page=demo._.Gone\""))
        #expect(start.contains("href=\"https://lorespire.paizo.com/tiki-download_file.php?fileId=9\""))
        let two = try entry("lorespire.pf2e.demo._.Two", in: entries(.pathfinder)).html
        #expect(two.contains("<img src=\"fieldguide:///images/lorespire/7.png\" alt=\"Chart\" />"))
    }

    @Test("Each entry links its page on Lorespire, or the heading in its document when it has no page")
    func sources() throws {
        let entries = try entries(.pathfinder)
        #expect(try entry("lorespire.pf2e.demo._.Rules", in: entries).source.absoluteString
            == "https://lorespire.paizo.com/tiki-index.php?page=demo._.Rules")
        #expect(try entry("lorespire.pf2e.demo._.Book.Appendix", in: entries).source.absoluteString
            == "https://lorespire.paizo.com/tiki-index.php?page=demo._.Book#Appendix")
    }

    @Test("The licenses page reads as Markdown")
    func licenses() throws {
        let library = try LorespireFixtures.library()
        defer { try? FileManager.default.removeItem(at: library.folder) }
        #expect(try library.licenses() == """
            ### Trademarks

            Demo © Someone; **all** *rights*.

            1. First [term](https://example.com)

            2. Second
            line

            - Dot

            """)
        #expect(try LorespireLibrary(folder: library.folder, documents: []).licenses().isEmpty)
    }

    @Test("A missing document fails with its path")
    func missing() throws {
        let library = LorespireLibrary(folder: URL(fileURLWithPath: "/nonexistent"),
                                       documents: LorespireFixtures.libraryDocuments)
        #expect(throws: LorespireError.missingDownload(path: "/nonexistent/demo.html")) {
            try library.entries(for: .pathfinder)
        }
        #expect(LorespireError.missingDownload(path: "/x").description.contains("run make lorespire"))
    }
}
