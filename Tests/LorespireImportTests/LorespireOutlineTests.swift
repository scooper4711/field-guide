import Foundation
import Testing
@testable import LorespireImport

@Suite("Lorespire outline")
struct LorespireOutlineTests {
    let sections = LorespireOutline(document: LorespireFixtures.libraryDocuments[0],
                                    content: LorespireFixtures.compilation).sections

    func section(_ key: String) throws -> LorespireSection {
        try #require(sections.first { $0.key == key })
    }

    @Test("Each linked heading starts a page; the parts are the top-level pages")
    func pages() {
        #expect(sections.map(\.key) == ["demo._.Intro", "demo._.Making-Heroes", "demo._.Rules", "demo._.Two"])
        #expect(sections.map(\.name) == ["Intro", "Making Heroes", "Rules", "Part Two"])
        #expect(sections.map(\.part) == ["Intro", "Intro", "Intro", "Part Two"])
        #expect(sections.map(\.level) == [1, 2, 3, 1])
    }

    @Test("A page keeps its unlinked sections, the text after its pages, and a link where each page was")
    func ownContent() throws {
        let intro = try section("demo._.Intro")
        for kept in ["Version 2", "Welcome.", "Basic text.", "Tail text.",
                     "<a href=\"tiki-index.php?page=demo._.All#Heroes\">Making Heroes</a>"] {
            #expect(intro.html.contains(kept), "\(kept)")
        }
        for gone in ["Demo Guide", "Single Page Layout", "Rule one.", "See "] {
            #expect(!intro.html.contains(gone), "\(gone)")
        }
        #expect(intro.headingIDs == ["Intro", "Basics", "Tail"])
    }

    @Test("A page without text of its own is left out, and links to it open the next page")
    func emptyPage() throws {
        let rules = try section("demo._.Rules")
        #expect(rules.aliases == ["demo._.Empty"])
        #expect(rules.headingIDs == ["Rules", "Deep", "Empty"])
        #expect(try section("demo._.Making-Heroes").html.contains("page=demo._.All#Empty\">Empty</a>"))
    }

    @Test("Unlinked headings at the top pages' level are pages too, keyed by the document and heading")
    func unlinkedTopLevel() {
        let book = LorespireOutline(document: LorespireFixtures.libraryDocuments[2],
                                    content: LorespireFixtures.handbookCompilation).sections
        #expect(book.map(\.key) == ["demo._.Book-Start", "demo._.Book.Appendix"])
        #expect(book.map(\.part) == ["Handbook", "Handbook"])
    }

    @Test("A document without linked headings has no pages")
    func noPages() {
        #expect(LorespireOutline(document: LorespireFixtures.libraryDocuments[0],
                                 content: LorespireFixtures.heading(1, "A", "A") + "<p>x</p>").sections.isEmpty)
    }
}

@Suite("Lorespire markup")
struct LorespireMarkupTests {
    let two = LorespireMarkup.simplify(LorespireFixtures.compilation)

    @Test("Tabs become headed sections, cards asides, and the wrappers, classes and styles go")
    func structure() {
        #expect(two.contains("<h6 class=\"tab\">First</h6><p>One.</p><h6 class=\"tab\">Second</h6>"))
        #expect(two.contains("<table id=\"t1\"><tr><td rowspan=\"2\">Two.</td></tr></table>"))
        #expect(two.contains("<aside><p class=\"card-title\">Note</p><p>Careful.</p></aside>"))
        for gone in ["<div", "</div>", "nav-tabs", "style=", "class=\"wiki", "regImage", "<span", "data-toggle"] {
            #expect(!two.contains(gone), "\(gone)")
        }
    }

    @Test("Footnotes show inline, in parentheses")
    func footnotes() {
        #expect(two.contains("Rule one.<small>(<a href=\"https://example.com/crb\">Core</a>; <em>p. 4</em>)</small>"))
        #expect(!two.contains("click to close") && !two.contains("CRB"))
    }

    @Test("Empty paragraphs and line breaks that open a paragraph go")
    func paragraphs() {
        #expect(LorespireMarkup.simplify("<p>\n</p><p><br />\n<br />Text</p>") == "<p>Text</p>")
    }

    @Test("Headings move up so a page's first sub-headings are h2")
    func headings() {
        #expect(LorespireLibrary.shiftingHeadings("<h4 id=\"a\">A</h4><h6>B</h6><h3>C</h3>", below: 3)
            == "<h2 id=\"a\">A</h2><h4>B</h4><h2>C</h2>")
    }
}
