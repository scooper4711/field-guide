import Foundation
@testable import LorespireImport

/// Made-up Tiki Wiki pages shaped like Lorespire's, so the tests need no network and no Paizo text.
enum LorespireFixtures {
    static func wikiPage(title: String, content: String) -> String {
        """
        <html><body><nav><a href="tiki-index.php?page=Menu">Menu</a></nav>
        <h1 class="pagetitle">
        <a class="" title="refresh" href="tiki-index.php?page=x">\(title)</a>
        </h1>
        <article id="top" class="wikitext clearfix">
        <div id="page-data" class="clearfix">
        \(content)
        </div>
        <footer>Last edited</footer>
        </article><div id="col3">Translations</div></body></html>
        """
    }

    static func heading(_ level: Int, _ id: String, _ inner: String) -> String {
        "<h\(level) class=\"showhide_heading\" id=\"\(id)\">\(inner)<a href=\"#\(id)\" class=\"heading-link\">"
            + "<span class=\"icon\"></span></a></h\(level)>"
    }

    static let guide = wikiPage(title: "Complete Compilation", content: """
        \(heading(1, "Core_Guide", "<a href=\"tiki-index.php?page=demo._.Core\" class=\"wiki\">Core&nbsp;Guide</a>"))
        <p>See <a href="tiki-index.php?page=demo._.Making-Heroes#Rules" class="wiki">the rules</a>.</p>
        \(heading(2, "Making_Heroes", "<a href=\"tiki-index.php?page=demo._.Making-Heroes\">Making Heroes</a>"))
        <p><img src="tiki-download_file.php?fileId=7&amp;display&amp;x=360&amp;y=476" /></p>
        <script>alert(1)</script>
        <div class='float-right'><a class="btn" href="/tiki-index.php?page=demo._.All" onclick="g()">No Tabs</a></div>
        <p><a href="tiki-index.php?page=demo._.Handbook">Handbook</a>
        <a href="tiki-index.php?page=demo._.Elsewhere">x</a>
        <a href="https://example.com/a?b=1&amp;c=2">out</a> <a href="mailto:gm@example.com">mail</a>
        <a href="https://lorespire.paizo.com/tiki-download_file.php?fileId=9">Letter</a>
        <img src="img/icons/star.png" /></p>
        """)

    static let handbook = wikiPage(title: "Handbook &amp; More", content: """
        \(heading(1, "Handbook", "Handbook"))
        <p><a href="tiki-index.php?page=demo._.Making-Heroes">heroes</a> <a href="#Handbook">top</a></p>
        """)

    static let documents = [
        LorespireDocument(id: "demo-guide", page: "demo._.All", system: .pathfinder, aliases: ["demo._.Full"]),
        LorespireDocument(id: "demo-handbook", page: "demo._.Handbook", system: .both)
    ]

    static let responses: [String: LorespireResponse] = [
        Lorespire.pageURL("demo._.All").absoluteString: LorespireResponse(data: Data(guide.utf8),
                                                                          contentType: "text/html"),
        Lorespire.pageURL("demo._.Handbook").absoluteString: LorespireResponse(data: Data(handbook.utf8),
                                                                               contentType: "text/html"),
        Lorespire.fileURL(7).absoluteString: LorespireResponse(data: Data([1, 2]), contentType: "image/png"),
        Lorespire.fileURL(9).absoluteString: LorespireResponse(data: Data([3]), contentType: "application/pdf",
                                                               suggestedFileName: "Welcome Letter.pdf")
    ]
}

/// Answers from ``LorespireFixtures/responses``, and 404 for anything else.
struct FakeFetcher: LorespireFetching {
    var responses = LorespireFixtures.responses

    func fetch(_ url: URL) async throws -> LorespireResponse {
        guard let response = responses[url.absoluteString] else {
            throw LorespireError.httpStatus(url: url, status: 404)
        }
        return response
    }
}
