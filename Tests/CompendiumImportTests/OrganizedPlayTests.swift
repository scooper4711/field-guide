import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

/// A made-up Lorespire download, in the documents' own file names, with no Paizo text.
enum LorespireDownload {
    static func heading(_ level: Int, _ id: String, page: String, _ title: String) -> String {
        "<h\(level) id=\"\(id)\"><a href=\"tiki-index.php?page=\(page)\">\(title)</a></h\(level)>"
    }

    static let files = [
        "pfs2-guide.html": heading(1, "Intro", page: "pfs2guide._.Intro", "Intro") + "<p>Welcome, wanderer.</p>"
            + heading(2, "Boons", page: "popguide._.Boons", "Boons")
            + "<p>Boons <img src=\"tiki-download_file.php?fileId=7\" /> reward play.</p>",
        "sfs2-guide.html": heading(1, "Intro", page: "sfs2guide._.Intro", "Intro") + "<p>Welcome, spacer.</p>",
        "vo-handbook.html": heading(2, "Officers", page: "vohandbook._.Officers", "Officers") + "<p>Lead.</p>",
        "licenses.html": "<h3 id=\"T\">Trademarks</h3><p>Demo.</p>"
    ]

    static func write(in root: URL) throws -> URL {
        let folder = root.appendingPathComponent("lorespire")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("files"),
                                                withIntermediateDirectories: true)
        for (name, html) in files { try Data(html.utf8).write(to: folder.appendingPathComponent(name)) }
        try Data([1]).write(to: folder.appendingPathComponent("files/7.png"))
        return folder
    }
}

@Suite struct OrganizedPlayTests {
    func imported() throws -> Imported {
        try Imported { options in
            options.lorespire = try? LorespireDownload.write(in: options.workFolder.deletingLastPathComponent())
            options.lorespireIcons = LorespireIcons(parts: ["Intro": "Weapons/sword.png"],
                                                    pages: ["Boons": "Weapons/missing.png"])
        }
    }

    @Test("Each system's guide pages, then the VO Handbook's, are Organized Play entries in guide order")
    func entries() throws {
        let imported = try imported()
        defer { imported.repository.remove() }
        #expect(try imported.catalog.categories(in: .pathfinder).prefix(2) == [.gmScreen, .organizedPlay])
        let pathfinder = try imported.catalog.summaries(of: .organizedPlay, in: .pathfinder)
        #expect(pathfinder.map(\.name) == ["Intro", "Boons", "Officers"])
        #expect(pathfinder.map { $0.values(of: .section) } == [["Intro"], ["Intro"], ["Venture-Officer Handbook"]])
        #expect(pathfinder.map(\.subtitle) == ["Intro", "Intro", "Venture-Officer Handbook"])
        // Intro's part has the sword; Boons names a picture the packs lack; the handbook has none.
        #expect(pathfinder.map(\.image) == ["rexard/Weapons/sword.webp", "", ""])
        let starfinder = try imported.catalog.summaries(of: .organizedPlay, in: .starfinder)
        #expect(starfinder.map(\.id) == ["lorespire.sf2e.sfs2guide._.Intro", "lorespire.sf2e.vohandbook._.Officers"])
    }

    @Test("A guide page has the app's header, its images from the download, a link to Lorespire, and is searchable")
    func page() throws {
        let imported = try imported()
        defer { imported.repository.remove() }
        let html = try imported.page("lorespire.pf2e.popguide._.Boons")
        #expect(html.hasPrefix("<header class=\"entry-header\"><div><h1>Boons</h1><p class=\"subtitle\">Intro</p>"))
        #expect(try imported.page("lorespire.pf2e.pfs2guide._.Intro").contains(
            "<img class=\"art\" src=\"fieldguide:///images/rexard/Weapons/sword.webp\""))
        #expect(html.contains("<img src=\"fieldguide:///images/lorespire/7.png\" />"))
        #expect(html.hasSuffix("<footer class=\"source\"><a href=\""
            + "https://lorespire.paizo.com/tiki-index.php?page=popguide._.Boons\">Lorespire</a></footer>"))
        #expect(try imported.catalog.search("wanderer", in: .organizedPlay, of: .pathfinder)
            == ["lorespire.pf2e.pfs2guide._.Intro"])
        let output = imported.repository.output
        #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("Images/lorespire/7.png").path))
        let licenses = try String(contentsOf: output.appendingPathComponent(
            "Licenses/Lorespire Licenses and Trademarks.md"), encoding: .utf8)
        #expect(licenses == "### Trademarks\n\nDemo.\n")
    }

    @Test("Without a download, there are no Organized Play entries")
    func withoutDownload() throws {
        let imported = try Imported()
        defer { imported.repository.remove() }
        #expect(try imported.catalog.summaries(of: .organizedPlay, in: .pathfinder).isEmpty)
    }
}

@Suite struct LorespireIconTests {
    let icons = LorespireIcons(parts: ["Core Guide": "scroll.png"], pages: ["Boons": "medal.png"])

    @Test("A page's own picture, by its name without its book, comes before its part's")
    func choice() {
        #expect(icons.file(forPage: "popguide._.Boons", part: "Core Guide") == "medal.png")
        #expect(icons.file(forPage: "pfs2guide._.Boons", part: "Other") == "medal.png")
        #expect(icons.file(forPage: "pfs2guide._.Key-Terms", part: "Core Guide") == "scroll.png")
        #expect(icons.file(forPage: "pfs2guide", part: "Other") == nil)
    }

    @Test("The file is read when it is there, and means no pictures when it isn't")
    func load() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("icons-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try LorespireIcons.load(from: url) == LorespireIcons())
        try JSONEncoder().encode(icons).write(to: url)
        #expect(try LorespireIcons.load(from: url) == icons)
    }
}
