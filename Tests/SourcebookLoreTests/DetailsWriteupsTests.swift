import CoreGraphics
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct DetailsWriteupsTests {
    typealias Fixture = PDFFixture
    typealias Piece = PDFFixture.Piece

    static let filler = (0..<6).map { line in
        Fixture.text("Body text sets the size and height every heading is measured against.", at: 60,
                     200 - CGFloat(line) * 12)
    }

    /// Player Core's ancestry: a title, an introduction, sections with bullets (each bullet a point below its
    /// text) and labels, a box of rules in capitals, then "Elf Heritages".
    static let elf: [Piece] = [
        Fixture.text("ELF", at: 60, 700, font: Fixture.bold, size: 26),
        Fixture.text("Elves are an ancient people.", at: 60, 670),
        Fixture.text("KEY ATTRIBUTE", at: 60, 640, font: Fixture.bold, size: 13),
        Fixture.text("Dexterity", at: 60, 624),
        Fixture.text("You might...", at: 60, 600, font: Fixture.bold, size: 13),
        Fixture.text("•", at: 60, 583),
        Fixture.text("Curate your friendships with", at: 70, 584),
        Fixture.text("great care.", at: 70, 572),
        Fixture.text("•", at: 60, 559),
        Fixture.text("Study obscure arts.", at: 70, 560),
        Fixture.text("Beliefs", at: 60, 536, font: Fixture.bold, size: 13),
        Fixture.text("Elves love beauty.", at: 60, 520),
        Piece(runs: [TextRun(text: "Popular Edicts", font: Fixture.bold, size: 9),
                     TextRun(text: " find beauty in nature", font: Fixture.regular, size: 9)],
              origin: CGPoint(x: 60, y: 508)),
        Fixture.text("Elf Heritages", at: 60, 480, font: Fixture.bold, size: 17),
        Fixture.text("Ancient Elf", at: 60, 456, font: Fixture.bold, size: 13),
        Fixture.text("You have lived long.", at: 60, 440)
    ]

    /// A class with its description set large, ending in a short line, before its roleplaying sections.
    static let fighter: [Piece] = [
        Fixture.text("FIGHTER", at: 60, 700, font: Fixture.bold, size: 26),
        Fixture.text("Fighting for honor, greed, or the thrill of battle,", at: 60, 670, size: 13),
        Fixture.text("you master weapons.", at: 60, 654, size: 13),
        Fixture.text("During combat encounters...", at: 60, 620, font: Fixture.bold, size: 13),
        Fixture.text("You strike with accuracy.", at: 60, 604),
        Fixture.text("Class Features", at: 60, 570, font: Fixture.bold, size: 17)
    ]

    /// Starfinder Player Core's ancestry: sections headed in capitals, a tall box of rules before them.
    static let android: [Piece] = [
        Fixture.text("ANDROID", at: 60, 700, font: Fixture.bold, size: 26),
        Fixture.text("LOW-LIGHT VISION", at: 60, 670, font: Fixture.bold, size: 17),
        Fixture.text("You can see in dim light.", at: 60, 654),
        Fixture.text("PHYSICAL DESCRIPTION", at: 60, 630, font: Fixture.bold, size: 13),
        Fixture.text("Androids are synthetic.", at: 60, 614),
        Fixture.text("ANDROID HERITAGES", at: 60, 580, font: Fixture.bold, size: 17)
    ]

    /// Howl of the Wild's ancestry: its rules start under a heading no larger than its sections'.
    static let centaur: [Piece] = [
        Fixture.text("CENTAUR", at: 60, 700, font: Fixture.bold, size: 26),
        Fixture.text("Society", at: 60, 670, font: Fixture.bold, size: 13),
        Fixture.text("Centaurs roam.", at: 60, 654),
        Fixture.text("Centaur Heritages", at: 60, 630, font: Fixture.bold, size: 13),
        Fixture.text("Choose a heritage.", at: 60, 614)
    ]

    static func writeups(_ names: [String]) throws -> [String: DetailsLore] {
        let pages = [elf, fighter, android, centaur].map { $0 + filler }
        let document = try #require(PDFFixture(pages: pages).document())
        return DetailsWriteups(names: names).writeups(in: document)
    }

    @Test func readsAnAncestrysSectionsUpToItsHeritages() throws {
        let elf = try #require(try Self.writeups(["Elf"])["Elf"])
        #expect(elf.sections.map(\.heading) == ["", "You might...", "Beliefs"])
        #expect(elf.sections[0].paragraphs == [.init("Elves are an ancient people.")])
        #expect(elf.sections[1].paragraphs == [.init("Curate your friendships with great care.", isBullet: true),
                                               .init("Study obscure arts.", isBullet: true)])
        #expect(elf.sections[2].paragraphs == [.init("Elves love beauty."),
                                               .init("find beauty in nature", label: "Popular Edicts")])
    }

    @Test func readsAClassesRoleplayingPastItsDescription() throws {
        let fighter = try #require(try Self.writeups(["Fighter"])["Fighter"])
        #expect(fighter.sections.map(\.heading) == ["During combat encounters..."])
    }

    @Test func readsSectionsHeadedInCapitalsAndSkipsTallBoxesOfRules() throws {
        let android = try #require(try Self.writeups(["Android"])["Android"])
        #expect(android.sections.map(\.heading) == ["Physical Description"])
        #expect(android.sections[0].paragraphs == [.init("Androids are synthetic.")])
    }

    @Test func stopsAtHeritagesSetAsASection() throws {
        let centaur = try #require(try Self.writeups(["Centaur"])["Centaur"])
        #expect(centaur.sections.map(\.heading) == ["Society"])
    }

    @Test func findsNothingForAnEntryTheBookDoesntIntroduce() throws {
        #expect(try Self.writeups(["Goblin"]).isEmpty)
    }

    @Test func showsSectionsWithTheirBulletsAsAList() {
        let lore = DetailsLore(sections: [
            DetailsSection(paragraphs: [.init("Intro & more.")]),
            DetailsSection(heading: "You Might...", paragraphs: [.init("One.", isBullet: true),
                                                                 .init("Two.", isBullet: true)]),
            DetailsSection(heading: "Beliefs", paragraphs: [.init("kindness", label: "Popular Edicts")]),
            DetailsSection(heading: "Empty")
        ])
        #expect(lore.html == "<p>Intro &amp; more.</p><h2>You Might...</h2><ul><li>One.</li><li>Two.</li></ul>"
            + "<h2>Beliefs</h2><p><strong>Popular Edicts</strong> kindness</p>")
        #expect(DetailsLore().isEmpty && !lore.isEmpty)
        #expect(DetailsSection(paragraphs: [.init("Last.", isBullet: true)]).paragraphs.count == 1)
        #expect(DetailsLore(sections: [DetailsSection(paragraphs: [.init("Last.", isBullet: true)])]).html
            == "<ul><li>Last.</li></ul>")
    }

    @Test func knowsTheDetailsOwnHeadings() {
        for heading in ["You Might...", "OTHERS PROBABLY…", "Physical Description", "Roleplaying the Fighter",
                        "Elves of the Inner Sea", "Alignment and Religion"] {
            #expect(DetailsSectionReader.isLoreHeading(heading), "\(heading)")
        }
        #expect(!DetailsSectionReader.isLoreHeading("Hit Points"))
    }
}
