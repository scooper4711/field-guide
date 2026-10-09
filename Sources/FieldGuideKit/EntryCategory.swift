import Foundation

/// The kinds of entry the app browses: Foundry's compendium browser tabs, then character options.
public enum EntryCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case actions, bestiary, campaignFeatures, equipment, feats, hazards, spells
    case conditions, ancestries, heritages, backgrounds, classes, deities

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .campaignFeatures: "Campaign Features"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// One entry's kind: "Condition", "Ancestry", "Deity".
    public var singularTitle: String {
        switch self {
        case .ancestries: "Ancestry"
        case .classes: "Class"
        case .deities: "Deity"
        case .bestiary: "Creature"
        default: String(title.dropLast())
        }
    }

    /// An SF Symbol for the sidebar.
    public var symbol: String {
        switch self {
        case .actions: "figure.run"
        case .bestiary: "pawprint"
        case .campaignFeatures: "flag"
        case .equipment: "shield.lefthalf.filled"
        case .feats: "star"
        case .hazards: "exclamationmark.triangle"
        case .spells: "sparkles"
        case .conditions: "bandage"
        case .ancestries: "person.2"
        case .heritages: "person.crop.circle.badge.plus"
        case .backgrounds: "book.closed"
        case .classes: "graduationcap"
        case .deities: "sun.max"
        }
    }

    /// Whether entries have levels worth filtering and sorting by.
    public var hasLevels: Bool {
        switch self {
        case .actions, .conditions, .ancestries, .heritages, .backgrounds, .classes, .deities: false
        default: true
        }
    }

    /// The category's own filters, after level, rarity, traits and source.
    public var facets: [Facet] {
        switch self {
        case .actions: [.actionType]
        case .bestiary: [.size]
        case .campaignFeatures, .feats: [.featCategory]
        case .equipment: [.itemType]
        case .hazards: [.complexity]
        case .spells: [.rank, .spellKind, .tradition, .castingTime]
        default: []
        }
    }
}
