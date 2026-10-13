import FieldGuideKit
import Foundation

/// The Ancestries and Classes journals' pages, each the Details of the ancestry or class of the same name in its
/// system. Pages no entry is named for (Index, Versatile Heritages) stay in the journals.
struct JournalDetails {
    /// The pages that are an entry's Details, by the entry's ID.
    private var pagesByOwner: [String: JournalPage] = [:]
    /// The entry each such page is the Details of, by the page's ID.
    private var ownersByPage: [String: String] = [:]
    /// The pages that are entries of their own.
    private(set) var entries: [JournalPage] = []

    init(pages: [JournalPage], documents: [SourceDocument]) {
        var owners: [String: String] = [:]
        for document in documents where [.ancestries, .classes].contains(document.category) {
            let key = Self.key(document.system, document.category, document.name)
            if owners[key] == nil { owners[key] = document.uuid }
        }
        for page in pages {
            if let category = page.detailsOf, let owner = owners[Self.key(page.system, category, page.name)],
               pagesByOwner[owner] == nil {
                pagesByOwner[owner] = page
                ownersByPage[page.uuid] = owner
            } else {
                entries.append(page)
            }
        }
    }

    /// Where links to `page` lead: its owner's Details, or the page.
    func linkTarget(of page: JournalPage) -> String {
        ownersByPage[page.uuid].map(EntryLink.details(of:)) ?? page.uuid
    }

    /// `rows` with each ancestry's and class's Details, whose text search finds too.
    func attaching(to rows: [EntryRow], context: PageContext) -> [EntryRow] {
        rows.map { row in
            guard let page = pagesByOwner[row.id] else { return row }
            var row = row
            row.details = GMScreen.details(page, context: context)
            row.text += " " + HTML.plainText(row.details)
            return row
        }
    }

    private static func key(_ system: GameSystem, _ category: EntryCategory, _ name: String) -> String {
        "\(system.rawValue).\(category.rawValue).\(name)"
    }
}
