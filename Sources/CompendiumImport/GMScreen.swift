import FieldGuideKit
import Foundation

/// The pages of a system's journals, and how many pages of journals no rule places were left out.
struct JournalReading {
    var pages: [JournalPage] = []
    var unplaced: [String: Int] = [:]
}

/// One page of a system's rules journals.
struct JournalPage: Equatable {
    var system: GameSystem
    var category: EntryCategory = .gmScreen
    /// For the Ancestries and Classes journals, the category whose entry of the same name the page is the Details
    /// of; when no entry has its name, the page stays in `category`.
    var detailsOf: EntryCategory?
    /// What the list sorts the page by instead of its name; empty to sort by name. Set for the guides.
    var sortKey = ""
    var journalID: String
    var pageID: String
    var name: String
    var section: String
    var html: String

    var uuid: String { "Compendium.\(system.rawValue).journals.JournalEntry.\(journalID).JournalEntryPage.\(pageID)" }
}

/// Reads the system's journals (`packs/<system>/journals/*.json`) into pages. GM Screen pages go under the
/// last level-1 page before them, their section, and level-1 pages with little text are only headings; the
/// other journals' pages go where `JournalPlacement` puts them. A journal it does not place is reported, not shown.
enum GMScreen {
    static let minimumText = 120
    static let gmScreenFile = "gm-screen.json"

    static func pages(repository: URL, system: GameSystem) -> [JournalPage] {
        read(repository: repository, system: system).pages
    }

    static func read(repository: URL, system: GameSystem) -> JournalReading {
        let folder = repository.appendingPathComponent("packs/\(system.rawValue)/journals")
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix("_") && !JournalPlacement.skippedFiles.contains($0) }
            .sorted()
        var reading = JournalReading()
        for file in files {
            let url = folder.appendingPathComponent(file)
            guard JournalPlacement.category(ofFile: file) != nil else {
                let journal = (try? JSONValue(contentsOf: url)) ?? JSONValue.null
                reading.unplaced["Compendium.\(system.rawValue).journals.JournalEntry.\(journal["name"].string)"] =
                    journal["pages"].array.count
                continue
            }
            reading.pages += pages(in: url, system: system)
        }
        return reading
    }

    private static func pages(in file: URL, system: GameSystem) -> [JournalPage] {
        guard let journal = try? JSONValue(contentsOf: file) else { return [] }
        let journalID = journal["_id"].string
        let isGMScreen = file.lastPathComponent == gmScreenFile
        let fileName = file.lastPathComponent
        var section = isGMScreen ? "" : journal["name"].string
        var pages: [JournalPage] = []
        for page in journal["pages"].array.sorted(by: { $0["sort"].int < $1["sort"].int }) {
            let html = page[path: "text.content"].string
            if isGMScreen, page[path: "title.level"].int == 1 { section = page["name"].string }
            guard HTML.plainText(html).count >= minimumText else { continue }
            let name = page["name"].string
            let guide = JournalPlacement.guide(file: fileName, page: name)
            pages.append(JournalPage(
                system: system, category: guide?.category ?? JournalPlacement.category(ofFile: fileName) ?? .gmScreen,
                detailsOf: guide == nil ? JournalPlacement.details[fileName] : nil, sortKey: guide?.sortKey ?? "",
                journalID: journalID, pageID: page["_id"].string, name: name,
                section: section, html: absoluteLinks(html, system: system, journalID: journalID)
            ))
        }
        return pages
    }

    /// Adds a row linking the area diagrams to the end of the first table (Playing the Game).
    static func linkingAreas(_ html: String, entry: String) -> String {
        guard let end = html.range(of: "</tbody></table>") else { return html }
        let row = "<tr><td><p>\(HTML.link("Areas", to: "entry:\(entry)"))</p></td><td></td><td></td></tr>"
        return html.replacingCharacters(in: end.lowerBound..<end.lowerBound, with: row)
    }

    /// `@UUID[.<page>]` links a page of the same journal; spelled out, the link index can follow it.
    static func absoluteLinks(_ html: String, system: GameSystem, journalID: String) -> String {
        let journal = "Compendium.\(system.rawValue).journals.JournalEntry.\(journalID)"
        return html.replacingOccurrences(of: "@UUID[.", with: "@UUID[\(journal).JournalEntryPage.")
    }

    /// `areasEntry`, when given, is linked from the GM Screen's index page, in its first table.
    static func row(_ page: JournalPage, context: PageContext, areasEntry: String? = nil) -> EntryRow {
        var body = RulesDiagrams.adding(to: context.enrich(page.html), of: page)
        if let areasEntry, page.name == "GM Screen" { body = linkingAreas(body, entry: areasEntry) }
        // Pages of a category of their own read as its kind ("Archetype"); the others, and the guides, as their
        // journal.
        let isOwnCategory = !page.category.facets.contains(.section)
        let subtitle = isOwnCategory && page.sortKey.isEmpty ? page.category.singularTitle : page.section
        let html = "<header class=\"entry-header\"><div><h1>\(HTML.escape(page.name))</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(subtitle))</p></div></header>" + section(body)
        return EntryRow(
            id: page.uuid, system: page.system, category: page.category, name: page.name, level: nil,
            subtitle: subtitle, image: "",
            facets: isOwnCategory || page.section.isEmpty ? [:] : [.section: [page.section]],
            html: html, text: HTML.plainText(html), traitSlugs: [], sortKey: page.sortKey
        )
    }

    /// A page's rules as an entry's Details: no header, since the entry's overview has one, and the setting's lore
    /// left out (`DetailsPage`), for the app to fill from the user's book.
    static func details(_ page: JournalPage, context: PageContext) -> String {
        section(context.enrich(DetailsPage.removingLore(from: page.html)))
    }

    private static func section(_ body: String) -> String {
        "<section class=\"description journal\">\(body)</section>"
    }
}
