import CreatureImport
import FieldGuideKit
import Foundation

/// One entry ready for the catalog.
public struct EntryRow: Sendable {
    public var id: String
    public var system: GameSystem
    public var category: EntryCategory
    public var name: String
    public var level: Int?
    public var subtitle: String
    public var image: String
    public var facets: [Facet: [String]]
    public var html: String
    /// The page's text, for full-text search.
    public var text: String
    /// The trait slugs the page shows, whose descriptions the catalog keeps.
    public var traitSlugs: [String]
    /// An ancestry's or class's journal page, its Details; empty for other entries.
    public var details = ""
}

/// Builds an entry's page: header with image, traits, details or stat block, description and source.
struct PageBuilder {
    /// The image path of a creature's art, followed by its key (`<system>.<pack>.<id>`), as the bestiary keys it.
    static let creatureArtPrefix = "creature/"

    let context: PageContext
    /// Whether creatures' descriptions and deities' write-ups are kept (`ImportOptions.includesLore`).
    var includesLore = true
    /// The sources whose lore is always kept: the Community Use Policy lets a free project use "any of the text
    /// or artwork published in the Paizo Blog".
    static let communityUseSources = ["Paizo Blog", "Pathfinder Blog"]

    func row(for document: SourceDocument) -> EntryRow {
        let traitsJSON = document.systemData["traits"]
        let slugs = traitsJSON["value"].strings
        let traitsHTML = context.traits(document.system)
        let facets = FacetExtractor.facets(of: document, traitLabels: traitsHTML.labels(slugs))
        let image = image(of: document)
        let html = [
            header(document, image: image, subtitle: facets.subtitle),
            traitsHTML.html(rarity: traitsJSON["rarity"].string, size: traitsJSON[path: "size.value"].string,
                            traits: slugs),
            body(document),
            footer(document)
        ].joined()
        return EntryRow(
            id: document.uuid, system: document.system, category: document.category, name: document.name,
            level: facets.level, subtitle: facets.subtitle, image: image, facets: facets.values, html: html,
            text: HTML.plainText(html), traitSlugs: slugs + [traitsJSON["rarity"].string].filter { !$0.isEmpty }
        )
    }

    private func header(_ document: SourceDocument, image: String, subtitle: String) -> String {
        let system = document.systemData
        let glyph = Formatting.actionGlyph(type: system[path: "actionType.value"].string,
                                           count: system[path: "actions.value"].optionalInt)
        let spellTime = document.category == .spells ? Formatting.time(system[path: "time.value"].string) : ""
        let title = "<div><h1>\(HTML.escape(document.name)) \(glyph)\(spellTime)</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(subtitle))</p></div>"
        // A religious symbol sits in the top-right corner, other art on the left.
        if image.hasPrefix(ImageCollector.symbolFolder + "/") {
            return "<header class=\"entry-header\">\(title)\(picture(image, className: "symbol"))</header>"
        }
        return "<header class=\"entry-header\">\(picture(image, className: "art"))\(title)</header>"
    }

    /// The image's `<img>`, or "" for none. A creature's art may be missing; its image then takes no room.
    private func picture(_ image: String, className: String) -> String {
        image.isEmpty ? "" : "<img class=\"\(className)\" src=\"\(HTML.imageURL(image))\" alt=\"\" "
            + "onerror=\"this.remove()\">"
    }

    private func body(_ document: SourceDocument) -> String {
        let system = document.systemData
        switch document.category {
        case .bestiary:
            return CreatureBlock.html(document, context: context)
                + lore(system[path: "details.publicNotes"].string, of: document, values: CreatureBlock.values(system))
        case .hazards:
            return HazardBlock.html(document, context: context)
        default:
            let details = DetailLines.html(document, context: context)
            let text = system[path: "description.value"].string
            let values = FormulaValues.level(system[path: "level.value"].int)
            return (details.isEmpty ? "" : "<section class=\"details\">\(details)</section>")
                + (document.category == .deities
                    ? lore(text, of: document, values: values) : description(text, values: values))
        }
    }

    /// A description that is the setting's lore (a creature's, a deity's), or "" when the import leaves lore out
    /// and the Community Use Policy doesn't cover the document's source.
    private func lore(_ html: String, of document: SourceDocument, values: FormulaValues) -> String {
        includesLore || Self.isCommunityUse(document) ? description(html, values: values) : ""
    }

    private static func isCommunityUse(_ document: SourceDocument) -> Bool {
        let source = FacetExtractor.sourceTitle(of: document)
        return communityUseSources.contains { source.hasPrefix($0) }
    }

    /// The description, its formulas worked out from the entry's rank or level (`@item.level`, `@item.rank`).
    private func description(_ html: String, values: FormulaValues) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "<hr>" + PageDescription.section(context.enrich(trimmed, values: values))
    }

    private func footer(_ document: SourceDocument) -> String {
        let title = FacetExtractor.sourceTitle(of: document)
        return title.isEmpty ? "" : "<footer class=\"source\">\(HTML.escape(title))</footer>"
    }

    /// A creature's art, drawn on the device from the user's own PDFs (`creature/<key>`); an item's art from the
    /// user's item decks, else its Rexard icon (`ItemArtPath`); a deity's religious symbol; else the document's
    /// Rexard icon.
    private func image(of document: SourceDocument) -> String {
        switch document.category {
        case .bestiary, .hazards:
            let key = "\(document.system.rawValue).\(document.pack.linkName).\(document.json["_id"].string)"
            return Self.creatureArtPrefix + key
        case .equipment:
            return ItemArtPath(system: document.system, name: document.name,
                               fallback: context.images.icon(of: document)).path
        case .deities:
            let symbol = context.images.symbol(of: document)
            return symbol.isEmpty ? context.images.icon(of: document) : symbol
        default:
            return context.images.icon(of: document)
        }
    }
}
