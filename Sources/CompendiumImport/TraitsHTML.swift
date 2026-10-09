import FieldGuideKit
import Foundation

/// The row of trait tags under an entry's name: rarity (unless common), size, then the traits.
struct TraitsHTML {
    let glossary: TraitGlossary
    let system: GameSystem

    func html(rarity: String, size: String = "", traits: [String]) -> String {
        var tags: [String] = []
        if !rarity.isEmpty, rarity != "common" { tags.append(tag(slug: rarity, className: "trait rarity-\(rarity)")) }
        if let size = Formatting.sizes[size] { tags.append("<span class=\"trait size\">\(size)</span>") }
        tags += traits.map { tag(slug: $0, className: "trait") }
        return tags.isEmpty ? "" : "<div class=\"traits\">\(tags.joined(separator: " "))</div>"
    }

    /// Display labels for filtering.
    func labels(_ traits: [String]) -> [String] {
        traits.map { glossary.label(of: $0, in: system) }
    }

    private func tag(slug: String, className: String) -> String {
        let label = HTML.escape(glossary.label(of: slug, in: system))
        guard glossary.description(of: slug, in: system) != nil else {
            return "<span class=\"\(className)\">\(label)</span>"
        }
        return "<a class=\"\(className)\" href=\"trait:\(HTML.escape(slug))\">\(label)</a>"
    }
}
