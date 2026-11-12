import ArtExtractionTestSupport
import CoreGraphics
import Foundation
import PDFKit
import SourcebookLore

/// A sample sourcebook App Review (and anyone without Paizo's books) can add to try reading lore: real creatures',
/// deities', ancestries' and classes' names laid out as Paizo's books lay them out, with placeholder text in place of
/// every line Paizo wrote. There is one for each game (`pathfinder`, `starfinder`); Field Guide reads them as
/// `SourcebookList.samples`. Every write-up opens with `marker`, so lore from a sample is plain to see.
public struct SampleSourcebook: Sendable {
    /// A creature: its name, its level, and the file name of the picture printed beside it, from the Paizo blog
    /// art in the Community Use Package artwork's `paizo-blog` folder; nil for a drawn stand-in.
    public struct Creature: Sendable {
        public var name: String
        public var level: Int
        public var art: String?

        public init(_ name: String, level: Int, art: String? = nil) {
            self.name = name
            self.level = level
            self.art = art
        }
    }

    /// A family of creatures, or a creature standing alone when `creatures` names only the family.
    public struct Family: Sendable {
        public var name: String
        public var creatures: [Creature]

        public init(name: String, creatures: [Creature]) {
            self.name = name
            self.creatures = creatures
        }
    }

    /// An ancestry or class: its Details' sections and the heading its rules start under.
    public struct Details: Sendable {
        public var name: String
        public var sections: [String]
        public var rules: String

        public init(name: String, sections: [String], rules: String) {
            self.name = name
            self.sections = sections
            self.rules = rules
        }
    }

    /// A stat block: its traits, then a bold label and its value per line.
    public typealias StatBlock = [(label: String, value: String)]

    /// The sentence every write-up in a sample opens with.
    public static let marker = "This lore has been imported from the sample PDF."

    public var book: Sourcebook
    /// What the title page says under the title.
    public var subtitle: String
    public var families: [Family]
    public var deities: [String]
    public var details: [Details]
    /// Each creature's stat block, by name, as Paizo prints it; a creature without one gets placeholder lines.
    public var statBlocks: [String: StatBlock] = [:]
    /// The ORC attribution of the Licensed Material the stat blocks come from; nil when the sample prints none.
    public var credit: String?
    /// Added to every seed of placeholder text, so a name both games' samples print (Abadar) reads differently in
    /// each.
    public var seed = ""
    /// Paizo's Pathfinder-Icons font file. With it the stat blocks' action icons are drawn in that font, which goes
    /// into the PDF whole and unaltered, and read back as they do from Paizo's books ("[one-action]"), so Pluck
    /// knows them; without it they are plain symbols (◆, ⤾).
    public var actionIcons: Data?

    public var title: String { book.title }
    public var creatures: [Creature] { families.flatMap(\.creatures) }

    static let left: CGFloat = 60
    static let lineHeight: CGFloat = 12
    static let charactersPerLine = 70
    /// How far a stat block's wrapped lines hang in from their label: one font size, and the room that costs.
    static let hangingIndent: CGFloat = 9
    static let hangingCharacters = 2
    /// Where the pictures' column starts, right of the text, which ends near x = 380.
    static let pictureColumn: CGFloat = 400

    /// A page: its text and its pictures.
    struct Page {
        var pieces: [PDFFixture.Piece]
        var pictures: [PDFFixture.Picture] = []
    }

    /// The sample as a PDF, each creature beside its picture in `art` (by the creature's name), or beside a drawn
    /// stand-in when `art` has none for it.
    public func document(art: [String: CGImage] = [:]) -> PDFDocument? {
        data(art: art).flatMap(PDFDocument.init(data:))
    }

    /// The sample's PDF file. Write this, not `document`, which PDFKit would write out its own way.
    public func data(art: [String: CGImage] = [:]) -> Data? {
        let pages = pages(art: art)
        let pictures = Dictionary(uniqueKeysWithValues: pages.enumerated().map { ($0.offset, $0.element.pictures) })
        var fixture = PDFFixture(pages: pages.map(\.pieces), pictures: pictures)
        fixture.actionIcons = actionIcons
        return fixture.data()
    }

    func pages(art: [String: CGImage]) -> [Page] {
        [Page(pieces: titlePage())] + families.flatMap { pages(of: $0, art: art) }
            + deities.map { Page(pieces: page(ofDeity: $0)) } + details.map { Page(pieces: page(of: $0)) }
            + [Page(pieces: copyrightPage())]
    }

    private func titlePage() -> [PDFFixture.Piece] {
        [PDFFixture.text(title.uppercased(), at: Self.left, 650, font: PDFFixture.bold, size: 20),
         PDFFixture.text(subtitle, at: Self.left, 620)]
    }

    /// A page for each creature, the family's heading and introduction on the first (unless the creature stands
    /// alone): the creature's heading and lore, then its stat block, with its picture in the right-hand column beside
    /// them.
    private func pages(of family: Family, art: [String: CGImage]) -> [Page] {
        family.creatures.enumerated().map { index, creature in
            var writer = PageWriter(top: 700, drawsIcons: actionIcons != nil)
            // A creature standing alone has no family heading of its own.
            if index == 0, family.creatures.count > 1 || family.name != creature.name {
                writer.heading(family.name, size: 17)
                writer.paragraphs(2, seed: seed + family.name, opening: Self.marker)
                writer.gap()
            }
            let pictureTop = writer.top
            writer.heading(creature.name, size: 13)
            writer.paragraphs(1, seed: seed + creature.name, opening: Self.marker)
            let level = (creature.level < 0 ? "–" : "") + String(abs(creature.level))
            writer.heading("\(creature.name.uppercased()) CREATURE \(level)", size: 12)
            for line in statBlocks[creature.name] ?? Self.placeholderStatBlock {
                writer.statLine(line.label, line.value)
            }
            let image = art[creature.name] ?? creatureArt(variant: index, scale: 4)
            return Page(pieces: writer.pieces, pictures: [Self.picture(image, top: pictureTop)])
        }
    }

    /// `image` scaled to fit the right-hand column (150 by 200 points), its top at `top`.
    static func picture(_ image: CGImage, top: CGFloat) -> PDFFixture.Picture {
        let scale = min(150 / CGFloat(image.width), 200 / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let origin = CGPoint(x: pictureColumn + (150 - size.width) / 2, y: top - size.height)
        return PDFFixture.Picture(image: image, rect: CGRect(origin: origin, size: size))
    }

    private func page(ofDeity name: String) -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading(name, size: 34)
        writer.heading("THE PLACEHOLDER GOD", size: 12)
        writer.statLine("Areas of Concern", "lorem, ipsum, dolor")
        writer.statLine("Edicts", "sit amet, consectetur adipiscing")
        writer.statLine("Anathema", "sed do eiusmod tempor")
        writer.statLine("Sacred Colors", "gray, silver")
        writer.gap()
        writer.paragraphs(2, seed: seed + name, opening: Self.marker)
        return writer.pieces
    }

    /// An ancestry's or class's opening pages: its name, an introduction, its sections (the ones named "...",
    /// bulleted), then the heading its rules start under.
    private func page(of details: Details) -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        writer.heading(details.name.uppercased(), size: 26)
        writer.paragraphs(1, seed: seed + details.name, opening: Self.marker)
        for section in details.sections {
            writer.gap()
            writer.heading(section, size: 13)
            if section.hasSuffix("...") {
                writer.bullets(2, seed: seed + section)
            } else {
                writer.paragraphs(1, seed: seed + section)
            }
        }
        writer.gap()
        writer.heading(details.rules, size: 17)
        writer.statLine("Hit Points", "8")
        return writer.pieces
    }

    /// The ORC notice and attribution when the stat blocks are Paizo's, then the Reserved Material and the sample's
    /// own copyright line.
    private func copyrightPage() -> [PDFFixture.Piece] {
        var writer = PageWriter(top: 700)
        if let credit {
            writer.heading("ORC Notice", size: 12)
            writer.text(Self.orcNotice)
            writer.gap()
            writer.text("Attribution: This product is based on the following Licensed Material: \(credit)")
            writer.gap()
        }
        writer.text(reservedMaterial)
        writer.gap()
        writer.text(communityUseNotice)
        writer.gap()
        if actionIcons != nil {
            writer.text(Self.actionIconsNotice)
            writer.gap()
        }
        writer.text("\(title) © 2026, Field Guide.")
        return writer.pieces
    }

    /// What is Paizo's in the sample, which the ORC License leaves out: the deities' names and the art (from
    /// paizo.com, when it prints any) are used under the Community Use Policy instead (`communityUseNotice`).
    private var reservedMaterial: String {
        let hasArt = creatures.contains { $0.art != nil }
        return "Reserved Material: the creatures' and deities' names\(hasArt ? ", the art" : "") and every other "
            + "element Paizo designates as Reserved Material. The lore is placeholder text, not Paizo's."
    }

    /// The stat lines of a creature the sample has no stat block for.
    static let placeholderStatBlock: StatBlock = [
        ("Perception", "+0; placeholder senses"), ("Skills", "Lorem +0, Ipsum +0")
    ]

    /// Lays out a page from the top down.
    struct PageWriter {
        var top: CGFloat
        /// Whether a stat line's action symbols are drawn as Paizo's icons.
        var drawsIcons = false
        var pieces: [PDFFixture.Piece] = []

        mutating func heading(_ text: String, size: CGFloat) {
            top -= size * 1.2
            pieces.append(PDFFixture.text(text, at: left, top, font: PDFFixture.bold, size: size))
            top -= 4
        }

        /// A bold label and its value, wrapped onto further lines when long; a line without a label (a stat
        /// block's traits) is plain text. The further lines hang in from the label, as a bestiary sets them, which
        /// is how Pluck tells a wrapped entry from the next one.
        mutating func statLine(_ label: String, _ value: String) {
            guard !label.isEmpty else { return text(value) }
            let lines = Lorem.lines(of: label + " " + value, width: charactersPerLine - hangingCharacters)
            top -= lineHeight
            let value = PDFFixture.stat(label, String(lines[0].dropFirst(label.count + 1)), at: left, top)
            pieces.append(withIcons(value))
            for line in lines.dropFirst() {
                top -= lineHeight
                pieces.append(withIcons(PDFFixture.text(line, at: left + hangingIndent, top)))
            }
        }

        /// The piece with its action symbols as icons, when the page draws them.
        private func withIcons(_ piece: PDFFixture.Piece) -> PDFFixture.Piece {
            guard drawsIcons else { return piece }
            return PDFFixture.Piece(runs: piece.runs.flatMap(ActionIcon.runs(of:)), origin: piece.origin)
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

        /// `count` paragraphs of placeholder text, each ending on a short line; the first opens with `opening`.
        mutating func paragraphs(_ count: Int, seed: String, opening: String? = nil) {
            for index in 0..<count {
                let text = Lorem.paragraph(seed: seed.count + index)
                let paragraph = index == 0 ? opening.map { "\($0) \(text)" } ?? text : text
                for line in Lorem.lines(of: paragraph, width: charactersPerLine) {
                    top -= lineHeight
                    pieces.append(PDFFixture.text(line, at: left, top))
                }
            }
        }
    }
}
