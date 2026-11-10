import ArtExtraction
import Foundation
import PDFKit
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct SampleSourcebookTests {
    @Test func everySampleCreatureAndDeityReadsBack() throws {
        let document = try #require(SampleSourcebook.document())
        let creatures = CreatureWriteups().writeups(in: document)
        for family in SampleSourcebook.families {
            for creature in family.creatures {
                #expect(SampleSourcebook.statBlocks[creature.name] != nil, "\(creature.name)")
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
        let details = DetailsWriteups(names: SampleSourcebook.details.map(\.name)).writeups(in: document)
        for entry in SampleSourcebook.details {
            let lore = try #require(details[entry.name])
            #expect(lore.sections.map(\.heading) == [""] + entry.sections, "\(entry.name)")
            #expect(lore.sections.last?.paragraphs.allSatisfy(\.isBullet) == true, "\(entry.name)")
        }
        // The sample is known by its file's name, as published.
        let file = URL(filePath: "/Downloads/Field Guide Sample Monster Core.pdf")
        #expect(SourcebookIdentifier(list: SourcebookList(books: [SourcebookList.sample])).book(namedBy: file)
            == SourcebookList.sample)
    }

    /// Each creature's page holds its one picture, and no other page has any, so a picture is found by its page.
    @Test func everyCreatureHasItsPictureOnItsOwnPage() throws {
        let document = try #require(SampleSourcebook.document())
        let counts = (0..<document.pageCount).map { index in
            document.page(at: index)?.pageRef.map { PageScanner.images(on: $0).count } ?? 0
        }
        let pictured = counts.indices.filter { counts[$0] == 1 }
        let pictureless = counts.indices.filter { counts[$0] == 0 }
        #expect(pictured.count == SampleSourcebook.creatures.count)
        #expect(pictured.count + pictureless.count == document.pageCount)
        for (index, creature) in zip(pictured, SampleSourcebook.creatures) {
            let text = document.page(at: index)?.string ?? ""
            #expect(text.contains("\(creature.name.uppercased()) CREATURE"), "\(creature.name)")
        }
    }
}
