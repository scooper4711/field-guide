import Foundation
import SourcebookLore
import Testing
@testable import FieldGuideUI

@Suite("Filtering the Sourcebooks list by whether a book has been processed or downloaded")
@MainActor
struct SourcebookFilterTests {
    static let processed = row("Processed Gods", sku: "PZO1", isRead: true)
    static let unprocessed = row("Unprocessed Gods", sku: nil, isRead: false)
    static let notDownloaded = row("Owned Gods", sku: "PZO2", isRead: false)
    static let downloaded = row("Downloaded Gods", sku: "PZO3", isRead: false)
    static let notOwned = row("Unowned Gods", sku: "PZO4", isRead: false)
    static let rows = [processed, unprocessed, notDownloaded, downloaded, notOwned]
    /// Scrollkeeper's list: PZO1 (processed) and PZO2 aren't downloaded, PZO3 is; PZO4 isn't owned.
    static let owned = ["PZO1": false, "PZO2": false, "PZO3": true]

    static func row(_ title: String, sku: String?, isRead: Bool) -> SourcebookRow {
        let book = Sourcebook(title: title, sku: sku, aliases: [], supplies: [.deityLore])
        let lore = BookLore(title: title, location: nil, sourceDigest: "a", sourceDate: nil, readerVersion: 1,
                            importedAt: Date(), deities: [:])
        return SourcebookRow(book: book, counts: .init(), read: isRead ? lore : nil)
    }

    @Test("All shows every sourcebook, in order")
    func all() {
        #expect(SourcebookFilter.all.rows(Self.rows, owned: Self.owned) == Self.rows)
    }

    @Test("Processed shows only the sourcebooks Field Guide has processed")
    func processed() {
        #expect(SourcebookFilter.processed.rows(Self.rows, owned: Self.owned) == [Self.processed])
    }

    @Test("Not Processed shows only the sourcebooks still to process")
    func notProcessed() {
        #expect(SourcebookFilter.notProcessed.rows(Self.rows, owned: Self.owned)
                == [Self.unprocessed, Self.notDownloaded, Self.downloaded, Self.notOwned])
    }

    @Test("Not Downloaded shows the unprocessed books owned in Scrollkeeper without a downloaded copy")
    func notDownloaded() {
        #expect(SourcebookFilter.notDownloaded.rows(Self.rows, owned: Self.owned) == [Self.notDownloaded])
    }

    @Test("Not Downloaded is offered only once Scrollkeeper's list has arrived")
    func choices() {
        #expect(SourcebookFilter.choices(owned: Self.owned) == SourcebookFilter.allCases)
        #expect(SourcebookFilter.choices(owned: [:]) == [.all, .processed, .notProcessed])
    }

    @Test("A remembered filter that isn't offered falls back to All")
    func effective() {
        #expect(SourcebookFilter.notDownloaded.effective(owned: [:]) == .all)
        #expect(SourcebookFilter.notDownloaded.effective(owned: Self.owned) == .notDownloaded)
        #expect(SourcebookFilter.processed.effective(owned: [:]) == .processed)
    }

    @Test("Each filter has a title for the picker and says so when it leaves nothing",
          arguments: SourcebookFilter.allCases)
    func wording(filter: SourcebookFilter) {
        #expect(!filter.title.isEmpty && !filter.emptyMessage.isEmpty)
        #expect(filter.id == filter)
    }

    @Test("With no processed sourcebooks, Processed leaves nothing and says so")
    func emptyProcessed() {
        #expect(SourcebookFilter.processed.rows([Self.unprocessed], owned: [:]).isEmpty)
        #expect(SourcebookFilter.processed.emptyMessage == "No processed sourcebooks yet.")
    }
}
