import CoreGraphics
import CoreText
import Foundation
import PDFKit

/// A stretch of a line set in one font.
public struct TextRun: Equatable, Sendable {
    public var text: String
    /// The font's PostScript name, such as "GoodOT-Bold".
    public var font: String
    public var size: CGFloat

    public init(text: String, font: String, size: CGFloat) {
        self.text = text
        self.font = font
        self.size = size
    }

    public var isBold: Bool { font.localizedCaseInsensitiveContains("bold") }
}

/// One line of a page's text, in reading order, with where it is on the page.
public struct TextLine: Equatable, Sendable {
    public var runs: [TextRun]
    public var bounds: CGRect

    public init(runs: [TextRun], bounds: CGRect) {
        self.runs = runs
        self.bounds = bounds
    }

    public var text: String { runs.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The size most of the line's letters are set in.
    public var size: CGFloat {
        let sizes = Dictionary(grouping: runs, by: \.size).mapValues { $0.reduce(0) { $0 + $1.text.count } }
        return sizes.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? 0
    }

    /// The font of the line's first letters.
    public var font: String { runs.first { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }?.font ?? "" }

    /// True when the line starts with a bold run, as a stat line's label does.
    public var startsBold: Bool {
        runs.first { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }?.isBold ?? false
    }
}

/// A word of a page's text and where it is.
public struct TextWord: Equatable, Sendable {
    public var text: String
    public var bounds: CGRect
}

/// Reads a PDF page's text as lines.
public enum PageText {
    /// The page's lines, or those inside `rect`, in the order PDFKit reads them.
    public static func lines(of page: PDFPage, in rect: CGRect? = nil) -> [TextLine] {
        let area = rect ?? page.bounds(for: .mediaBox)
        guard let selection = page.selection(for: area) else { return [] }
        return selection.selectionsByLine().compactMap { line in
            guard let text = line.attributedString, !text.string.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return TextLine(runs: runs(of: text), bounds: line.bounds(for: page))
        }
    }

    /// The page's words matching `pattern`, each with its own bounds. Selecting a range of the page's text gives
    /// exact bounds, unlike `PDFPage.characterBounds(at:)`, which can be a character off.
    public static func words(of page: PDFPage, matching pattern: String) -> [TextWord] {
        guard let string = page.string, let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(string.startIndex..., in: string)
        return expression.matches(in: string, range: range).compactMap { match in
            guard let selection = page.selection(for: match.range), let text = selection.string else { return nil }
            return TextWord(text: text, bounds: selection.bounds(for: page))
        }
    }

    static func runs(of text: NSAttributedString) -> [TextRun] {
        var runs: [TextRun] = []
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { font, range, _ in
            let piece = (text.string as NSString).substring(with: range)
            let (name, size) = describe(font)
            runs.append(TextRun(text: piece, font: name, size: size))
        }
        return runs
    }

    /// The name and size of a font attribute: an `NSFont` on the Mac, a `UIFont` on the iPad, both of them `CTFont`s.
    static func describe(_ font: Any?) -> (String, CGFloat) {
        guard let font, CFGetTypeID(font as CFTypeRef) == CTFontGetTypeID() else { return ("", 0) }
        // The type ID was checked above, so the cast cannot fail.
        let ctFont = font as! CTFont // swiftlint:disable:this force_cast
        return (CTFontCopyPostScriptName(ctFont) as String, CTFontGetSize(ctFont))
    }
}
