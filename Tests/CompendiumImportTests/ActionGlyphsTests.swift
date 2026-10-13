import Testing
@testable import CompendiumImport

@Suite("Action glyphs")
struct ActionGlyphsTests {
    func span(_ character: String) -> String { "<span class=\"action-glyph\">\(character)</span>" }

    @Test("The pf2e font's letters become Pathfinder-Icons code points", arguments: [
        ("1", "\u{E902}"), ("a", "\u{E902}"), ("A", "\u{E902}"), ("2", "\u{E901}"), ("d", "\u{E901}"),
        ("D", "\u{E901}"), ("3", "\u{E900}"), ("t", "\u{E900}"), ("T", "\u{E900}"), ("f", "\u{E903}"),
        ("F", "\u{E903}"), ("4", "\u{E903}"), ("r", "\u{E904}"), ("R", "\u{E904}"), ("5", "\u{E904}"),
        ("\u{E901}", "\u{E901}")
    ])
    func letters(letter: String, character: String) {
        #expect(ActionGlyphs.html(letter) == span(character))
    }

    @Test("Ranges keep their separators as text, and spaces stay put")
    func ranges() {
        #expect(ActionGlyphs.html("1 – 3") == span("\u{E902}") + " – " + span("\u{E900}"))
        #expect(ActionGlyphs.html("A ") == span("\u{E902}") + " ")
        #expect(ActionGlyphs.html("x<") == "x&lt;")
    }

    @Test("Foundry's spans are rewritten, and rewriting again changes nothing")
    func spans() {
        let foundry = "<p>Strike <span class=\"action-glyph\">A</span> or <span class=\"action-glyph\">2 / 3</span></p>"
        let converted = ActionGlyphs.convertSpans(in: foundry)
        #expect(converted == "<p>Strike \(span("\u{E902}")) or \(span("\u{E901}")) / \(span("\u{E900}"))</p>")
        #expect(ActionGlyphs.convertSpans(in: converted) == converted)
        #expect(ActionGlyphs.convertSpans(in: "<p>No icons</p>") == "<p>No icons</p>")
    }
}
