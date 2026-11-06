import CoreGraphics
import Foundation
import PDFKit
import SourcebookLore

/// The sample sourcebook App Review (and anyone without Paizo's books) can add to try reading lore: real creatures'
/// and deities' names laid out as Monster Core and Divine Mysteries lay them out, with placeholder text in place of
/// every line Paizo wrote. Field Guide reads it as `SourcebookList.sample`.
public enum SampleSourcebook {
    /// A family of creatures, or a creature standing alone when `creatures` names only the family.
    public struct Family: Sendable {
        public var name: String
        public var creatures: [(name: String, level: Int)]
    }

    public static let families = [
        Family(name: "Goblin", creatures: [("Goblin Warrior", -1), ("Goblin Commando", 1)]),
        Family(name: "Wolf", creatures: [("Wolf", 1), ("Dire Wolf", 3)]),
        Family(name: "The Swarm", creatures: [("Athraxer", 1)])
    ]
    public static let deities = ["Abadar", "Iomedae"]

    static let left: CGFloat = 60
    static let lineHeight: CGFloat = 12
    static let charactersPerLine = 70

    /// The sample as a PDF.
    public static func document() -> PDFDocument? {
        PDFFixture(pages: pages()).document()
    }

    static func pages() -> [[PDFFixture.Piece]] {
        [titlePage()] + families.map(page(of:)) + deities.map(page(ofDeity:)) + [copyrightPage()]
    }

    private static func titlePage() -> [PDFFixture.Piece] {
        [PDFFixture.text("FIELD GUIDE SAMPLE MONSTER CORE", at: left, 650, font: PDFFixture.bold, size: 20),
         PDFFixture.text("Placeholder text for trying Field Guide's Sourcebooks. It holds no Paizo text.", at: left,
                         620)]
    }

    private static func page(of family: Family) -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading(family.name, size: 17)
        writer.paragraphs(2, seed: family.name)
        for creature in family.creatures {
            writer.gap()
            writer.heading(creature.name, size: 13)
            writer.paragraphs(1, seed: creature.name)
            let level = (creature.level < 0 ? "–" : "") + String(abs(creature.level))
            writer.heading("\(creature.name.uppercased()) CREATURE \(level)", size: 12)
            writer.statLine("Perception", "+0; placeholder senses")
            writer.statLine("Skills", "Lorem +0, Ipsum +0")
        }
        return writer.pieces
    }

    private static func page(ofDeity name: String) -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading(name, size: 34)
        writer.heading("THE PLACEHOLDER GOD", size: 12)
        writer.statLine("Areas of Concern", "lorem, ipsum, dolor")
        writer.statLine("Edicts", "sit amet, consectetur adipiscing")
        writer.statLine("Anathema", "sed do eiusmod tempor")
        writer.statLine("Sacred Colors", "gray, silver")
        writer.gap()
        writer.paragraphs(2, seed: name)
        return writer.pieces
    }

    private static func copyrightPage() -> [PDFFixture.Piece] {
        [PDFFixture.text("\(SourcebookList.sample.title) © 2026, Field Guide.", at: left, 400)]
    }

    /// Lays out a page from the top down.
    struct PageWriter {
        var top: CGFloat
        var pieces: [PDFFixture.Piece] = []

        mutating func heading(_ text: String, size: CGFloat) {
            top -= size * 1.2
            pieces.append(PDFFixture.text(text, at: left, top, font: PDFFixture.bold, size: size))
            top -= 4
        }

        mutating func statLine(_ label: String, _ value: String) {
            top -= lineHeight
            pieces.append(PDFFixture.stat(label, value, at: left, top))
        }

        mutating func gap() { top -= lineHeight }

        /// `count` paragraphs of placeholder text, each ending on a short line.
        mutating func paragraphs(_ count: Int, seed: String) {
            for index in 0..<count {
                for line in Lorem.lines(of: Lorem.paragraph(seed: seed.count + index), width: charactersPerLine) {
                    top -= lineHeight
                    pieces.append(PDFFixture.text(line, at: left, top))
                }
            }
        }
    }
}

/// Placeholder text.
enum Lorem {
    static let words = """
        lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore \
        magna aliqua ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo \
        consequat duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur
        """.split(separator: " ").map(String.init)

    /// Three or four sentences, chosen by `seed`.
    static func paragraph(seed: Int) -> String {
        (0..<(3 + seed % 2)).map { sentence in
            let start = (seed * 7 + sentence * 11) % words.count
            let picked = (0..<(9 + sentence % 4)).map { words[(start + $0) % words.count] }.joined(separator: " ")
            return picked.prefix(1).uppercased() + picked.dropFirst() + "."
        }.joined(separator: " ")
    }

    /// The text broken into lines of at most `width` characters; the last is short, as a paragraph's last is.
    static func lines(of text: String, width: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ") {
            if !line.isEmpty, line.count + word.count + 1 > width {
                lines.append(line)
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
