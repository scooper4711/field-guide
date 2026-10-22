import CoreGraphics
import CoreText
import Foundation
import PDFKit
import SourcebookLore

/// Builds small PDFs for tests: pieces of text in given fonts at given points, a page at a time.
public struct PDFFixture: Sendable {
    /// A piece of text: runs in their fonts, starting at `origin`, the baseline's left end.
    public struct Piece: Sendable {
        public var runs: [TextRun]
        public var origin: CGPoint

        public init(runs: [TextRun], origin: CGPoint) {
            self.runs = runs
            self.origin = origin
        }
    }

    public static let regular = "Helvetica"
    public static let bold = "Helvetica-Bold"

    public var pageSize = CGSize(width: 600, height: 780)
    public var pages: [[Piece]] = []

    public init(pages: [[Piece]]) {
        self.pages = pages
    }

    /// A piece in one font, its baseline starting at (`left`, `baseline`).
    public static func text(_ text: String, at left: CGFloat, _ baseline: CGFloat, font: String = regular,
                            size: CGFloat = 9) -> Piece {
        Piece(runs: [TextRun(text: text, font: font, size: size)], origin: CGPoint(x: left, y: baseline))
    }

    /// A stat line: a bold label, then its value.
    public static func stat(_ label: String, _ value: String, at left: CGFloat, _ baseline: CGFloat) -> Piece {
        Piece(runs: [TextRun(text: label, font: bold, size: 9), TextRun(text: " " + value, font: regular, size: 9)],
              origin: CGPoint(x: left, y: baseline))
    }

    public func document() -> PDFDocument? {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        for page in pages {
            context.beginPDFPage(nil)
            page.forEach { draw($0, in: context) }
            context.endPDFPage()
        }
        context.closePDF()
        return PDFDocument(data: data as Data)
    }

    private func draw(_ piece: Piece, in context: CGContext) {
        let text = NSMutableAttributedString()
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        for run in piece.runs {
            let font = CTFontCreateWithName(run.font as CFString, run.size, nil)
            text.append(NSAttributedString(string: run.text, attributes: [fontKey: font]))
        }
        context.textPosition = piece.origin
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
}
