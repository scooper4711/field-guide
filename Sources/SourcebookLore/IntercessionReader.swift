import CoreGraphics
import Foundation

/// A deity's divine intercession: how it intervenes, then its boons and curses from minor to major.
public struct Intercession: Codable, Equatable, Sendable {
    /// The paragraphs before the boons and curses.
    public var introduction: [String]
    /// The boons and curses, labeled "Minor Boon" to "Major Curse".
    public var effects: [StatLine]

    public init(introduction: [String] = [], effects: [StatLine] = []) {
        self.introduction = introduction
        self.effects = effects
    }
}

/// Reads a deity's divine intercession from its section: in Divine Mysteries, the lines under its "Divine
/// Intercession" subheading; in the Gods & Magic Web Supplement, the whole entry, whose introduction opens it. Each
/// boon or curse starts with its bold label ("Minor Boon:") and runs to the next, or to the next subheading.
struct IntercessionReader {
    static let labels = ["Minor Boon", "Moderate Boon", "Major Boon", "Minor Curse", "Moderate Curse", "Major Curse"]

    let lines: [TextLine]
    let bodySize: CGFloat

    func read() -> Intercession? {
        let heading = lines.firstIndex { TextRepair.matchKey($0.text) == "divineintercession" }
        let start = heading.map { $0 + 1 } ?? lines.startIndex
        guard let first = lines[start...].firstIndex(where: { Self.label(of: $0) != nil }) else { return nil }
        let introduction = ParagraphReader(lines: Array(lines[start..<first]), bodySize: bodySize).paragraphs()
        return Intercession(introduction: introduction, effects: effects(from: first))
    }

    private func effects(from start: Int) -> [StatLine] {
        var effects: [(label: String, parts: [String])] = []
        for line in lines[start...] {
            if let (label, text) = Self.label(of: line) {
                effects.append((label, [text]))
            } else if isSubheading(line) {
                break
            } else if !effects.isEmpty {
                effects[effects.count - 1].parts.append(ParagraphReader.text(of: line, bodySize: bodySize))
            }
        }
        return effects.map { StatLine(label: $0.label, text: TextRepair.join($0.parts)) }
    }

    private func isSubheading(_ line: TextLine) -> Bool {
        ParagraphReader(lines: [], bodySize: bodySize).isSubheading(line)
    }

    /// The boon's or curse's label and the text after it, when the line starts one. Divine Mysteries sets the
    /// labels in bold; the Gods & Magic Web Supplement's read back in the body font, so the colon marks them.
    static func label(of line: TextLine) -> (String, String)? {
        let text = line.text
        guard let label = labels.first(where: { text.hasPrefix($0 + ":") }) else { return nil }
        return (label, text.dropFirst(label.count + 1).trimmingCharacters(in: .whitespaces))
    }
}
