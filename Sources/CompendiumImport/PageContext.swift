import FieldGuideKit
import Foundation

/// What page builders share: enrichment, links, traits and images.
final class PageContext {
    let enricher: Enricher
    let links: LinkIndex
    let glossary: TraitGlossary
    let images: ImageCollector

    init(enricher: Enricher, links: LinkIndex, glossary: TraitGlossary, images: ImageCollector) {
        self.enricher = enricher
        self.links = links
        self.glossary = glossary
        self.images = images
    }

    func enrich(_ html: String) -> String { enricher.enrich(html) }

    /// Enriches text that may be plain or HTML, for one-line fields such as triggers.
    func inline(_ text: String) -> String {
        let enriched = enrich(text)
        return enriched.replacingOccurrences(of: #"^\s*<p>(.*)</p>\s*$"#, with: "$1", options: .regularExpression)
    }

    /// A link to the entry a `Compendium.…` UUID names, or its name as plain text.
    func link(uuid: String, name: String) -> String {
        guard let target = links.entryID(forLink: uuid) else { return HTML.escape(name) }
        return HTML.link(name, to: "entry:\(target)")
    }

    func traits(_ system: GameSystem) -> TraitsHTML { TraitsHTML(glossary: glossary, system: system) }
}
