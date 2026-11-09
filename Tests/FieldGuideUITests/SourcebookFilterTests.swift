import Foundation
import SourcebookLore
import Testing
@testable import FieldGuideUI

@Suite("Filtering the Sourcebooks list by whether a book has been processed")
@MainActor
struct SourcebookFilterTests {
    static let processed = row("Processed Gods", isRead: true)
    static let unprocessed = row("Unprocessed Gods", isRead: false)
    static let rows = [processed, unprocessed]

    static func row(_ title: String, isRead: Bool) -> SourcebookRow {
        let book = Sourcebook(title: title, sku: nil, aliases: [], supplies: [.deityLore])
        let lore = BookLore(title: title, location: nil, sourceDigest: "a", sourceDate: nil, readerVersion: 1,
                            importedAt: Date(), deities: [:])
        return SourcebookRow(book: book, counts: .init(), read: isRead ? lore : nil)
    }

    @Test("All shows every sourcebook, in order")
    func all() {
        #expect(SourcebookFilter.all.rows(Self.rows) == Self.rows)
    }

    @Test("Processed shows only the sourcebooks Field Guide has processed")
    func processed() {
        #expect(SourcebookFilter.processed.rows(Self.rows) == [Self.processed])
    }

    @Test("Not Processed shows only the sourcebooks still to process")
    func notProcessed() {
        #expect(SourcebookFilter.notProcessed.rows(Self.rows) == [Self.unprocessed])
    }

    @Test("Each filter has a title for the picker and says so when it leaves nothing",
          arguments: SourcebookFilter.allCases)
    func wording(filter: SourcebookFilter) {
        #expect(!filter.title.isEmpty && !filter.emptyMessage.isEmpty)
        #expect(filter.id == filter)
    }

    @Test("With no processed sourcebooks, Processed leaves nothing and says so")
    func emptyProcessed() {
        #expect(SourcebookFilter.processed.rows([Self.unprocessed]).isEmpty)
        #expect(SourcebookFilter.processed.emptyMessage == "No processed sourcebooks yet.")
    }
}
