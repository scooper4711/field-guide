import ArtExtraction
import Foundation
import PDFKit
import Testing
import SourcebookLoreTestSupport
@testable import SourcebookLore

@Suite struct SampleSourcebookTests {
    static let marker = SampleSourcebook.marker

    @Test(arguments: SampleSourcebook.all.map(\.title))
    func everySampleCreatureReadsBackOpeningWithTheMarker(title: String) throws {
        let sample = try Self.sample(title)
        let creatures = CreatureWriteups().writeups(in: try #require(sample.document()))
        for family in sample.families {
            for creature in family.creatures {
                let lore = try #require(creatures[TextRepair.matchKey(creature.name)], "\(creature.name)")
                #expect(lore.paragraphs.first?.hasPrefix(Self.marker) == true, "\(creature.name)")
                if family.creatures.count > 1 || family.name != creature.name {
                    #expect(lore.family == family.name, "\(creature.name)")
                    #expect(lore.familyParagraphs.first?.hasPrefix(Self.marker) == true, "\(creature.name)")
                }
            }
        }
    }

    @Test(arguments: SampleSourcebook.all.map(\.title))
    func everySampleDeityAndDetailsReadsBackOpeningWithTheMarker(title: String) throws {
        let sample = try Self.sample(title)
        let document = try #require(sample.document())
        let deities = DeityWriteups(names: sample.deities).writeups(in: document)
        for name in sample.deities {
            let lore = try #require(deities[name], "\(name)")
            #expect(lore.statLines.map(\.label).contains("Edicts"), "\(name)")
            #expect(lore.paragraphs.first?.hasPrefix(Self.marker) == true, "\(name)")
        }
        let details = DetailsWriteups(names: sample.details.map(\.name)).writeups(in: document)
        for entry in sample.details {
            let lore = try #require(details[entry.name], "\(entry.name)")
            #expect(lore.sections.map(\.heading) == [""] + entry.sections, "\(entry.name)")
            #expect(lore.sections.first?.paragraphs.first?.text.hasPrefix(Self.marker) == true, "\(entry.name)")
            #expect(lore.sections.last?.paragraphs.allSatisfy(\.isBullet) == true, "\(entry.name)")
        }
    }

    @Test(arguments: SampleSourcebook.all.map(\.title))
    func aSampleIsKnownByItsPublishedFileName(title: String) {
        let file = URL(filePath: "/Downloads/\(title).pdf")
        let identifier = SourcebookIdentifier(list: SourcebookList(books: SourcebookList.samples))
        #expect(identifier.book(namedBy: file)?.title == title)
    }

    @Test func eachSampleCoversOnlyItsOwnGamesEntries() {
        let pathfinder = "Compendium.pf2e.deities.Item.d56paSkcwvll2OhR"
        let starfinder = "Compendium.sf2e.deities.Item.d56paSkcwvll2OhR"
        #expect(SourcebookList.sample(forEntry: pathfinder) == SourcebookList.pathfinderSample)
        #expect(SourcebookList.sample(forEntry: starfinder) == SourcebookList.starfinderSample)
        #expect(SourcebookList.sample(SourcebookList.starfinderSample.title, covers: starfinder))
        #expect(!SourcebookList.sample(SourcebookList.starfinderSample.title, covers: pathfinder))
        #expect(SourcebookList.sample(forEntry: "id.abadar") == nil)
        #expect(SourcebookList.sample(forEntry: "Compendium.other.deities.Item.x") == nil)
        #expect(SourcebookList.isSample(SourcebookList.starfinderSample.title) && !SourcebookList.isSample("Abadar"))
        #expect(SourcebookList.pathfinderSample.downloadURL?.absoluteString.hasSuffix(
            "Resources/Review/Field%20Guide%20Sample%20Monster%20Core.pdf") == true)
    }

    private static func sample(_ title: String) throws -> SampleSourcebook {
        try #require(SampleSourcebook.all.first { $0.title == title })
    }

    @Test(arguments: SampleSourcebook.all.map(\.title))
    func everySampleCreatureHasItsBestiarysStatBlockAndArt(title: String) throws {
        let sample = try Self.sample(title)
        for creature in sample.creatures {
            #expect(sample.statBlocks[creature.name] != nil, "\(creature.name)")
            #expect(creature.art != nil, "\(creature.name)")
        }
    }

    @Test(arguments: [(SampleSourcebook.pathfinder, "Pathfinder Monster Core © 2024"),
                      (SampleSourcebook.starfinder, "Starfinder Alien Core © 2025")])
    func everySampleCarriesTheORCNoticeAndItsBestiarysCredit(sample: SampleSourcebook, credit: String) throws {
        let text = try #require(sample.document()?.string)
        #expect(text.contains("ORC Notice") && text.contains(credit))
        #expect(text.contains("Paizo's Community Use Policy"))
        #expect(!text.contains("placeholder senses"))
    }

    /// Each creature's page holds its one picture, and no other page has any, so a picture is found by its page.
    @Test(arguments: SampleSourcebook.all.map(\.title))
    func everyCreatureHasItsPictureOnItsOwnPage(title: String) throws {
        let sample = try Self.sample(title)
        let document = try #require(sample.document())
        let counts = (0..<document.pageCount).map { index in
            document.page(at: index)?.pageRef.map { PageScanner.images(on: $0).count } ?? 0
        }
        let pictured = counts.indices.filter { counts[$0] == 1 }
        let pictureless = counts.indices.filter { counts[$0] == 0 }
        #expect(pictured.count == sample.creatures.count)
        #expect(pictured.count + pictureless.count == document.pageCount)
        for (index, creature) in zip(pictured, sample.creatures) {
            let text = document.page(at: index)?.string ?? ""
            #expect(text.contains("\(creature.name.uppercased()) CREATURE"), "\(creature.name)")
        }
    }
}
