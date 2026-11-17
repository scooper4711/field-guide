import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import SourcebookLore
import SourcebookLoreTestSupport

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

/// Lines beside pictures, which PDFKit reads with object replacement characters in them.
@Suite struct PageTextPictureTests {
    @Test func textRangesSkipThePictureCharacters() {
        let text = "ab\u{FFFC}cd\u{FFFC}\u{FFFC}e\u{FFFC}" as NSString
        let ranges = PageText.textRanges(in: NSRange(location: 0, length: text.length), of: text)
        #expect(ranges.map { text.substring(with: $0) } == ["ab", "cd", "e"])
        #expect(PageText.textRanges(in: NSRange(location: 1, length: 2), of: text).map { text.substring(with: $0) }
            == ["b"])
        #expect(PageText.textRanges(in: NSRange(location: 2, length: 1), of: text).isEmpty)
        #expect(PageText.textRanges(in: NSRange(location: 8, length: 5), of: text).isEmpty)
    }

    @Test func aPictureIsReadWithoutItsAttachment() throws {
        let page = try #require(Self.pageWithPicture())
        let pageText = try #require(page.string as NSString?)
        // macOS 26's PDFKit (GitHub's runners) doesn't read a tagged picture as a picture character, so there is
        // nothing to leave out; macOS 27's does. Checked here, not in a trait: building a PDF while Swift Testing
        // plans the run crashed the test process on macOS 26.
        guard pageText.contains(PageText.pictureCharacter) else { return }
        let lines = try #require(page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine())
        let pieces = lines.flatMap { PageText.textSelections(of: $0, on: page, pageText: pageText) }
        #expect(!pieces.contains { $0.string?.contains(PageText.pictureCharacter) == true })
        let picture = try #require(lines.first { $0.string?.contains(PageText.pictureCharacter) == true })
        #expect(PageText.textSelections(of: picture, on: page, pageText: nil).isEmpty)
        let read = PageText.lines(of: page)
        #expect(read.map(\.text) == ["Beside the art"])
        #expect(read.flatMap(\.runs).allSatisfy { $0.font == PDFFixture.regular && $0.size == 9 })
    }

    @Test func aLineWithoutPicturesIsOneSelection() throws {
        let fixture = PDFFixture(pages: [[PDFFixture.text("Plain text", at: 72, 400)]])
        let page = try #require(fixture.document()?.page(at: 0))
        let line = try #require(page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine().first)
        #expect(PageText.textSelections(of: line, on: page, pageText: page.string as NSString?) == [line])
        #expect(PageText.textSelections(of: line, on: page, pageText: nil) == [line])
    }

    /// A tagged page with a line of text beside a picture.
    static func pageWithPicture() -> PDFPage? {
        guard let image = image() else { return nil }
        var fixture = PDFFixture(pages: [[PDFFixture.text("Beside the art", at: 72, 400)]],
                                 pictures: [0: [PDFFixture.Picture(image: image, rect: CGRect(x: 250, y: 500,
                                                                                              width: 60, height: 30))]])
        fixture.isTagged = true
        return fixture.document()?.page(at: 0)
    }

    /// A small gray square.
    static func image() -> CGImage? {
        let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        context?.setFillColor(gray: 0.5, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return context?.makeImage()
    }
}
