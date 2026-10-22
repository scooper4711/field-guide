import Foundation
import Testing
@testable import SourcebookLore

@Suite struct SourcebookListTests {
    static let divineMysteries = Sourcebook(
        title: "Pathfinder Lost Omens Divine Mysteries", sku: "PZO13003E",
        aliases: ["Pathfinder Lost Omens- Divine Mysteries"], supplies: [.deityLore])
    static let list = SourcebookList(books: [divineMysteries], deities: [
        "abadar": LoreSources(stats: "Web Supplement", prose: "Pathfinder Lost Omens Divine Mysteries"),
        "anubis": LoreSources(stats: "Web Supplement")
    ])

    @Test func knowsABookByItsTitleFolderOrFileName() {
        for name in ["Pathfinder Lost Omens Divine Mysteries", "Pathfinder Lost Omens- Divine Mysteries",
                     "Pathfinder Lost Omens- Divine Mysteries PDF - Single File.pdf",
                     "PZO13003E Pathfinder Lost Omens: Divine Mysteries.pdf"] {
            #expect(Self.list.book(named: name) == Self.divineMysteries, "\(name)")
        }
        #expect(Self.list.book(named: "Pathfinder Lost Omens Gods & Magic") == nil)
    }

    @Test func listsTheDeitiesABookSupplies() {
        #expect(Set(Self.list.deities(from: Self.divineMysteries).keys) == ["abadar"])
    }

    @Test func namesEachSourceOnce() {
        #expect(LoreSources(stats: "A", prose: "A").books == ["A"])
        #expect(LoreSources(stats: "A", prose: "B").books == ["A", "B"])
        #expect(LoreSources().books.isEmpty)
    }

    @Test func shipsTheSurveyedList() throws {
        let list = SourcebookList.bundled
        let supplement = try #require(list.book(named: "Pathfinder Lost Omens Divine Mysteries Web Supplement"))
        #expect(supplement.downloadURL != nil && supplement.sku == "PZO13003WS")
        #expect(list.book(named: "PZO9303 Gods & Magic Web Supplement")?.isLegacy == true)
        #expect(list.deities.count > 400)
        #expect(list.deities.values.allSatisfy { sources in sources.books.allSatisfy { list.book(named: $0) != nil } })
    }

    @Test func readsAFileNameWithoutItsDecorations() {
        #expect(Sourcebook.key("PZO13003E Pathfinder Lost Omens- Divine Mysteries PDF - Single File.pdf")
                == Sourcebook.key("Pathfinder Lost Omens Divine Mysteries"))
        #expect(Sourcebook.key("Divine Mysteries Single-File.PDF") == Sourcebook.key("Divine Mysteries"))
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Self.list)
        #expect(try JSONDecoder().decode(SourcebookList.self, from: data) == Self.list)
    }
}
