import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct DeityWriteupsTests {
    typealias Fixture = PDFFixture

    /// A major deity's write-up as Divine Mysteries sets it, then a minor deity's in smaller capitals.
    static let pages: [[Fixture.Piece]] = [[
        Fixture.text("Abadar", at: 80, 700, font: Fixture.bold, size: 34),
        Fixture.text("MASTER OF THE FIRST VAULT", at: 80, 660, font: Fixture.bold, size: 12),
        Fixture.stat("Areas of Concern", "cities, law, merchants, wealth", at: 80, 648),
        Fixture.stat("Edicts", "bring civilization to the frontiers, earn wealth", at: 80, 636),
        Fixture.text("through hard work and trade", at: 89, 624),
        Fixture.stat("Sacred Color", "gold, silver", at: 80, 612),
        Fixture.text("Devotee Benefits", at: 80, 590, size: 14),
        Fixture.stat("Divine Font", "harm or heal", at: 80, 576),
        Fixture.text("Abadar is worshipped among most as a god of", at: 80, 550),
        Fixture.text("commerce and order.", at: 80, 538),
        Fixture.text("His cathedral banks are found in every major", at: 89, 526),
        Fixture.text("city on Golarion.", at: 80, 514),
        Fixture.text("12", at: 30, 20, size: 10),
        Fixture.text("THE CHURCH", at: 80, 490, size: 14),
        Fixture.text("The Abadaran church is highly regimented.", at: 80, 476)
    ], [
        Fixture.text("CHAVAZVUG", at: 80, 700, font: Fixture.bold, size: 14),
        Fixture.text("Chavazvug is a towering mound of organs.", at: 80, 686),
        Fixture.text("Most of his worshippers are arsonists who love fire", at: 89, 674),
        Fixture.text("and smoke.", at: 80, 662),
        Fixture.text("CHAPTER 5", at: 560, 500, font: Fixture.bold, size: 8),
        Fixture.text("YAMASOTH", at: 80, 640, font: Fixture.bold, size: 14),
        Fixture.text("Yamasoth appears as a nightmarish octopus.", at: 80, 626)
    ]]

    @Test func readsAMajorDeitysStatLinesAndIntroduction() throws {
        let document = try #require(PDFFixture(pages: Self.pages).document())
        let writeups = DeityWriteups(names: ["Abadar", "Chavazvug", "Yamasoth"]).writeups(in: document)
        let abadar = try #require(writeups["Abadar"])
        #expect(abadar.statLines == [
            StatLine(label: "Title", text: "Master of the First Vault"),
            StatLine(label: "Areas of Concern", text: "cities, law, merchants, wealth"),
            StatLine(label: "Edicts",
                     text: "bring civilization to the frontiers, earn wealth through hard work and trade"),
            StatLine(label: "Sacred Colors", text: "gold, silver"),
            StatLine(label: "Divine Font", text: "harm or heal")
        ])
        #expect(abadar.paragraphs == [
            "Abadar is worshipped among most as a god of commerce and order.",
            "His cathedral banks are found in every major city on Golarion."
        ])
    }

    @Test func readsAMinorDeitysProseUpToTheNextDeity() throws {
        let document = try #require(PDFFixture(pages: Self.pages).document())
        let writeups = DeityWriteups(names: ["Abadar", "Chavazvug", "Yamasoth"]).writeups(in: document)
        #expect(writeups["Chavazvug"] == DeityLore(paragraphs: [
            "Chavazvug is a towering mound of organs.", "Most of his worshippers are arsonists who love fire and smoke."
        ]))
        #expect(writeups["Yamasoth"]?.paragraphs == ["Yamasoth appears as a nightmarish octopus."])
    }
}
