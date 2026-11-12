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

    /// A picture drawn into `rect`, as a book's art is.
    public struct Picture: @unchecked Sendable {
        public var image: CGImage
        public var rect: CGRect

        public init(image: CGImage, rect: CGRect) {
            self.image = image
            self.rect = rect
        }
    }

    public var pageSize = CGSize(width: 600, height: 780)
    public var pages: [[Piece]] = []
    /// The pictures on each page, by the page's index; drawn before its text.
    public var pictures: [Int: [Picture]] = [:]
    /// Paizo's Pathfinder-Icons font file: runs in `ActionIcon.fontName` are drawn with it, and it goes into the
    /// PDF whole and unaltered (`ActionIconEmbedder`).
    public var actionIcons: Data?

    public init(pages: [[Piece]], pictures: [Int: [Picture]] = [:]) {
        self.pages = pages
        self.pictures = pictures
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
        data().flatMap(PDFDocument.init(data:))
    }

    /// The PDF file; nil when it couldn't be drawn, or the action icons' font couldn't be put into it.
    public func data() -> Data? {
        let icons = actionIcons.flatMap { CGDataProvider(data: $0 as CFData) }.flatMap(CGFont.init)
        if actionIcons != nil, icons == nil { return nil }
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        for (index, page) in pages.enumerated() {
            context.beginPDFPage(nil)
            pictures[index, default: []].forEach { context.draw($0.image, in: $0.rect) }
            page.forEach { draw($0, in: context, icons: icons) }
            context.endPDFPage()
        }
        context.closePDF()
        guard let actionIcons else { return data as Data }
        return ActionIconEmbedder(font: actionIcons).embedding(in: data as Data)
    }

    private func draw(_ piece: Piece, in context: CGContext, icons: CGFont?) {
        let text = NSMutableAttributedString()
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        for run in piece.runs {
            let font = if let icons, run.font == ActionIcon.fontName {
                CTFontCreateWithGraphicsFont(icons, run.size, nil, nil)
            } else {
                CTFontCreateWithName(run.font as CFString, run.size, nil)
            }
            text.append(NSAttributedString(string: run.text, attributes: [fontKey: font]))
        }
        context.textPosition = piece.origin
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
}
