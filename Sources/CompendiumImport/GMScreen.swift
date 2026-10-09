import FieldGuideKit
import Foundation

/// One page of a system's GM Screen journal.
struct JournalPage: Equatable {
    var system: GameSystem
    var category: EntryCategory = .gmScreen
    var journalID: String
    var pageID: String
    var name: String
    var section: String
    var html: String

    var uuid: String { "Compendium.\(system.rawValue).journals.JournalEntry.\(journalID).JournalEntryPage.\(pageID)" }
}

/// Reads the system's journals (`packs/<system>/journals/*.json`) into pages. GM Screen pages go under the
/// last level-1 page before them, their section, and level-1 pages with little text are only headings; the
/// other journals' pages go under the journal's name.
enum GMScreen {
    static let minimumText = 120
    static let gmScreenFile = "gm-screen.json"

    static func pages(repository: URL, system: GameSystem) -> [JournalPage] {
        let folder = repository.appendingPathComponent("packs/\(system.rawValue)/journals")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix("_") }.sorted()
        return files.flatMap { pages(in: folder.appendingPathComponent($0), system: system) }
    }

    private static func pages(in file: URL, system: GameSystem) -> [JournalPage] {
        guard let journal = try? JSONValue(contentsOf: file) else { return [] }
        let journalID = journal["_id"].string
        let isGMScreen = file.lastPathComponent == gmScreenFile
        var section = isGMScreen ? "" : journal["name"].string
        var pages: [JournalPage] = []
        for page in journal["pages"].array.sorted(by: { $0["sort"].int < $1["sort"].int }) {
            let html = page[path: "text.content"].string
            if isGMScreen, page[path: "title.level"].int == 1 { section = page["name"].string }
            guard HTML.plainText(html).count >= minimumText else { continue }
            pages.append(JournalPage(
                system: system, category: isGMScreen ? .gmScreen : .journals, journalID: journalID,
                pageID: page["_id"].string, name: page["name"].string,
                section: section, html: absoluteLinks(html, system: system, journalID: journalID)
            ))
        }
        return pages
    }

    /// `@UUID[.<page>]` links a page of the same journal; spelled out, the link index can follow it.
    static func absoluteLinks(_ html: String, system: GameSystem, journalID: String) -> String {
        let journal = "Compendium.\(system.rawValue).journals.JournalEntry.\(journalID)"
        return html.replacingOccurrences(of: "@UUID[.", with: "@UUID[\(journal).JournalEntryPage.")
    }

    static func row(_ page: JournalPage, context: PageContext) -> EntryRow {
        let html = "<header class=\"entry-header\"><div><h1>\(HTML.escape(page.name))</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(page.section))</p></div></header>"
            + "<section class=\"description journal\">\(context.enrich(page.html))</section>"
        return EntryRow(
            id: page.uuid, system: page.system, category: page.category, name: page.name, level: nil,
            subtitle: page.section, image: "", facets: page.section.isEmpty ? [:] : [.section: [page.section]],
            html: html, text: HTML.plainText(html), traitSlugs: []
        )
    }
}
