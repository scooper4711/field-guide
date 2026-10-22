import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct DeityTableTests {
    typealias Fixture = PDFFixture

    /// A table page like the Web Supplement's: a header row, a section heading, a row whose edicts wrap over three
    /// lines with the name centered beside them, and a footer.
    static let page: [Fixture.Piece] = [
        Fixture.text("DEITY", at: 40, 700, font: Fixture.bold, size: 8),
        Fixture.text("TITLE", at: 120, 700, font: Fixture.bold, size: 8),
        Fixture.text("EDICTS", at: 260, 700, font: Fixture.bold, size: 8),
        Fixture.text("HOLY", at: 420, 705, font: Fixture.bold, size: 8),
        Fixture.text("SYMBOL", at: 416, 696, font: Fixture.bold, size: 8),
        Fixture.text("Core Gods", at: 32, 670, font: Fixture.bold, size: 8),
        Fixture.text("Abadar†", at: 40, 640, size: 8),
        Fixture.text("Master of the First Vault", at: 100, 640, size: 8),
        Fixture.text("Bring civilization to the frontiers,", at: 220, 649, size: 8),
        Fixture.text("earn wealth through hard work and", at: 220, 640, size: 8),
        Fixture.text("trade, follow the rule of law", at: 220, 631, size: 8),
        Fixture.text("Golden key", at: 410, 640, size: 8),
        Fixture.text("Arazni†", at: 40, 600, size: 8),
        Fixture.text("The Unyielding", at: 100, 600, size: 8),
        Fixture.text("Protect the abused", at: 220, 600, size: 8),
        Fixture.text("Bloody heart", at: 410, 600, size: 8),
        Fixture.text("Unknown God", at: 40, 560, size: 8),
        Fixture.text("Nobody", at: 100, 560, size: 8),
        Fixture.text("© 2024, Paizo Inc.", at: 300, 8, size: 8)
    ]

    @Test func readsEachRowsCellsUnderTheirLabels() throws {
        let document = try #require(PDFFixture(pages: [[Fixture.text("No table here", at: 50, 700)], Self.page])
            .document())
        let rows = DeityTable(names: ["Abadar", "Arazni", "Asmodeus"]).rows(in: document)
        #expect(Set(rows.keys) == ["Abadar", "Arazni"])
        #expect(rows["Abadar"] == [
            StatLine(label: "Title", text: "Master of the First Vault"),
            StatLine(label: "Edicts", text: "Bring civilization to the frontiers, earn wealth through hard work and "
                + "trade, follow the rule of law"),
            StatLine(label: "Religious Symbol", text: "Golden key")
        ])
        #expect(rows["Arazni"]?.first { $0.label == "Edicts" }?.text == "Protect the abused")
    }

    @Test func titlesTheHeadersLabels() {
        #expect(TableHeader.title("AREAS OF CONCERN") == "Areas of Concern")
        #expect(TableHeader.title("HOLY SYMBOL") == "Religious Symbol")
        #expect(TableHeader.title("SACRED COLORS") == "Sacred Colors")
    }
}
