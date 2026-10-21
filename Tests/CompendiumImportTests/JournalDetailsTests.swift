import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct JournalDetailsTests {
    static let journalPage = "Compendium.pf2e.journals.JournalEntry"

    private func importedCatalog(_ repository: FakeRepository,
                                 configure: (inout ImportOptions) -> Void = { _ in }) throws -> Catalog {
        try repository.writeRulesJournals()
        var options = ImportOptions(paths: repository.paths, output: repository.output,
                                    workFolder: repository.root.appendingPathComponent("work"))
        configure(&options)
        _ = try CompendiumImporter(options: options).run()
        return try Catalog(url: repository.output.appendingPathComponent("catalog.sqlite"))
    }

    @Test func ancestryAndClassPagesAreTheirEntriesDetails() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository)
        let elf = try #require(try catalog.page(of: "Compendium.pf2e.ancestries.Item.el1"))
        #expect(elf.details.contains("Elves live long lives.") && !elf.details.contains("entry-header"))
        let fighter = try #require(try catalog.page(of: "Compendium.pf2e.classes.Item.fi1"))
        #expect(fighter.details.contains("Fighters train hard."))
        #expect(try catalog.search("elves", in: .ancestries, of: .pathfinder).count == 1)
        #expect(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anE") == nil)
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
                                           (.domains, "Fire Domain", "Domain"),
                                           (.remasterChanges, "Spells", "Remaster Change")] {
            let entries = try catalog.summaries(of: category, in: .pathfinder)
            #expect(entries.map(\.name) == [name] && entries.first?.subtitle == subtitle)
            #expect(entries.first?.facets.isEmpty == true)
        }
        let journals = try catalog.summaries(of: .journals, in: .pathfinder)
        #expect(journals.map(\.name) == ["Draconic Connections", "Index", "Last Stand"])
        #expect(journals.map { $0.values(of: .section) } == [["Classes"], ["Ancestries"], ["Hero Point Deck"]])
        #expect(try catalog.categories(in: .pathfinder).contains(.archetypes))
    }

    @Test func withoutLoreAncestriesAndClassesHaveNoDetails() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let catalog = try importedCatalog(repository) { $0.includesLore = false }
        let elf = try #require(try catalog.page(of: "Compendium.pf2e.ancestries.Item.el1"))
        #expect(elf.details.isEmpty)
        #expect(try catalog.page(of: "Compendium.pf2e.classes.Item.fi1")?.details.isEmpty == true)
        #expect(try catalog.search("elves", in: .ancestries, of: .pathfinder).isEmpty)
        #expect(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anE") == nil)
        // Links to a Details page open its entry, and the journals' other pages stay.
        let index = try #require(try catalog.page(of: "\(Self.journalPage).an1.JournalEntryPage.anI"))
        #expect(index.html.contains("<a href=\"entry:Compendium.pf2e.ancestries.Item.el1#details\">Elf</a>"))
        #expect(try catalog.summaries(of: .journals, in: .pathfinder).map(\.name)
            == ["Draconic Connections", "Index", "Last Stand"])
    }
}
