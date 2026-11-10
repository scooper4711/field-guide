import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import PDFKit
import SourcebookLore

/// The sample sourcebook App Review (and anyone without Paizo's books) can add to try reading lore: real creatures'
/// and deities' names laid out as Monster Core and Divine Mysteries lay them out, with placeholder text in place of
/// every line Paizo wrote. Field Guide reads it as `SourcebookList.sample`.
public enum SampleSourcebook {
    /// A creature: its name, its level, and the file name of the picture printed beside it, from the Paizo blog
    /// art in the Community Use Package artwork's `paizo-blog` folder.
    public struct Creature: Sendable {
        public var name: String
        public var level: Int
        public var art: String
    }

    /// A family of creatures, or a creature standing alone when `creatures` names only the family.
    public struct Family: Sendable {
        public var name: String
        public var creatures: [Creature]
    }

    public static let families = [
        Family(name: "Goblin", creatures: [
            Creature(name: "Goblin Warrior", level: -1, art: "s2_0254_PZO160709_Bilia.png"),
            Creature(name: "Goblin Pyro", level: 1, art: "rcv_PZO2109_FireworkTechnician.jpg")
        ]),
        Family(name: "Hobgoblin", creatures: [
            Creature(name: "Hobgoblin Soldier", level: 1, art: "20287_031521_Kaoling-Hobgoblin.jpg")
        ]),
        Family(name: "Kholo", creatures: [
            Creature(name: "Kholo Hunter", level: 2, art: "20007_022820_GnollWarriorjpg.jpg")
        ])
    ]
    public static var creatures: [Creature] { families.flatMap(\.creatures) }
    public static let deities = ["Abadar", "Iomedae"]
    /// An ancestry or class: its Details' sections and the heading its rules start under.
    public struct Details: Sendable {
        public var name: String
        public var sections: [String]
        public var rules: String
    }

    public static let details = [
        Details(name: "Elf", sections: ["Physical Description", "Society", "You Might...", "Others Probably..."],
                rules: "Elf Heritages"),
        Details(name: "Fighter", sections: ["During Combat Encounters...", "While Exploring...", "You Might..."],
                rules: "Class Features")
    ]

    static let left: CGFloat = 60
    static let lineHeight: CGFloat = 12
    static let charactersPerLine = 70
    /// Where the pictures' column starts, right of the text, which ends near x = 380.
    static let pictureColumn: CGFloat = 400

    /// A page: its text and its pictures.
    struct Page {
        var pieces: [PDFFixture.Piece]
        var pictures: [PDFFixture.Picture] = []
    }

    /// The sample as a PDF, each creature beside its picture in `art` (by the creature's name), or beside a drawn
    /// stand-in when `art` has none for it.
    public static func document(art: [String: CGImage] = [:]) -> PDFDocument? {
        let pages = pages(art: art)
        let pictures = Dictionary(uniqueKeysWithValues: pages.enumerated().map { ($0.offset, $0.element.pictures) })
        return PDFFixture(pages: pages.map(\.pieces), pictures: pictures).document()
    }

    static func pages(art: [String: CGImage]) -> [Page] {
        [Page(pieces: titlePage())] + families.flatMap { pages(of: $0, art: art) }
            + deities.map { Page(pieces: page(ofDeity: $0)) } + details.map { Page(pieces: page(of: $0)) }
            + [Page(pieces: copyrightPage())]
    }

    private static func titlePage() -> [PDFFixture.Piece] {
        [PDFFixture.text("FIELD GUIDE SAMPLE MONSTER CORE", at: left, 650, font: PDFFixture.bold, size: 20),
         PDFFixture.text("Placeholder lore for trying Field Guide's Sourcebooks; the stat blocks are Monster Core's.",
                         at: left, 620)]
    }

    /// A page for each creature, the family's heading and introduction on the first: the creature's heading and
    /// lore, then its stat block, with its picture in the right-hand column beside them.
    private static func pages(of family: Family, art: [String: CGImage]) -> [Page] {
        family.creatures.enumerated().map { index, creature in
            var writer = PageWriter(top: 700)
            if index == 0 {
                writer.heading(family.name, size: 17)
                writer.paragraphs(2, seed: family.name)
                writer.gap()
            }
            let pictureTop = writer.top
            writer.heading(creature.name, size: 13)
            writer.paragraphs(1, seed: creature.name)
            let level = (creature.level < 0 ? "–" : "") + String(abs(creature.level))
            writer.heading("\(creature.name.uppercased()) CREATURE \(level)", size: 12)
            for line in statBlocks[creature.name] ?? [] { writer.statLine(line.label, line.value) }
            let image = art[creature.name] ?? creatureArt(variant: index, scale: 4)
            return Page(pieces: writer.pieces, pictures: [picture(image, top: pictureTop)])
        }
    }

    /// `image` scaled to fit the right-hand column (150 by 200 points), its top at `top`.
    static func picture(_ image: CGImage, top: CGFloat) -> PDFFixture.Picture {
        let scale = min(150 / CGFloat(image.width), 200 / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let origin = CGPoint(x: pictureColumn + (150 - size.width) / 2, y: top - size.height)
        return PDFFixture.Picture(image: image, rect: CGRect(origin: origin, size: size))
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

    /// An ancestry's or class's opening pages: its name, an introduction, its sections (the ones named "...",
    /// bulleted), then the heading its rules start under.
    private static func page(of details: Details) -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading(details.name.uppercased(), size: 26)
        writer.paragraphs(1, seed: details.name)
        for section in details.sections {
            writer.gap()
            writer.heading(section, size: 13)
            if section.hasSuffix("...") {
                writer.bullets(2, seed: section)
            } else {
                writer.paragraphs(1, seed: section)
            }
        }
        writer.gap()
        writer.heading(details.rules, size: 17)
        writer.statLine("Hit Points", "8")
        return writer.pieces
    }

    private static func copyrightPage() -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading("ORC Notice", size: 12)
        writer.text(orcNotice)
        writer.gap()
        writer.text("Attribution: This product is based on the following Licensed Material: \(monsterCoreCredit)")
        writer.gap()
        writer.text("""
            Reserved Material: the creatures' and deities' names, the art and every other element Paizo designates \
            as Reserved Material. The lore is placeholder text, not Paizo's; the art is from paizo.com, used under \
            Paizo's Community Use Policy.
            """)
        writer.gap()
        writer.text("\(SourcebookList.sample.title) © 2026, Field Guide.")
        return writer.pieces
    }

    static let orcNotice = """
        This product is licensed under the ORC License located at the Library of Congress at TX 9-307-067 and \
        available online at various locations including paizo.com/orclicense, azoralaw.com/orclicense, and others. \
        All warranties are disclaimed as set forth therein.
        """
    /// How Monster Core asks to be credited.
    static let monsterCoreCredit = """
        Pathfinder Monster Core © 2024, Paizo Inc., Authors: Alexander Augunas, Dennis Baker, Kate Baker, Joshua \
        Birdsong, Joseph Blomquist, Logan Bonner, Jason Bulmahn, James Case, John Compton, Paris Crenshaw, Adam \
        Daigle, Darrin Drader, Brian Duckwitz, Robert N. Emerson, Scott Fernandez, Eleanor Ferron, Leo Glass, \
        Matthew Goodall, BJ Hensley, Thurston Hillman, Vanessa Hoskins, James Jacobs, Jenny Jarzabski, Miko Kallio, \
        Jason Keeley, Jeff Lee, Lyz Liddell, Luis Loza, Ron Lundeen, Robert G. McCreary, Philippe-Antoine Menard, \
        Jacob W. Michaels, Dave Nelson, Jason Nelson, Tim Nightengale, Stephen Radney-MacFarland, Mikhail Rekun, \
        Patrick Renie, Alex Riggs, David N. Ross, Michael Sayre, Mark Seifter, Chris S. Sims, Amber Stewart, \
        Jeffrey Swank, William Thompson, Jason Tondro, Clark Valentine, Landon Winkler, Tonya Woldridge, and Linda \
        Zayas-Palmer.
        """

    /// Lays out a page from the top down.
    struct PageWriter {
        var top: CGFloat
        var pieces: [PDFFixture.Piece] = []

        mutating func heading(_ text: String, size: CGFloat) {
            top -= size * 1.2
            pieces.append(PDFFixture.text(text, at: left, top, font: PDFFixture.bold, size: size))
            top -= 4
        }

        /// A bold label and its value, wrapped onto further lines when long; a line without a label (a stat
        /// block's traits) is plain text.
        mutating func statLine(_ label: String, _ value: String) {
            guard !label.isEmpty else { return text(value) }
            let lines = Lorem.lines(of: label + " " + value, width: charactersPerLine)
            top -= lineHeight
            pieces.append(PDFFixture.stat(label, String(lines[0].dropFirst(label.count + 1)), at: left, top))
            for line in lines.dropFirst() {
                top -= lineHeight
                pieces.append(PDFFixture.text(line, at: left, top))
            }
        }

        /// Plain text, wrapped.
        mutating func text(_ text: String) {
            for line in Lorem.lines(of: text, width: charactersPerLine) {
                top -= lineHeight
                pieces.append(PDFFixture.text(line, at: left, top))
            }
        }

        mutating func gap() { top -= lineHeight }

        /// `count` bulleted items of placeholder text, the bullet beside each item's first line.
        mutating func bullets(_ count: Int, seed: String) {
            for index in 0..<count {
                let item = Lorem.paragraph(seed: seed.count + index).components(separatedBy: ". ").first ?? ""
                for (offset, line) in Lorem.lines(of: item + ".", width: charactersPerLine - 4).enumerated() {
                    top -= lineHeight
                    if offset == 0 { pieces.append(PDFFixture.text("•", at: left, top)) }
                    pieces.append(PDFFixture.text(line, at: left + 9, top))
                }
            }
        }

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
