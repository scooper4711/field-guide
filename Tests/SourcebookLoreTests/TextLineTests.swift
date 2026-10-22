import CoreGraphics
import Testing
@testable import SourcebookLore

@Suite struct TextLineTests {
    static let line = TextLine(runs: [
        TextRun(text: " ", font: "Helvetica", size: 14),
        TextRun(text: "Edicts", font: "GoodOT-Bold", size: 9),
        TextRun(text: " follow the rule of law", font: "GoodOT", size: 9)
    ], bounds: CGRect(x: 72, y: 600, width: 200, height: 10))

    @Test func describesItsRunsFontsAndSizes() {
        #expect(Self.line.text == "Edicts follow the rule of law")
        #expect(Self.line.size == 9)
        #expect(Self.line.font == "GoodOT-Bold")
        #expect(Self.line.startsBold)
        #expect(TextRun(text: "x", font: "TimesNewRomanPS-BoldMT", size: 9).isBold)
        #expect(!TextRun(text: "x", font: "GoodOT", size: 9).isBold)
    }

    @Test func anEmptyLineHasNoFontOrSize() {
        let empty = TextLine(runs: [], bounds: .zero)
        #expect(empty.text.isEmpty && empty.size == 0 && empty.font.isEmpty && !empty.startsBold)
        #expect(PageText.describe(nil) == ("", 0))
        #expect(PageText.describe("not a font") == ("", 0))
    }
}
