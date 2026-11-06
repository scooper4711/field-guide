import CoreGraphics
import Foundation
import PDFKit

/// Reads ancestries' and classes' Details from a book such as Player Core: the name as a chapter-sized heading
/// ("ELF", "FIGHTER"), an introduction, then sections under smaller headings ("Society", "You might...", "During
/// combat encounters..."), up to the next section-sized heading ("Elf Heritages", "Class Features"), where the rules
/// begin. Boxes of rules set under headings in capitals ("KEY ATTRIBUTE", "INITIAL PROFICIENCIES") are left out:
/// the entry's overview shows them.
public struct DetailsWriteups {
    /// The ancestries and classes to look for, as the catalog spells them.
    public let names: [String]

    public init(names: [String]) {
        self.names = names
    }

    /// The Details of each ancestry or class found, by its name as `names` spells it.
    public func writeups(in document: PDFDocument) -> [String: DetailsLore] {
        let lines = (0..<document.pageCount).flatMap { index in
            document.page(at: index).map(Self.contentLines(of:)) ?? []
        }
        return writeups(in: lines)
    }

    func writeups(in lines: [TextLine]) -> [String: DetailsLore] {
        let reader = DetailsSectionReader(lines: lines)
        var writeups: [String: DetailsLore] = [:]
        for name in names {
            // Of the titles naming it (a book may also have a creature of that name), the one with most sections
            // of the Details' own, then the tallest.
            let candidates = reader.titles(of: name).map { (start: $0, lore: reader.lore(of: name, from: $0)) }
            let best = candidates.max { first, second in
                (Self.loreSectionCount(first.lore), lines[first.start].bounds.height)
                    < (Self.loreSectionCount(second.lore), lines[second.start].bounds.height)
            }
            if let lore = best?.lore, !lore.isEmpty { writeups[name] = lore }
        }
        return writeups
    }

    static func loreSectionCount(_ lore: DetailsLore) -> Int {
        lore.sections.filter { DetailsSectionReader.isLoreHeading($0.heading) }.count
    }

    /// The page's lines without its margins: the page number, the running header and the chapter tabs, which
    /// Player Core sets a little further in than the bestiaries do.
    static func contentLines(of page: PDFPage) -> [TextLine] {
        let box = page.bounds(for: .mediaBox)
        let content = box.insetBy(dx: box.width * 0.12, dy: 0).divided(atDistance: 32, from: .minYEdge).remainder
            .divided(atDistance: box.height * 0.05, from: .maxYEdge).remainder
        let lines = PageText.lines(of: page).filter { content.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)) }
        return ColumnOrder.lines(lines, pageWidth: box.width)
    }
}

/// Reads one ancestry's or class's Details from a book's lines. Headings are told by their lines' heights, relative
/// to the body text's: a chapter title is at least 1.6 times as tall, a section heading at least 1.47 times, a
/// subheading at least 1.2 times.
struct DetailsSectionReader {
    static let titleRatio: CGFloat = 1.6
    static let sectionRatio: CGFloat = 1.47
    static let subheadingRatio: CGFloat = 1.2
    /// Headings are short; a taller line of a long sentence is an introduction set large.
    static let headingLength = 40

    let lines: [TextLine]
    let bodySize: CGFloat
    let bodyHeight: CGFloat

    init(lines: [TextLine]) {
        self.lines = lines
        let section = CreatureSection(lines: lines, bodySize: WriteupReader.bodyFont(of: lines).size)
        bodySize = section.bodySize
        bodyHeight = section.bodyHeight
    }

    /// The chapter-sized headings naming `name`; failing those, the section-sized ones, as a book that introduces
    /// one ancestry sets its title ("Jotunborn" in Battlecry!).
    func titles(of name: String) -> [Int] {
        let key = TextRepair.matchKey(name)
        let named = lines.indices.filter { index in
            ratio(of: lines[index]) >= Self.sectionRatio && isShort(lines[index])
                && CreatureSection.headingKey(lines[index].text) == key
        }
        let titles = named.filter { ratio(of: lines[$0]) >= Self.titleRatio }
        return titles.isEmpty ? named : titles
    }

    /// The headings of the Details' sections, as Paizo's books name them; a heading in capitals is one of these or
    /// a box of rules.
    static let loreHeadings = "^(" + [
        "you might", "others (probably|might)", "physical description", "society", "(sample )?names", "beliefs",
        "adventurers", "alignments? and religion", "ethnicities", "roleplaying .*", "during (combat|social) encounters",
        "while exploring", "in downtime", ".+ origins", ".+ of the inner sea"
    ].joined(separator: "|") + #")(\.\.\.|…)?$"#

    /// The Details of `name` from the title at `start` to where its rules begin.
    func lore(of name: String, from start: Int) -> DetailsLore {
        let end = end(of: name, after: start)
        // Each heading opens a section; one over a box of rules is read but dropped.
        var sections = [(section: DetailsSection(), isRules: false)]
        var lines: [TextLine] = []
        func close() {
            sections[sections.count - 1].section.paragraphs = DetailsParagraphs(lines: lines, bodySize: bodySize).read()
            lines = []
        }
        for line in self.lines[(start + 1)..<end] {
            if ratio(of: line) >= Self.subheadingRatio, isShort(line) {
                close()
                sections.append((DetailsSection(heading: Self.headingText(line)), Self.isRulesHeading(line)))
            } else if abs(line.size - bodySize) < 0.6, !Self.isCapitals(line) {
                lines.append(line)
            }
        }
        close()
        return DetailsLore(sections: Self.loreSections(of: sections))
    }

    /// The sections that are lore: not boxes of rules, and none after the last one with a heading the Details use,
    /// where a book that sets no section-sized heading before its rules begins them ("Rarity", "Hit Points").
    static func loreSections(of sections: [(section: DetailsSection, isRules: Bool)]) -> [DetailsSection] {
        let last = sections.lastIndex { $0.section.heading.isEmpty || isLoreHeading($0.section.heading) } ?? 0
        return sections[...last].filter { !$0.isRules && !$0.section.paragraphs.isEmpty }.map(\.section)
    }

    /// Where the rules begin: the first heading, at any size, that names a part of the rules ("Elf Heritages",
    /// "Class Features", "Ancestry Feats"), a section-sized heading naming the entry, or a heading about as tall as
    /// the entry's own title; failing those, the first section-sized heading that isn't one of the Details' own.
    private func end(of name: String, after start: Int) -> Int {
        let key = TextRepair.matchKey(name)
        let headings = lines.indices.dropFirst(start + 1).filter { index in
            ratio(of: lines[index]) >= Self.subheadingRatio && isShort(lines[index])
        }
        let titleHeight = lines[start].bounds.height * 0.9
        let rules = headings.first { index in
            let (text, ratio) = (lines[index].text, ratio(of: lines[index]))
            let isRules = text.range(of: #"(?i)class features|heritages|ancestry feats"#, options: .regularExpression)
            return lines[index].bounds.height >= titleHeight || isRules != nil
                || ratio >= Self.sectionRatio && TextRepair.matchKey(text).contains(key)
        }
        let section = headings.first { index in
            ratio(of: lines[index]) >= Self.sectionRatio && !Self.isLoreHeading(lines[index].text)
        }
        return rules ?? section ?? lines.endIndex
    }

    /// A heading over a box of rules: one in capitals ("KEY ATTRIBUTE", "INITIAL PROFICIENCIES") that isn't one of
    /// the Details' own, which Starfinder Player Core sets in capitals ("PHYSICAL DESCRIPTION").
    static func isRulesHeading(_ line: TextLine) -> Bool {
        line.text == line.text.uppercased() && line.text.contains(where: \.isLetter) && !isLoreHeading(line.text)
    }

    /// A line all in capitals, as a box of rules sets its entries ("SIZE: TINY"); prose never is.
    static func isCapitals(_ line: TextLine) -> Bool {
        line.text == line.text.uppercased() && line.text.filter(\.isLetter).count > 1
    }

    static func isLoreHeading(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces)
            .range(of: loreHeadings, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// A heading's text, a heading in capitals in title case.
    static func headingText(_ line: TextLine) -> String {
        let text = line.text.trimmingCharacters(in: .whitespaces)
        return text == text.uppercased() ? TextRepair.titleCase(text) : text
    }

    private func ratio(of line: TextLine) -> CGFloat {
        bodyHeight > 0 ? line.bounds.height / bodyHeight : 0
    }

    /// True for a line that may be a heading: short, with letters, and not ending a sentence (the last line of an
    /// introduction set large is short too); a heading may trail off ("You might...").
    private func isShort(_ line: TextLine) -> Bool {
        let text = line.text
        let endsSentence = (text.hasSuffix(".") && !text.hasSuffix("...") && !text.hasSuffix("…"))
            || text.hasSuffix(",") || text.hasSuffix(";")
        return text.count <= Self.headingLength && text.contains(where: \.isLetter) && !endsSentence
    }
}

/// Splits a section's lines into paragraphs: a bullet ("•") starts an item, a line opening in bold starts a labeled
/// paragraph, and `ParagraphReader` splits the rest where paragraphs end.
struct DetailsParagraphs {
    private struct Chunk {
        var label = ""
        var isBullet = false
        var lines: [TextLine] = []
    }

    let lines: [TextLine]
    let bodySize: CGFloat

    func read() -> [DetailsSection.Paragraph] {
        chunks().flatMap { chunk -> [DetailsSection.Paragraph] in
            let texts = chunk.isBullet ? [TextRepair.join(chunk.lines.map(\.text))]
                : ParagraphReader(lines: chunk.lines, bodySize: bodySize).paragraphs()
            return texts.enumerated().compactMap { offset, text in
                guard !text.isEmpty else { return nil }
                return DetailsSection.Paragraph(text, label: offset == 0 ? chunk.label : "",
                                                isBullet: chunk.isBullet)
            }
        }
    }

    private func chunks() -> [Chunk] {
        var chunks: [Chunk] = []
        for line in lines {
            let text = line.text
            if text.hasPrefix("•") {
                chunks.append(Chunk(isBullet: true))
                let rest = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { chunks[chunks.count - 1].lines.append(Self.line(line, text: rest)) }
            } else if line.startsBold, let (label, rest) = Self.label(of: line) {
                chunks.append(Chunk(label: label, lines: rest.map { [$0] } ?? []))
            } else if chunks.isEmpty {
                chunks.append(Chunk(lines: [line]))
            } else {
                chunks[chunks.count - 1].lines.append(line)
            }
        }
        return chunks
    }

    /// A line's bold label ("Popular Edicts", "Sample Names:") and the rest of the line, if any.
    static func label(of line: TextLine) -> (String, TextLine?)? {
        let bold = line.runs.prefix { $0.isBold || $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let label = bold.map(\.text).joined().trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard !label.isEmpty else { return nil }
        let rest = TextLine(runs: Array(line.runs.dropFirst(bold.count)), bounds: line.bounds)
        return (label, rest.text.isEmpty ? nil : rest)
    }

    private static func line(_ line: TextLine, text: String) -> TextLine {
        TextLine(runs: [TextRun(text: text, font: line.font, size: line.size)], bounds: line.bounds)
    }
}
