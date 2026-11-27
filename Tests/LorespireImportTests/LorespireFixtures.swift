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

    static func pageHeading(_ level: Int, _ id: String, page: String, _ title: String) -> String {
        heading(level, id, "<a href=\"tiki-index.php?page=\(page)\" class=\"wiki\">\(title)</a>")
    }

    /// A compilation: a title and version, two parts, pages inside pages, an unlinked section, an empty page, a
    /// tab set, a footnote and an image.
    static let compilation = """
        \(heading(1, "Title", "Demo Guide"))
        <p>Single Page Layout
        </p>
        <p><strong>Version 2</strong></p>
        \(pageHeading(1, "Intro", page: "demo._.Intro", "Intro"))
        <p>Welcome.</p>
        \(heading(2, "Basics", "Basics"))
        <p>Basic text.</p>
        \(pageHeading(2, "Heroes", page: "demo._.Making-Heroes", "Making&nbsp;Heroes"))
        <p>See <a href="tiki-index.php?page=demo._.Intro#Basics">the basics</a> and <a href="#Tail">the tail</a>.</p>
        <p><a href="#Deep">deep</a></p>
        \(pageHeading(3, "Empty", page: "demo._.Empty", "Empty"))
        <p>
        </p>
        \(pageHeading(3, "Rules", page: "demo._.Rules", "Rules"))
        <p>Rule one.<a id="mo1-link"  class="plugin-mouseover-anchor"><sup>CRB</sup></a><span id="mo1" \
        class="plugin-mouseover" style="width: 400px;"><a href="https://example.com/crb">Core</a><br />\
        <em>p. 4</em><br />(click to close)</span></p>
        \(heading(4, "Deep", "Deep"))
        <p>Deep text. <a href="#Deep">here</a> <a href="tiki-index.php?page=demo._.Full#Deep">again</a></p>
        \(heading(2, "Tail", "Tail"))
        <p>Tail text.</p>
        \(pageHeading(1, "Two", page: "demo._.Two", "Part Two"))
        <div class="clearfix tabs" data-name="t"><ul class="nav nav-tabs"><li class="nav-item">\
        <a class="nav-link active show" href="#contentt-1" data-toggle="tab">First </a></li><li class="nav-item">\
        <a class="nav-link " href="#contentt-2" data-toggle="tab"> Second</a></li></ul></div>\
        <div class="tab-content"><div id='contentt-1' class='tab-pane pt-3 active show'><p>One.</p></div>\
        <div id='contentt-2' class='tab-pane pt-3 '><div class="table-responsive"><div class="ts-wrapperdiv">\
        <table class="table table-striped" id="t1"><tr><td style="width: 20%" rowspan="2">Two.</td></tr></table>\
        </div></div></div></div>
        <div class="card bg-light"><div class="card-header">Note</div><div class="card-body"><p>Careful.</p></div></div>
        <p><img src="tiki-download_file.php?fileId=7&amp;display&amp;x=360" alt="Chart" class="regImage" /></p>
        """

    static let handbookCompilation = """
        \(heading(1, "Book", "Book"))
        \(pageHeading(2, "Start", page: "demo._.Book-Start", "1. Start"))
        <p>Go to <a href="tiki-index.php?page=demo._.Rules">the rules</a>, \
        <a href="tiki-index.php?page=demo._.Gone">a page not downloaded</a> and \
        <a href="tiki-download_file.php?fileId=9">a letter</a>.</p>
        \(heading(2, "Appendix", "2. Appendix"))
        <p>More.</p>
        """

    static let licenses = """
        <h3 id="Trademarks">Trademarks</h3>
        <p>Demo © Someone; <strong>all</strong> <em>rights</em>.
        </p>
        <ol><li> First <a href="https://example.com">term</a>
        </li><li> Second<br />line
        </li></ol><ul><li>Dot</li></ul>
        """

    static let libraryDocuments = [
        LorespireDocument(id: "demo", page: "demo._.All", system: .pathfinder, aliases: ["demo._.Full"]),
        LorespireDocument(id: "other", page: "other._.All", system: .starfinder),
        LorespireDocument(id: "book", page: "demo._.Book", system: .both, part: "Handbook"),
        LorespireDocument(id: "licenses", page: "demo._.Licenses", system: .both, isGuide: false)
    ]

    /// A download of ``libraryDocuments`` in a new temporary folder.
    static func library() throws -> LorespireLibrary {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lorespire-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("files"),
                                                withIntermediateDirectories: true)
        let contents = ["demo": compilation, "other": pageHeading(1, "O", page: "other._.O", "Other") + "<p>O.</p>",
                        "book": handbookCompilation, "licenses": licenses]
        for (id, html) in contents { try Data(html.utf8).write(to: folder.appendingPathComponent(id + ".html")) }
        for name in ["7.png", "9-welcome-letter.pdf", ".DS_Store"] {
            try Data([1]).write(to: folder.appendingPathComponent("files/" + name))
        }
        return LorespireLibrary(folder: folder, documents: libraryDocuments)
    }

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
