import CoreGraphics
import Foundation
import PDFKit

/// Reads deities' write-ups from a book such as Divine Mysteries: the deity's name as a large heading, its title in
/// capitals, its stat lines ("Edicts", "Anathema"…), then its prose up to the next heading as large.
public struct DeityWriteups {
    /// The deities to look for, as the catalog spells them.
    public let names: [String]

    public init(names: [String]) {
        self.names = names
    }

    /// The write-up of each deity found, by its name as `names` spells it.
    public func writeups(in document: PDFDocument) -> [String: DeityLore] {
        let lines = (0..<document.pageCount).flatMap { index in
            document.page(at: index).map(Self.contentLines(of:)) ?? []
        }
        let bodySize = WriteupReader.bodyFont(of: lines).size
        var writeups: [String: DeityLore] = [:]
        let headings = headings(in: lines, bodySize: bodySize)
        for (offset, (start, name)) in headings.enumerated() where writeups[name] == nil {
            let next = offset + 1 < headings.count ? headings[offset + 1].0 : lines.endIndex
            let section = Self.section(of: lines[..<next], from: start, bodySize: bodySize)
            let lore = WriteupReader(lines: section, names: names).read()
            if !lore.isEmpty { writeups[name] = lore }
        }
        return writeups
    }

    /// The headings that name a deity, with where they are in `lines`: a major deity's name is set large, a minor
    /// one's in smaller capitals, both well above the body text's size; Starfinder Player Core sets its deities' names
    /// in capitals only a little larger.
    func headings(in lines: [TextLine], bodySize: CGFloat) -> [(Int, String)] {
        lines.indices.compactMap { index in
            let line = lines[index]
            let isCapitals = line.text == line.text.uppercased()
            guard line.size >= bodySize * (isCapitals ? 1.15 : 1.4), let name = name(of: line.text) else { return nil }
            return (index, name)
        }
    }

    /// The deity a heading names: the name it spells, else the one name it shortens or lengthens ("Nivi" for
    /// "Nivi Rhombodazzle", "Chaldira Zuzaristan" for "Chaldira").
    func name(of text: String) -> String? {
        let key = TextRepair.matchKey(text)
        guard key.count >= 4 else { return nil }
        if let name = names.first(where: { TextRepair.matchKey($0) == key }) { return name }
        let near = names.filter { name in
            let other = TextRepair.matchKey(name)
            return other.count >= 4 && (other.hasPrefix(key) || key.hasPrefix(other))
        }
        return near.count == 1 ? near[0] : nil
    }

    /// The lines after the heading at `start`, up to the next deity's heading (where `lines` ends) or the next
    /// heading about as large, such as a chapter's: a major deity's section runs past its own subheadings.
    static func section(of lines: ArraySlice<TextLine>, from start: Int, bodySize: CGFloat) -> [TextLine] {
        let size = lines[start].size
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.size >= size * 0.9 && $0.size > bodySize * 1.1 } ?? lines.endIndex
        return Array(lines[(start + 1)..<end])
    }

    /// The page's lines without its margins: the page number at the foot and the chapter tabs at the outer edge.
    static func contentLines(of page: PDFPage) -> [TextLine] {
        let box = page.bounds(for: .mediaBox)
        let content = box.insetBy(dx: box.width * 0.1, dy: 0).divided(atDistance: 32, from: .minYEdge).remainder
        let lines = PageText.lines(of: page).filter { content.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
        return readingOrder(of: lines, pageWidth: box.width)
    }

    /// The lines in reading order, which PDFKit's isn't always (Starfinder Player Core reads a deity's stat lines
    /// before its heading): a line across both columns is a band of its own; between them, the left column is read
    /// top to bottom, then the right.
    static func readingOrder(of lines: [TextLine], pageWidth: CGFloat) -> [TextLine] {
        var ordered: [TextLine] = []
        var band: [TextLine] = []
        func closeBand() {
            ordered += band.sorted { first, second in
                let (left, right) = (first.bounds.midX < pageWidth / 2, second.bounds.midX < pageWidth / 2)
                return left != right ? left : first.bounds.maxY > second.bounds.maxY
            }
            band = []
        }
        for line in lines.sorted(by: { $0.bounds.maxY > $1.bounds.maxY }) {
            if line.bounds.width > pageWidth * 0.55 {
                closeBand()
                ordered.append(line)
            } else {
                band.append(line)
            }
        }
        closeBand()
        return ordered
    }
}
