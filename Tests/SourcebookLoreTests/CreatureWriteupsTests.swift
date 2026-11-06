import CoreGraphics
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct CreatureWriteupsTests {
    typealias Fixture = PDFFixture

    /// A family as Monster Core sets it: the family's heading and introduction, then each creature's heading,
    /// paragraph and stat block. The adult dragon has no heading of its own; Wolf stands alone.
    static let pages: [[Fixture.Piece]] = [[
        Fixture.text("GOBLIN WARRIOR CREATURE –1", at: 60, 680, font: Fixture.bold, size: 12),
        Fixture.text("An example stat block from the introduction.", at: 60, 660)
    ], [
        Fixture.text("Goblin", at: 60, 700, font: Fixture.bold, size: 17),
        Fixture.text("Goblins are small and loud.", at: 60, 676),
        Fixture.text("They sing about their foes.", at: 60, 664),
        Fixture.text("Goblin Songs", at: 60, 640, font: Fixture.bold, size: 13),
        Fixture.text("A sidebar of songs.", at: 60, 620),
        Fixture.text("Goblin Warrior", at: 60, 590, font: Fixture.bold, size: 13),
        Fixture.text("Warriors fight in groups.", at: 60, 570),
        Fixture.text("GOBLIN WARRIOR CREATURE –1", at: 60, 550, font: Fixture.bold, size: 12),
        Fixture.stat("Perception", "+2; darkvision", at: 60, 536),
        Fixture.text("Goblin Commando (Raider)", at: 60, 500, font: Fixture.bold, size: 13),
        Fixture.text("Commandos ride wolves.", at: 60, 480),
        Fixture.text("GOBLIN COMMANDO", at: 60, 460, font: Fixture.bold, size: 12),
        Fixture.text("CREATURE 1", at: 60, 446, font: Fixture.bold, size: 12),
        Fixture.stat("Perception", "+5", at: 60, 432)
    ], [
        Fixture.text("Wolf", at: 60, 700, font: Fixture.bold, size: 17),
        Fixture.text("Wolves hunt in packs.", at: 60, 676),
        Fixture.text("WOLF CREATURE 1", at: 60, 650, font: Fixture.bold, size: 12),
        Fixture.stat("Perception", "+7", at: 60, 636),
        Fixture.text("Horned Dragon", at: 60, 600, font: Fixture.bold, size: 13),
        Fixture.text("Horned dragons guard forests.", at: 60, 580),
        Fixture.text("YOUNG HORNED DRAGON CREATURE 7", at: 60, 560, font: Fixture.bold, size: 12),
        Fixture.stat("Perception", "+15", at: 60, 546),
        Fixture.text("ADULT HORNED DRAGON CREATURE 12", at: 60, 500, font: Fixture.bold, size: 12),
        Fixture.stat("Perception", "+22", at: 60, 486),
        Fixture.text("Goblin Raider", at: 60, 450, font: Fixture.bold, size: 13),
        Fixture.text("Raiders steal.", at: 60, 430),
        Fixture.text("Goblin Raider", at: 60, 410, font: Fixture.bold, size: 13),
        Fixture.text("Raiders steal again.", at: 60, 390),
        Fixture.text("GOBLIN RAIDER CREATURE 2", at: 60, 370, font: Fixture.bold, size: 12)
    ]]

    static func writeups() throws -> [String: CreatureLore] {
        let document = try #require(PDFFixture(pages: pages).document())
        return CreatureWriteups().writeups(in: document)
    }

    @Test func readsACreaturesParagraphsAndItsFamilysIntroduction() throws {
        let warrior = try #require(try Self.writeups()["goblinwarrior"])
        #expect(warrior.paragraphs == ["Warriors fight in groups."])
        #expect(warrior.family == "Goblin")
        #expect(warrior.familyParagraphs == ["Goblins are small and loud. They sing about their foes."])
    }

    @Test func matchesAHeadingWithAParentheticalAndALevelOnTheNextLine() throws {
        let commando = try #require(try Self.writeups()["goblincommando"])
        #expect(commando.paragraphs == ["Commandos ride wolves."] && commando.family == "Goblin")
    }

    @Test func aCreatureAsLargeAsAFamilyStandsAlone() throws {
        let wolf = try #require(try Self.writeups()["wolf"])
        #expect(wolf.paragraphs == ["Wolves hunt in packs."] && wolf.family.isEmpty && wolf.familyParagraphs.isEmpty)
    }

    @Test func aCreatureWithoutAHeadingSharesTheOneAbove() throws {
        let writeups = try Self.writeups()
        #expect(writeups["younghorneddragon"]?.paragraphs == ["Horned dragons guard forests."])
        #expect(writeups["adulthorneddragon"]?.paragraphs == ["Horned dragons guard forests."])
    }

    @Test func theClosestHeadingNamingTheCreatureWins() throws {
        #expect(try Self.writeups()["goblinraider"]?.paragraphs == ["Raiders steal again."])
    }

    @Test func readsNothingWithoutStatBlocks() throws {
        let document = try #require(PDFFixture(pages: [[Fixture.text("Just prose.", at: 60, 600)]]).document())
        #expect(CreatureWriteups().writeups(in: document).isEmpty)
    }

    @Test func aStatBlockWithoutACapitalizedNameIsNotOne() {
        let line = TextLine(runs: [TextRun(text: "Goblin warrior CREATURE 1", font: "Bold", size: 12)],
                            bounds: CGRect(x: 0, y: 0, width: 100, height: 13))
        #expect(CreatureWriteups.statName(at: 0, in: [line]) == nil)
        let level = TextLine(runs: [TextRun(text: "CREATURE 1", font: "Bold", size: 12)],
                             bounds: CGRect(x: 0, y: 0, width: 100, height: 13))
        #expect(CreatureWriteups.statName(at: 0, in: [level]) == nil)
    }

    @Test func aVariantsKeysNameTheStatBlockItsBookPrints() {
        #expect(CreatureLore.keys(for: "Horned Dragon (Adult, Spellcaster)")
            == ["horneddragonadultspellcaster", "adulthorneddragon", "horneddragon"])
        #expect(CreatureLore.keys(for: "Goblin Warrior") == ["goblinwarrior"])
    }

    @Test func showsTheCreaturesParagraphsThenItsFamilys() {
        let lore = CreatureLore(paragraphs: ["Fights <loudly>."], family: "Goblin", familyParagraphs: ["Small & loud."])
        #expect(lore.html == "<section class=\"description\"><p>Fights &lt;loudly&gt;.</p><hr><h3>Goblin</h3>"
            + "<p>Small &amp; loud.</p></section>")
        #expect(CreatureLore(paragraphs: ["Alone."]).html == "<section class=\"description\"><p>Alone.</p></section>")
        #expect(CreatureLore().isEmpty)
    }

    @Test func ordersAWideColumnBesideANarrowSidebar() {
        func line(_ text: String, left: CGFloat, top: CGFloat, width: CGFloat) -> TextLine {
            TextLine(runs: [TextRun(text: text, font: "Regular", size: 9)],
                     bounds: CGRect(x: left, y: top, width: width, height: 10))
        }
        // A narrow sidebar on the left, the wide column on the right with a short heading.
        let lines = [line("Main 1", left: 243, top: 700, width: 300), line("Side 1", left: 86, top: 690, width: 140),
                     line("Heading", left: 243, top: 650, width: 50), line("Side 2", left: 86, top: 640, width: 140),
                     line("Main 2", left: 243, top: 600, width: 300)]
        #expect(ColumnOrder.lines(lines, pageWidth: 612).map(\.text) == ["Side 1", "Side 2", "Main 1", "Heading",
                                                                         "Main 2"])
        #expect(ColumnOrder.split(of: [], pageWidth: 600) == 300)
        // On a page with the wide column on the left, the columns meet where fewest lines cross.
        let odd = [line("Main", left: 60, top: 700, width: 300), line("Main", left: 60, top: 690, width: 300),
                   line("Side", left: 374, top: 700, width: 150), line("Short", left: 243, top: 680, width: 100)]
        #expect(ColumnOrder.split(of: odd, pageWidth: 612) == 371)
        // A title across both columns is read where it stands.
        let title = line("Title", left: 60, top: 720, width: 480)
        #expect(ColumnOrder.lines(lines + [title], pageWidth: 612).first?.text == "Title")
    }

    @Test func aBookWithoutNamedHeadingsHasNoFamilies() {
        let line = TextLine(runs: [TextRun(text: "Heading", font: "Bold", size: 13)],
                            bounds: CGRect(x: 0, y: 0, width: 100, height: 15))
        let section = CreatureSection(lines: [line, line], bodySize: 9)
        #expect(section.familyHeading(above: 1, creatureHeight: 0) == nil)
        #expect(CreatureSection.creatureHeight(of: []) == 0)
    }
}
