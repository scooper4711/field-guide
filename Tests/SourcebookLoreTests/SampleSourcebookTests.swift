import Foundation
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct SampleSourcebookTests {
    @Test func everySampleCreatureAndDeityReadsBack() throws {
        let document = try #require(SampleSourcebook.document())
        let creatures = CreatureWriteups().writeups(in: document)
        for family in SampleSourcebook.families {
            for creature in family.creatures {
                let lore = try #require(creatures[TextRepair.matchKey(creature.name)], "\(creature.name)")
                #expect(!lore.paragraphs.isEmpty, "\(creature.name)")
                if family.creatures.count > 1 || family.name != creature.name {
                    #expect(lore.family == family.name && !lore.familyParagraphs.isEmpty, "\(creature.name)")
                }
            }
        }
        let deities = DeityWriteups(names: SampleSourcebook.deities).writeups(in: document)
        for name in SampleSourcebook.deities {
            let lore = try #require(deities[name])
            #expect(lore.statLines.map(\.label).contains("Edicts") && !lore.paragraphs.isEmpty, "\(name)")
        }
        // The sample is known by its file's name, as published.
        let file = URL(filePath: "/Downloads/Field Guide Sample Monster Core.pdf")
        #expect(SourcebookIdentifier(list: SourcebookList(books: [SourcebookList.sample])).book(namedBy: file)
            == SourcebookList.sample)
    }
}
