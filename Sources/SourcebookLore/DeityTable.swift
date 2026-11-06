import CoreGraphics
import Foundation
import PDFKit

/// Reads deities' stat lines from a table such as the Divine Mysteries Web Supplement's: a header row of column
/// labels ("DEITY", "TITLE", "EDICTS"…) above a row per deity, its name in the first column. Rows are as tall as
/// their longest cell and the name is centered in its row, so each cell goes to the name nearest its middle.
public struct DeityTable {
    /// The deities to look for, as the catalog spells them.
    public let names: [String]

    public init(names: [String]) {
        self.names = names
    }

    /// The stat lines of each deity found, by its name as `names` spells it.
    public func rows(in document: PDFDocument) -> [String: [StatLine]] {
        var rows: [String: [StatLine]] = [:]
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            rows.merge(self.rows(on: page)) { first, _ in first }
        }
        return rows
    }

    func rows(on page: PDFPage) -> [String: [StatLine]] {
        guard let header = TableHeader(page: page) else { return [:] }
        let columns = header.columns(placing: PageText.lines(of: page).filter { $0.bounds.maxY < header.bottom })
        let cells = columns.map { column in
            Self.blocks(of: PageText.lines(of: page, in: column.area(below: header.bottom)).filter { !$0.startsBold })
                .map { Self.ordered($0, on: page) }
        }
        guard let nameBlocks = cells.first else { return [:] }
        let rowNames = nameBlocks.map(name(of:))
        var rows: [String: [StatLine]] = [:]
        for (column, blocks) in zip(columns, cells).dropFirst() {
            for block in blocks {
                guard let row = Self.nearest(block, among: nameBlocks), let name = rowNames[row] else { continue }
                rows[name, default: []].append(StatLine(label: column.label, text: Self.text(of: block)))
            }
        }
        return rows
    }

    /// The deity a name cell holds, as `names` spells it.
    private func name(of block: [TextLine]) -> String? {
        let key = TextRepair.matchKey(Self.text(of: block))
        return names.first { TextRepair.matchKey($0) == key }
    }

    /// A column's lines grouped into cells: a gap wider than a line's spacing starts another cell. The lines keep
    /// PDFKit's reading order; the bounds of a cell's wrapped lines overlap, so sorting them could swap them.
    static func blocks(of lines: [TextLine]) -> [[TextLine]] {
        var blocks: [[TextLine]] = []
        for line in lines {
            if let last = blocks.last?.last, abs(last.bounds.minY - line.bounds.minY) <= 1.6 * max(line.size, 4) {
                blocks[blocks.count - 1].append(line)
            } else {
                blocks.append([line])
            }
        }
        return blocks
    }

    /// A cell's lines from top to bottom. The bounds PDFKit gives a cell's wrapped lines reach up into the line
    /// above, and its reading order sometimes puts a line first that comes second, so each line is placed by the
    /// bottom of its first word, which selecting that range of the page's text gives exactly. Where PDFKit puts two
    /// lines at the same height, the one starting with a capital comes first: cells are written in sentence case.
    static func ordered(_ block: [TextLine], on page: PDFPage) -> [TextLine] {
        guard block.count > 1 else { return block }
        let bottoms = block.map { line in firstWordBottom(of: line, on: page) ?? line.bounds.minY }
        return zip(block, bottoms).sorted { first, second in
            if abs(first.1 - second.1) > 1 { return first.1 > second.1 }
            return startsCapitalized(first.0) && !startsCapitalized(second.0)
        }.map(\.0)
    }

    private static func startsCapitalized(_ line: TextLine) -> Bool {
        line.text.first?.isUppercase ?? false
    }

    private static func firstWordBottom(of line: TextLine, on page: PDFPage) -> CGFloat? {
        guard let word = line.text.split(separator: " ").first else { return nil }
        let near = line.bounds.insetBy(dx: -2, dy: -line.size * 1.5)
        let candidates = PageText.words(of: page, matching: NSRegularExpression.escapedPattern(for: String(word)))
            .filter { near.contains(CGPoint(x: $0.bounds.minX + 1, y: $0.bounds.midY)) }
        return candidates.min { abs($0.bounds.minX - line.bounds.minX) < abs($1.bounds.minX - line.bounds.minX) }?
            .bounds.minY
    }

    /// The index of the name cell whose middle is nearest the cell's.
    static func nearest(_ block: [TextLine], among names: [[TextLine]]) -> Int? {
        let middle = Self.middle(of: block)
        return names.indices.min { abs(Self.middle(of: names[$0]) - middle) < abs(Self.middle(of: names[$1]) - middle) }
    }

    private static func middle(of block: [TextLine]) -> CGFloat {
        guard let top = block.first?.bounds.maxY, let bottom = block.last?.bounds.minY else { return 0 }
        return (top + bottom) / 2
    }

    /// A cell's text, without the dagger and asterisk marks that point to Divine Mysteries.
    static func text(of block: [TextLine]) -> String {
        TextRepair.join(block.map(\.text)).replacingOccurrences(of: "†", with: "")
            .replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
    }
}
