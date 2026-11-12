import Foundation
import PDFKit
import Testing
@testable import SourcebookLoreTestSupport
@testable import SourcebookLore

/// The sample's action icons: plain symbols, or Paizo's Pathfinder-Icons font when the sample is given it. The font
/// is in the private Artwork submodule, so the tests that need it are skipped without that.
@Suite struct ActionIconTests {
    static let font = try? Data(contentsOf: URL(filePath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Artwork/pathfinder-icons/Pathfinder-Icons.ttf"))

    @Test func actionSymbolsBecomeRunsInTheIconsFont() {
        let run = TextRun(text: " ◆◆◆ Frequency ◆◆ or ◆, ◇ and ⤾", font: PDFFixture.regular, size: 9)
        let runs = ActionIcon.runs(of: run)
        #expect(runs.map(\.text) == [" ", "\u{E900}", " Frequency ", "\u{E901}", " or ", "\u{E902}", ", ", "\u{E903}",
                                     " and ", "\u{E904}"])
        let fonts = Array(repeating: [PDFFixture.regular, ActionIcon.fontName], count: 5).flatMap { $0 }
        #expect(runs.map(\.font) == fonts)
        #expect(ActionIcon.runs(of: TextRun(text: "Perception +2", font: PDFFixture.bold, size: 9)).count == 1)
        #expect(ActionIcon.allCases.map(\.token) == ["[three-actions]", "[two-actions]", "[one-action]",
                                                     "[free-action]", "[reaction]"])
    }

    @Test func aSampleWithoutTheFontPrintsPlainSymbols() throws {
        let text = try #require(SampleSourcebook.pathfinder.document()?.string)
        #expect(text.contains("Melee ◆ dogslicer") && text.contains("Shield Block ⤾"))
        #expect(!text.contains("Compatibility License"))
    }

    /// The font file is in the PDF byte for byte, not the cut-down copy CoreGraphics makes, and the icons read back
    /// as they do from Paizo's books, which is what Pluck turns into action codes.
    @Test(.enabled(if: font != nil), arguments: SampleSourcebook.all.map(\.title))
    func aSampleWithTheFontHoldsItWholeAndReadsBackAsPaizosBooksDo(title: String) throws {
        let font = try #require(Self.font)
        var sample = try #require(SampleSourcebook.all.first { $0.title == title })
        sample.actionIcons = font
        let data = try #require(sample.data())
        #expect(data.range(of: font) != nil)
        #expect(data.range(of: Data("+\(ActionIcon.fontName)".utf8)) == nil)
        let document = try #require(PDFDocument(data: data))
        let text = try #require(document.string)
        #expect(text.contains("Melee [one-action] ") && text.contains(" [reaction]"))
        #expect(!text.contains("◆") && !text.contains("⤾") && !text.contains("\u{E902}"))
        // The license's paragraph, word for word (the page breaks its lines).
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(words.contains(SampleSourcebook.actionIconsNotice))
        let creatures = CreatureWriteups().writeups(in: document)
        for creature in sample.creatures {
            let lore = try #require(creatures[TextRepair.matchKey(creature.name)], "\(creature.name)")
            #expect(lore.paragraphs.first?.hasPrefix(SampleSourcebook.marker) == true, "\(creature.name)")
        }
    }

    @Test(.enabled(if: font != nil)) func everyIconReadsBackAsItsOwnText() throws {
        let symbols = ActionIcon.allCases.map(\.rawValue).joined(separator: " x ")
        var writer = SampleSourcebook.PageWriter(top: 700, drawsIcons: true)
        writer.statLine("Icons", symbols)
        var fixture = PDFFixture(pages: [writer.pieces])
        fixture.actionIcons = Self.font
        let text = try #require(fixture.document()?.string)
        #expect(text.contains("Icons " + ActionIcon.allCases.map(\.token).joined(separator: " x ")))
    }

    @Test func aPDFThatDrawsNoIconsIsLeftAsItWas() throws {
        let pdf = try #require(PDFFixture(pages: [[PDFFixture.text("No icons here", at: 60, 700)]]).data())
        #expect(ActionIconEmbedder(font: Data()).embedding(in: pdf) == pdf)
    }

    @Test func whatIsNotAPDFOrNotAFontIsRefused() {
        #expect(ActionIconEmbedder(font: Data()).embedding(in: Data("not a PDF".utf8)) == nil)
        var fixture = PDFFixture(pages: [[PDFFixture.text("\u{E902}", at: 60, 700, font: ActionIcon.fontName)]])
        fixture.actionIcons = Data("not a font".utf8)
        #expect(fixture.data() == nil)
    }

    /// Taking a PDF apart and writing it again keeps every object, so it still opens and reads the same.
    @Test func aPDFTakenApartGoesBackTogether() throws {
        let pdf = try #require(SampleSourcebook.starfinder.data())
        let file = try #require(PDFFile(pdf))
        let rewritten = try #require(PDFDocument(data: file.data))
        #expect(rewritten.string == PDFDocument(data: pdf)?.string)
        #expect(PDFFile(file.data)?.objects == file.objects)
        #expect(file.text(of: file.size + 1).isEmpty && file.stream(of: file.size + 1) == nil)
    }
}
