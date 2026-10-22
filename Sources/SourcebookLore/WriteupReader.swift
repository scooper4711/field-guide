import CoreGraphics
import Foundation

/// Reads one deity's write-up from the lines after its heading. The lines before the first one in the body text's
/// font are its header: the title, any descriptor, the stat lines (a bold label, then the value, wrapped lines
/// indented) and the "Devotee Benefits" heading. The prose follows, up to its first subheading.
struct WriteupReader {
    /// A stat line being read, which wrapped lines may still continue.
    private struct OpenStatLine {
        let line: TextLine
        let label: String
        var parts: [String]
    }

    /// The stat labels a write-up uses, as printed; "Sacred Color" is a variant of "Sacred Colors".
    static let labels: [String: String] = [
        "Areas of Concern": "Areas of Concern", "Edicts": "Edicts", "Anathema": "Anathema",
        "Religious Symbol": "Religious Symbol", "Sacred Animal": "Sacred Animal", "Sacred Animals": "Sacred Animal",
        "Sacred Colors": "Sacred Colors", "Sacred Color": "Sacred Colors", "Divine Attribute": "Divine Attribute",
        "Cleric Spells": "Cleric Spells", "Divine Font": "Divine Font",
        "Divine Sanctification": "Divine Sanctification",
        "Divine Skill": "Divine Skill", "Domains": "Domains", "Alternate Domains": "Alternate Domains",
        "Favored Weapon": "Favored Weapon"
    ]

    let lines: [TextLine]
    let names: [String]

    func read() -> DeityLore {
        let body = Self.bodyFont(of: lines)
        let headerEnd = Self.headerEnd(of: lines, body: body)
        let header = Array(lines[..<headerEnd])
        // A sentence set between the title and the stat lines, as Starfinder Player Core has, opens the prose.
        let descriptor = TextRepair.join(Self.descriptor(in: header, body: body).map(\.text))
        let prose = ParagraphReader(lines: Array(lines[headerEnd...]), bodySize: body.size).paragraphs()
        return DeityLore(statLines: statLines(of: header),
                         paragraphs: (descriptor.isEmpty ? [] : [descriptor]) + prose,
                         intercession: IntercessionReader(lines: lines, bodySize: body.size).read())
    }

    /// Where the prose starts: the first line in the body font that doesn't continue a stat line and isn't
    /// followed by more stat lines.
    static func headerEnd(of lines: [TextLine], body: (name: String, size: CGFloat)) -> Int {
        var open: TextLine?
        for (index, line) in lines.enumerated() {
            if statLine(line) != nil {
                open = line
            } else if let stat = open, continues(line, statLine: stat) {
                continue
            } else if isProse(line, body: body), !precedesStatLines(index, in: lines) {
                return index
            } else {
                open = nil
            }
        }
        return lines.endIndex
    }

    /// The header's lines of prose that don't continue a stat line.
    static func descriptor(in header: [TextLine], body: (name: String, size: CGFloat)) -> [TextLine] {
        var open: TextLine?
        return header.filter { line in
            if statLine(line) != nil {
                open = line
                return false
            }
            if let stat = open, continues(line, statLine: stat) { return false }
            open = nil
            return isProse(line, body: body)
        }
    }

    /// True when a stat line follows within the next few lines, as after Starfinder Player Core's descriptor.
    private static func precedesStatLines(_ index: Int, in lines: [TextLine]) -> Bool {
        lines[(index + 1)...].prefix(4).contains { statLine($0) != nil }
    }

    /// The header's title (its first line, when that isn't a stat line) and stat lines.
    private func statLines(of header: [TextLine]) -> [StatLine] {
        var result: [StatLine] = []
        var current: OpenStatLine?
        func close() {
            if let current, !current.label.isEmpty {
                result.append(StatLine(label: current.label, text: TextRepair.join(current.parts)))
            }
            current = nil
        }
        for (index, line) in header.enumerated() {
            if let (label, value) = Self.statLine(line) {
                close()
                current = OpenStatLine(line: line, label: label, parts: [value])
            } else if let open = current, Self.continues(line, statLine: open.line) {
                current?.parts.append(line.text)
            } else {
                close()
                if index == 0, !line.startsBold || line.text == line.text.uppercased() {
                    result.append(StatLine(label: "Title", text: Self.title(line)))
                }
            }
        }
        close()
        return result
    }

    /// A title line: one set in capitals in title case; one in small caps or a display font with its case repaired.
    static func title(_ line: TextLine) -> String {
        let text = line.text
        return text == text.uppercased() ? TextRepair.titleCase(text) : TextRepair.heading(text)
    }

    /// The font and size most of the section's letters are set in.
    static func bodyFont(of lines: [TextLine]) -> (name: String, size: CGFloat) {
        struct Face: Hashable {
            let name: String
            let size: CGFloat
        }
        let counts = lines.flatMap(\.runs).reduce(into: [Face: Int]()) { counts, run in
            counts[Face(name: run.font, size: run.size), default: 0] += run.text.count
        }
        let body = counts.max { $0.value < $1.value }?.key
        return (body?.name ?? "", body?.size ?? 9)
    }

    /// True for a line of prose: in the body font and size, not starting with a label, and not the "Devotee
    /// Benefits" heading set in the body font's small caps.
    static func isProse(_ line: TextLine, body: (name: String, size: CGFloat)) -> Bool {
        line.font == body.name && !line.startsBold && line.size <= body.size * 1.05 && !isBenefitsHeading(line)
    }

    /// The label and value of a stat line ("Edicts bring civilization…"), or nil for another line. A bold label
    /// that isn't a known stat (such as the first edition's "Alignment") still makes a stat line, which is dropped.
    static func statLine(_ line: TextLine) -> (String, String)? {
        guard let first = line.runs.first(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }),
              first.isBold, line.runs.count > 1 else { return nil }
        let label = first.text.trimmingCharacters(in: .whitespaces)
        let value = line.runs.drop { $0 != first }.dropFirst().map(\.text).joined()
        return (labels[label] ?? "", value.trimmingCharacters(in: .whitespaces))
    }

    /// True for a stat line's wrapped continuation: no label, indented from the stat line, in its value's font.
    static func continues(_ line: TextLine, statLine: TextLine) -> Bool {
        let valueFont = statLine.runs.last { !$0.isBold && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }?.font
        return !line.startsBold && line.bounds.minX > statLine.bounds.minX + 3
            && abs(line.size - statLine.size) < 1 && (valueFont == nil || line.font == valueFont)
    }

    /// The heading set between a write-up's setting lines and its rules lines.
    static func isBenefitsHeading(_ line: TextLine) -> Bool {
        TextRepair.matchKey(line.text) == "devoteebenefits"
    }
}
