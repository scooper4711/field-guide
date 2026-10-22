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

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Self.list)
        #expect(try JSONDecoder().decode(SourcebookList.self, from: data) == Self.list)
    }
}
