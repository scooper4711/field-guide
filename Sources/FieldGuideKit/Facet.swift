import Foundation

/// A filter an entry has values for. Every entry has rarity, traits and source; the others belong to
/// particular categories (`EntryCategory.facets`).
public enum Facet: String, CaseIterable, Codable, Sendable, Identifiable {
    case rarity, traits, source
    case actionType, size, featCategory, itemType, complexity, rank, spellKind, tradition, castingTime, section

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rarity: "Rarity"
        case .traits: "Traits"
        case .source: "Source"
        case .actionType: "Actions"
        case .size: "Size"
        case .featCategory: "Category"
        case .itemType: "Item Type"
        case .complexity: "Complexity"
        case .rank: "Rank"
        case .spellKind: "Kind"
        case .tradition: "Tradition"
        case .castingTime: "Casting Time"
        case .section: "Section"
        }
    }

    /// True when an entry must have every chosen value, as with traits; otherwise any one will do.
    public var matchesAll: Bool { self == .traits }

    /// Orders this facet's values for display: rarity and size by their game order, the rest naturally.
    public func sorted(_ values: [String]) -> [String] {
        guard let order = Self.orders[self] else {
            return values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return values.sorted { (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1)
            ?? order.count, $1) }
    }

    private static let orders: [Facet: [String]] = [
        .rarity: ["Common", "Uncommon", "Rare", "Unique"],
        .size: ["Tiny", "Small", "Medium", "Large", "Huge", "Gargantuan"],
        .rank: ["Cantrip", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
        .actionType: ["One Action", "Two Actions", "Three Actions", "Reaction", "Free Action", "Passive"]
    ]
}
