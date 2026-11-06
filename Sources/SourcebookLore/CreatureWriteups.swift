import CoreGraphics
import Foundation
import PDFKit

/// Reads creatures' lore from a bestiary such as Monster Core or Alien Core, or an adventure's bestiary. Each
/// creature's stat block opens with its name in capitals and its level ("AAPOPH GRANITESCALE CREATURE 6"); the
/// paragraphs about it come before that, under its name as a heading. A creature in a family has a smaller heading
/// than the family's, whose heading and introduction come earlier ("Serpentfolk", then the history of the
/// serpentfolk).
public struct CreatureWriteups {
    /// A creature's stat block heading and the name it prints.
    struct StatHeading {
        let index: Int
        let name: String
    }

    public init() {}

    /// The lore of each creature found, by the match key of its name (`TextRepair.matchKey`): the books a
    /// creature's lore may come from (a bestiary and its remaster) are matched by name.
    public func writeups(in document: PDFDocument) -> [String: CreatureLore] {
        let lines = (0..<document.pageCount).flatMap { index in
            document.page(at: index).map(Self.contentLines(of:)) ?? []
        }
        return writeups(in: lines)
    }

    /// The lore of each creature found in `lines`, a book's lines in reading order.
    func writeups(in lines: [TextLine]) -> [String: CreatureLore] {
        let section = CreatureSection(lines: lines, bodySize: WriteupReader.bodyFont(of: lines).size)
        let headings = statHeadings(in: lines)
        let starts = headings.indices.map { offset in
            section.heading(of: headings[offset].name, before: headings[offset].index,
                            after: offset > 0 ? headings[offset - 1].index + 1 : 0)
        }
        let named = starts.compactMap { $0 }.filter(\.isNamed)
        let creatureHeight = CreatureSection.creatureHeight(of: named.map { lines[$0.index].bounds.height })
        var writeups: [String: CreatureLore] = [:]
        var read: Set<String> = []
        // A creature printed twice (as the introduction's example, say) takes the stat block under its own heading.
        for (heading, start) in zip(headings, starts) {
            let key = TextRepair.matchKey(heading.name)
            guard let start, !read.contains(key), writeups[key] == nil || start.isNamed else { continue }
            let lore = section.lore(from: start.index, to: heading.index, creatureHeight: creatureHeight)
            guard !lore.isEmpty else { continue }
            writeups[key] = lore
            if start.isNamed { read.insert(key) }
        }
        return writeups
    }

    /// The page's lines without its margins (the page number, the running header and the chapter tabs), in
    /// reading order.
    static func contentLines(of page: PDFPage) -> [TextLine] {
        let box = page.bounds(for: .mediaBox)
        let content = box.insetBy(dx: box.width * 0.1, dy: 0).divided(atDistance: 32, from: .minYEdge).remainder
            .divided(atDistance: box.height * 0.07, from: .maxYEdge).remainder
        let lines = PageText.lines(of: page).filter { content.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
        return ColumnOrder.lines(lines, pageWidth: box.width)
    }

    /// The book's stat block headings. The level may be set on the line after the name.
    func statHeadings(in lines: [TextLine]) -> [StatHeading] {
        lines.indices.compactMap { index in
            Self.statName(at: index, in: lines).map { StatHeading(index: index, name: $0) }
        }
    }

    /// The name a stat block heading prints at `index`, or nil when the line isn't one.
    static func statName(at index: Int, in lines: [TextLine]) -> String? {
        let text = lines[index].text
        guard let range = text.range(of: #"\s*\b(CREATURE|NPC)\s+[–—-]?\d+$"#, options: .regularExpression)
        else { return nil }
        let name = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name == name.uppercased() ? name : nil }
        guard index > 0 else { return nil }
        let previous = lines[index - 1].text
        return previous == previous.uppercased() && previous.contains(where: \.isLetter) ? previous : nil
    }
}

/// Reads one creature's lore from the lines before its stat block.
/// Reads one creature's lore from the lines before its stat block. Headings are told apart by their lines'
/// heights rather than their fonts' sizes: some books' display fonts read back at the body text's size.
struct CreatureSection {
    let lines: [TextLine]
    let bodySize: CGFloat
    /// The height of a line of body text.
    let bodyHeight: CGFloat

    init(lines: [TextLine], bodySize: CGFloat) {
        self.lines = lines
        self.bodySize = bodySize
        let heights = lines.filter { abs($0.size - bodySize) < 0.6 }.map(\.bounds.height).sorted()
        bodyHeight = heights.isEmpty ? bodySize : heights[heights.count / 2]
    }

    /// The creature's paragraphs, from its heading at `start` to its stat block at `end`, and its family's
    /// introduction when its heading is a creature's (`creatureHeight` tall) rather than a family's.
    func lore(from start: Int, to end: Int, creatureHeight: CGFloat) -> CreatureLore {
        let stop = lines[(start + 1)..<end].indices.first(where: isStatHeading) ?? end
        let prose = ParagraphReader(lines: proseLines(from: start + 1, to: stop), bodySize: bodySize)
        var lore = CreatureLore(paragraphs: prose.paragraphs())
        if let family = familyHeading(above: start, creatureHeight: creatureHeight) {
            lore.family = Self.headingText(lines[family])
            let close = lines[(family + 1)...].firstIndex { isHeading($0) } ?? start
            lore.familyParagraphs = ParagraphReader(lines: proseLines(from: family + 1, to: close),
                                                    bodySize: bodySize).paragraphs()
        }
        return lore
    }

    /// Where a creature's prose starts: its heading, and whether the heading names it.
    struct Start {
        let index: Int
        let isNamed: Bool
    }

    /// The heading naming the creature closest above its stat block ("Cassisian (Archive Angel)" names the
    /// cassisian); failing that, the nearest heading between `earliest` and the stat block, for a creature whose
    /// heading names it differently or names its kind ("Adamantine Dragon" for the young adamantine dragon).
    func heading(of name: String, before end: Int, after earliest: Int) -> Start? {
        guard earliest < end else { return nil }
        let key = TextRepair.matchKey(name)
        let candidates = (earliest..<end).filter { isHeading(lines[$0]) && !isStatHeading($0) }
        if let named = candidates.last(where: { Self.headingKey(lines[$0].text) == key }) {
            return Start(index: named, isNamed: true)
        }
        if let nearest = candidates.last { return Start(index: nearest, isNamed: false) }
        // A creature without a heading of its own, such as an adult dragon after the young one, shares the one above.
        let limit = max(0, earliest - 400)
        return stride(from: earliest - 1, through: limit, by: -1)
            .first { isHeading(lines[$0]) && !isStatHeading($0) }
            .map { Start(index: $0, isNamed: false) }
    }

    /// A heading's match key without a parenthetical, such as "(Archive Angel)".
    static func headingKey(_ text: String) -> String {
        TextRepair.matchKey(text.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression))
    }

    /// The height of creatures' headings: the one most headings naming creatures share.
    static func creatureHeight(of headingHeights: [CGFloat]) -> CGFloat {
        let counts = Dictionary(grouping: headingHeights, by: rounded).mapValues(\.count)
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? 0
    }

    /// The nearest heading above `start` taller than a creature's, but not as tall as a chapter's: its family's.
    /// A creature whose own heading is that tall stands alone or opens its family. Looks back a few pages at most.
    func familyHeading(above start: Int, creatureHeight: CGFloat) -> Int? {
        // A book with no headings naming creatures has no creature height to compare with.
        guard creatureHeight * 1.4 > creatureHeight + 0.75 else { return nil }
        let family = (creatureHeight + 0.75)...(creatureHeight * 1.4)
        guard Self.rounded(lines[start].bounds.height) < family.lowerBound else { return nil }
        let limit = max(0, start - 1_000)
        return stride(from: start - 1, through: limit, by: -1).first { index in
            isHeading(lines[index]) && family.contains(Self.rounded(lines[index].bounds.height))
        }
    }

    /// True for a heading: a short line much taller than the body text's.
    func isHeading(_ line: TextLine) -> Bool {
        line.bounds.height >= bodyHeight * 1.35 && line.text.count <= 60 && line.text.contains(where: \.isLetter)
    }

    private func isStatHeading(_ index: Int) -> Bool {
        CreatureWriteups.statName(at: index, in: lines) != nil
    }

    /// A height to the nearest half point, so headings set alike compare equal.
    static func rounded(_ height: CGFloat) -> CGFloat { (height * 2).rounded() / 2 }

    /// The lines of prose between `start` and `end`: those in the body text's size.
    private func proseLines(from start: Int, to end: Int) -> [TextLine] {
        guard start < end else { return [] }
        return lines[start..<end].filter { abs($0.size - bodySize) < 0.6 }
    }

    /// A heading's text, its case repaired when it is set in capitals or a display font.
    static func headingText(_ line: TextLine) -> String {
        let text = line.text
        return text == text.uppercased() ? TextRepair.titleCase(text) : TextRepair.heading(text)
    }
}
