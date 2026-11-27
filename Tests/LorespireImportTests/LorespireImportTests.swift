import Foundation
import Testing
@testable import LorespireImport

@Suite("Lorespire pages")
struct LorespirePageTests {
    @Test("A page keeps its title and article, without the site's menus, scripts and buttons")
    func page() throws {
        let page = try LorespirePage(html: LorespireFixtures.guide, page: "demo._.All")
        #expect(page.title == "Complete Compilation")
        #expect(page.content.hasPrefix("<h1 class=\"showhide_heading\" id=\"Core_Guide\">"))
        #expect(page.content.hasSuffix("<img src=\"img/icons/star.png\" /></p>"))
        for gone in ["Menu", "Last edited", "Translations", "<script", "No Tabs", "onclick", "heading-link"] {
            #expect(!page.content.contains(gone), "\(gone)")
        }
    }

    @Test("The title's entities are decoded, and a page without one is titled by its name")
    func titles() throws {
        #expect(try LorespirePage(html: LorespireFixtures.handbook, page: "h").title == "Handbook & More")
        let untitled = LorespireFixtures.guide.replacingOccurrences(of: "pagetitle", with: "other")
        #expect(try LorespirePage(html: untitled, page: "demo._.All").title == "demo._.All")
    }

    @Test("A page without an article fails with its name")
    func missing() {
        #expect(throws: LorespireError.missingContent(page: "nope")) {
            try LorespirePage(html: "<html>Page not found</html>", page: "nope")
        }
        #expect(LorespireError.missingContent(page: "nope").description.contains("nope has no page content"))
    }

    @Test("The outline lists the h1 to h3 headings with ids, as text")
    func outline() {
        let html = LorespireFixtures.heading(1, "A", "<a href=\"x\">Core&nbsp;Guide</a>")
            + LorespireFixtures.heading(3, "B", "Small") + LorespireFixtures.heading(4, "C", "Tiny") + "<h2>None</h2>"
        #expect(LorespireHeadings.outline(of: html) == [
            LorespireHeading(level: 1, id: "A", title: "Core Guide"),
            LorespireHeading(level: 3, id: "B", title: "Small")
        ])
    }
}

@Suite("Lorespire links")
struct LorespireLinkTests {
    let rewriter = LorespireLinkRewriter(
        documents: LorespireFixtures.documents,
        anchors: ["demo._.Making-Heroes": LorespireAnchor(document: "demo-guide", id: "Making_Heroes")],
        files: [7: "files/7.png"])

    func link(_ href: String, in document: String = "demo-guide") -> String {
        rewriter.rewrite("<a href=\"\(href)\">", in: document)
    }

    @Test("Headings that link to a page mark where that page starts; the first one wins")
    func anchors() {
        let first = LorespireFixtures.heading(2, "One", "<a href=\"tiki-index.php?page=p#x\">One</a>")
        let second = LorespireFixtures.heading(2, "Two", "<a href=\"tiki-index.php?page=p\">Two</a>")
        #expect(LorespireHeadings.anchors(in: [("a", first), ("b", second)])
            == ["p": LorespireAnchor(document: "a", id: "One")])
    }

    @Test("Links to downloaded pages open the local copy", arguments: [
        ("tiki-index.php?page=demo._.Making-Heroes", "demo-guide", "#Making_Heroes"),
        ("tiki-index.php?page=demo._.Making-Heroes#Rules", "demo-guide", "#Rules"),
        ("tiki-index.php?page=demo._.Making-Heroes", "demo-handbook", "demo-guide.html#Making_Heroes"),
        ("/tiki-index.php?page=demo._.Full", "demo-handbook", "demo-guide.html"),
        ("https://lorespire.paizo.com/tiki-index.php?page=demo._.Handbook#Top", "demo-guide", "demo-handbook.html#Top"),
        ("tiki-index.php?page=demo._.All", "demo-guide", "demo-guide.html"),
        ("#Here", "demo-guide", "#Here")
    ])
    func local(href: String, document: String, expected: String) {
        #expect(link(href, in: document) == "<a href=\"\(expected)\">")
    }

    @Test("Other links point at Lorespire, or stay as they are", arguments: [
        ("tiki-index.php?page=demo._.Elsewhere", "https://lorespire.paizo.com/tiki-index.php?page=demo._.Elsewhere"),
        ("http://lorespire.paizo.com/tiki-index.php?page=x#y", "https://lorespire.paizo.com/tiki-index.php?page=x#y"),
        ("tiki-download_file.php?fileId=8", "https://lorespire.paizo.com/tiki-download_file.php?fileId=8"),
        ("img/a.png", "https://lorespire.paizo.com/img/a.png"),
        ("https://example.com/a?b=1&amp;c=2", "https://example.com/a?b=1&amp;c=2"),
        ("mailto:gm@example.com", "mailto:gm@example.com")
    ])
    func remote(href: String, expected: String) {
        #expect(link(href) == "<a href=\"\(expected)\">")
    }

    @Test("Images and attachments use the saved files")
    func files() {
        #expect(rewriter.rewrite("<img src=\"tiki-download_file.php?fileId=7&amp;display&amp;x=1\" />", in: "x")
            == "<img src=\"files/7.png\" />")
        #expect(LorespireLinkRewriter.fileIDs(in: LorespireFixtures.guide) == [7, 9])
    }
}

@Suite("Lorespire download")
struct LorespireDownloadTests {
    func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("lorespire-\(UUID().uuidString)/Lorespire")
    }

    @Test("The download saves each document, its files and a manifest, replacing an earlier download")
    func download() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("stale.html"))

        let manifest = try await LorespireDownloader(fetcher: FakeFetcher(), documents: LorespireFixtures.documents)
            .download(to: folder)

        #expect(manifest.files == ["files/7.png", "files/9-welcome-letter.pdf"])
        #expect(manifest.documents.map(\.title) == ["Complete Compilation", "Handbook & More"])
        #expect(manifest.documents[0].outline.map(\.id) == ["Core_Guide", "Making_Heroes"])
        #expect(manifest.documents[1].source == "https://lorespire.paizo.com/tiki-index.php?page=demo._.Handbook")
        let saved = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(saved == ["demo-guide.html", "demo-handbook.html", "files", "manifest.json"])
        let handbook = try String(contentsOf: folder.appendingPathComponent("demo-handbook.html"), encoding: .utf8)
        #expect(handbook.contains("href=\"demo-guide.html#Making_Heroes\""))
        let decoded = try JSONDecoder().decode(LorespireManifest.self,
                                               from: Data(contentsOf: folder.appendingPathComponent("manifest.json")))
        #expect(decoded == manifest)
        #expect(try Data(contentsOf: folder.appendingPathComponent("files/9-welcome-letter.pdf")) == Data([3]))
    }

    @Test("A failed fetch leaves the folder as it was")
    func failure() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var fetcher = FakeFetcher()
        fetcher.responses[Lorespire.fileURL(9).absoluteString] = nil

        await #expect(throws: LorespireError.httpStatus(url: Lorespire.fileURL(9), status: 404)) {
            try await LorespireDownloader(fetcher: fetcher, documents: LorespireFixtures.documents)
                .download(to: folder)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        #expect(LorespireError.httpStatus(url: Lorespire.fileURL(9), status: 404).description.hasSuffix("answered 404"))
    }

    @Test("Files without a suggested name are named by their type")
    func names() {
        #expect(SavedFile.name(3, LorespireResponse(data: Data(), contentType: "image/gif")) == "3.gif")
        #expect(SavedFile.name(4, LorespireResponse(data: Data(), contentType: "text/odd")) == "4.bin")
        #expect(SavedFile.name(5, LorespireResponse(data: Data(), contentType: "", suggestedFileName: "-.")) == "5.bin")
    }

    @Test("The guides are the two second-edition compilations, the VO handbook and the licenses")
    func documents() {
        #expect(Lorespire.documents.map(\.page) == [
            "pfs2guide._.Complete-Compilation", "sfs2guide._.Complete-Compilation", "vohandbook._.Full-Handbook",
            "site._.Licenses-And-Trademarks"
        ])
        #expect(Lorespire.documents[0].opens("pfs2guide._.Full-Guide"))
        #expect(!Lorespire.documents.contains { $0.page.hasPrefix("sfsguide") })
    }
}
