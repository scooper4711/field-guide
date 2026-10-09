import Foundation

/// What lists and filters need to know about an entry; its page is loaded only when it is opened.
public struct EntrySummary: Identifiable, Hashable, Sendable {
    /// The entry's Foundry UUID, such as `Compendium.pf2e.spells-srd.Item.<id>`.
    public let id: String
    public let system: GameSystem
    public let category: EntryCategory
    public let name: String
    public let level: Int?
    /// Such as "Spell 3", "Creature 5" or "Weapon".
    public let subtitle: String
    /// A path inside the images folder, empty for none.
    public let image: String
    /// Values by facet, including rarity, traits and source.
    public let facets: [Facet: [String]]

    public init(id: String, system: GameSystem, category: EntryCategory, name: String, level: Int?,
                subtitle: String, image: String, facets: [Facet: [String]]) {
        self.id = id
        self.system = system
        self.category = category
        self.name = name
        self.level = level
        self.subtitle = subtitle
        self.image = image
        self.facets = facets
    }

    public func values(of facet: Facet) -> [String] { facets[facet] ?? [] }
}
