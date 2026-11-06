import FieldGuideKit
import Foundation

/// One page of a system's rules journals.
struct JournalPage: Equatable {
    var system: GameSystem
    var category: EntryCategory = .gmScreen
    /// For the Ancestries and Classes journals, the category whose entry of the same name the page is the Details
    /// of; when no entry has its name, the page stays in `category`.
    var detailsOf: EntryCategory?
    var journalID: String
    var pageID: String
    var name: String
    var section: String
    var html: String

    var uuid: String { "Compendium.\(system.rawValue).journals.JournalEntry.\(journalID).JournalEntryPage.\(pageID)" }
}

/// Reads the system's journals (`packs/<system>/journals/*.json`) into pages. GM Screen pages go under the
/// last level-1 page before them, their section, and level-1 pages with little text are only headings; the
/// other journals' pages go under the journal's name. Archetypes, Domains and Remaster Changes are categories of
/// their own; the Ancestries and Classes pages are their entries' Details; the rest are Journals.
enum GMScreen {
    static let minimumText = 120
    static let gmScreenFile = "gm-screen.json"
    static let categories: [String: EntryCategory] = [
        gmScreenFile: .gmScreen, "archetypes.json": .archetypes, "domains.json": .domains,
        "remaster-changes.json": .remasterChanges
    ]
    static let details: [String: EntryCategory] = ["ancestries.json": .ancestries, "classes.json": .classes]

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
        let category = categories[file.lastPathComponent] ?? .journals
        var section = isGMScreen ? "" : journal["name"].string
        var pages: [JournalPage] = []
        for page in journal["pages"].array.sorted(by: { $0["sort"].int < $1["sort"].int }) {
            let html = page[path: "text.content"].string
            if isGMScreen, page[path: "title.level"].int == 1 { section = page["name"].string }
            guard HTML.plainText(html).count >= minimumText else { continue }
            pages.append(JournalPage(
                system: system, category: category, detailsOf: details[file.lastPathComponent], journalID: journalID,
                pageID: page["_id"].string, name: page["name"].string,
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
        // Pages of a category of their own read as its kind ("Archetype"), the others as their journal.
        let isOwnCategory = !page.category.facets.contains(.section)
        let subtitle = isOwnCategory ? page.category.singularTitle : page.section
        let html = "<header class=\"entry-header\"><div><h1>\(HTML.escape(page.name))</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(subtitle))</p></div></header>" + section(body)
        return EntryRow(
            id: page.uuid, system: page.system, category: page.category, name: page.name, level: nil,
            subtitle: subtitle, image: "",
            facets: isOwnCategory || page.section.isEmpty ? [:] : [.section: [page.section]],
            html: html, text: HTML.plainText(html), traitSlugs: []
        )
    }

    /// A page's text as an entry's Details: no header, since the entry's overview has one.
    static func details(_ page: JournalPage, context: PageContext) -> String {
        section(context.enrich(page.html))
    }

    private static func section(_ body: String) -> String {
        "<section class=\"description journal\">\(body)</section>"
    }
}
