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
}

/// Builds an entry's page: header with image, traits, details or stat block, description and source.
struct PageBuilder {
    /// The image path of a creature's art, followed by its key (`<system>.<pack>.<id>`), as the bestiary keys it.
    static let creatureArtPrefix = "creature/"

    let context: PageContext

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
        // A creature's art may be missing; its image then takes no room.
        let picture = image.isEmpty ? "" : "<img class=\"art\" src=\"\(HTML.imageURL(image))\" alt=\"\" "
            + "onerror=\"this.remove()\">"
        return "<header class=\"entry-header\">\(picture)<div><h1>\(HTML.escape(document.name)) " +
            "\(glyph)\(spellTime)</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(subtitle))</p></div></header>"
    }

    private func body(_ document: SourceDocument) -> String {
        let system = document.systemData
        switch document.category {
        case .bestiary:
            return CreatureBlock.html(document, context: context)
                + description(system[path: "details.publicNotes"].string)
        case .hazards:
            return HazardBlock.html(document, context: context)
        default:
            let details = DetailLines.html(document, context: context)
            return (details.isEmpty ? "" : "<section class=\"details\">\(details)</section>")
                + description(system[path: "description.value"].string)
        }
    }

    private func description(_ html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "<hr><section class=\"description\">\(context.enrich(trimmed))</section>"
    }

    private func footer(_ document: SourceDocument) -> String {
        let title = FacetExtractor.sourceTitle(of: document)
        return title.isEmpty ? "" : "<footer class=\"source\">\(HTML.escape(title))</footer>"
    }

    /// A creature's art, drawn on the device from the user's own PDFs (`creature/<key>`), else the document's
    /// Rexard icon.
    private func image(of document: SourceDocument) -> String {
        if document.category == .bestiary || document.category == .hazards {
            let key = "\(document.system.rawValue).\(document.pack.linkName).\(document.json["_id"].string)"
            return Self.creatureArtPrefix + key
        }
        return context.images.icon(of: document)
    }
}
