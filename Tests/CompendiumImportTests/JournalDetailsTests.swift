import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct JournalDetailsTests {
    static let journalPage = "Compendium.pf2e.journals.JournalEntry"

    private func importedCatalog(_ repository: FakeRepository) throws -> Catalog {
        try repository.writeRulesJournals()
        let options = ImportOptions(paths: repository.paths, output: repository.output,
                                    workFolder: repository.root.appendingPathComponent("work"))
        _ = try CompendiumImporter(options: options).run()
        return try Catalog(url: repository.output.appendingPathComponent("catalog.sqlite"))
    }

    @Test func linksToADetailsPageOpenItsEntrysDetails() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository)
        let index = try #require(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anI"))
        #expect(index.html.contains("<a href=\"entry:Compendium.pf2e.ancestries.Item.el1#details\">Elf</a>"))
    }

    @Test func otherJournalsAreCategoriesOrStayInJournals() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository)
        for (category, name, subtitle) in [(EntryCategory.archetypes, "Acrobat", "Archetype"),
                                           (.domains, "Fire Domain", "Domain")] {
            let entries = try catalog.summaries(of: category, in: .pathfinder)
            #expect(entries.map(\.name) == [name] && entries.first?.subtitle == subtitle)
            #expect(entries.first?.facets.isEmpty == true)
        }
        let ancestries = try catalog.summaries(of: .ancestries, in: .pathfinder)
        #expect(ancestries.map(\.name) == ["Index", "Standardized Ancestry Feats", "Elf"])
        #expect(ancestries.first?.subtitle == "Ancestries")
        #expect(try catalog.summaries(of: .heritages, in: .pathfinder).first?.name == "Versatile Heritages")
        #expect(try catalog.summaries(of: .classes, in: .pathfinder).map(\.name)
            == ["Fighter", "Draconic Sorcerer Bloodlines", "Draconic Connections"])
        #expect(try catalog.categories(in: .pathfinder).contains(.archetypes))
    }

    @Test func ancestriesAndClassesKeepTheRulesOfTheirDetailsButNotTheLore() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository)
        let elf = try #require(try catalog.page(of: "Compendium.pf2e.ancestries.Item.el1"))
        let start = "<section class=\"description journal\">\(DetailsPage.loreMarker)<h2>Elf Mechanics"
        #expect(elf.details.hasPrefix(start))
        #expect(elf.details.contains("Hit Points 6") && !elf.details.contains("Elves live long lives."))
        let fighter = try #require(try catalog.page(of: "Compendium.pf2e.classes.Item.fi1")?.details)
        #expect(fighter.contains("Key Attribute Strength") && fighter.contains("Expert in Fortitude"))
        #expect(fighter.contains(DetailsPage.loreMarker) && !fighter.contains("Fighters train hard."))
        #expect(try catalog.search("elves", in: .ancestries, of: .pathfinder).isEmpty)
        #expect(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anE") == nil)
        // Links to a Details page open its entry, and the journals' other pages stay, as guides.
        let index = try #require(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anI"))
        #expect(index.html.contains("<a href=\"entry:Compendium.pf2e.ancestries.Item.el1#details\">Elf</a>"))
    }

    @Test func journalsNoRulePlacesAreReportedAndTheOnesNotShownAreLeftOut() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository)
        let reading = GMScreen.read(repository: repository.repository, system: .pathfinder)

        #expect(reading.unplaced == ["Compendium.pf2e.journals.JournalEntry.Mystery": 1])
        #expect(reading.pages.contains { $0.journalID == "an1" })
        // Remaster Changes and the Hero Point Deck are skipped without a mention.
        #expect(!reading.pages.contains { ["re1", "he1", "my1"].contains($0.journalID) })
        #expect(try catalog.page(of: "\(Self.journalPage).re1.JournalEntryPage.reS") == nil)
        #expect(try catalog.page(of: "\(Self.journalPage).he1.JournalEntryPage.heC") == nil)
        #expect(try catalog.page(of: "\(Self.journalPage).my1.JournalEntryPage.myH") == nil)
        #expect(try catalog.search("renamed spells", in: .ancestries, of: .pathfinder).isEmpty)
    }
}
