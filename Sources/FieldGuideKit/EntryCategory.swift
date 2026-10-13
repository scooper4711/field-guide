import Foundation

/// The kinds of entry the app browses: the GM Screen, Foundry's compendium browser tabs, character options, then
/// the rules journals that are categories of their own and the rest of the journals.
public enum EntryCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case gmScreen
    case actions, bestiary, campaignFeatures, equipment, feats, hazards, spells
    case conditions, ancestries, heritages, backgrounds, classes, archetypes, deities, domains
    // swiftlint:disable:next inclusive_language - "Remaster" is Paizo's name for its revised rules
    case remasterChanges, journals

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .campaignFeatures: "Campaign Features"
        case .gmScreen: "GM Screen"
        case .remasterChanges: "Remaster Changes"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// One entry's kind: "Condition", "Ancestry", "Deity".
    public var singularTitle: String {
        switch self {
        case .ancestries: "Ancestry"
        case .classes: "Class"
        case .deities: "Deity"
        case .remasterChanges: "Remaster Change"
        case .bestiary: "Creature"
        case .gmScreen: "GM Screen"
        default: String(title.dropLast())
        }
    }

    /// An SF Symbol for the sidebar.
    public var symbol: String {
        switch self {
        case .gmScreen: "tablecells"
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
        case .archetypes: "person.crop.rectangle.stack"
        case .deities: "sun.max"
        case .domains: "circle.hexagongrid"
        case .remasterChanges: "arrow.triangle.2.circlepath"
        case .journals: "books.vertical"
        }
    }

    /// Whether entries have levels worth filtering and sorting by.
    public var hasLevels: Bool {
        switch self {
        case .gmScreen, .journals, .actions, .conditions, .ancestries, .heritages, .backgrounds, .classes, .deities,
             .archetypes, .domains, .remasterChanges:
            false
        default: true
        }
    }

    /// The category's own filters, after level, rarity, traits and source.
    public var facets: [Facet] {
        switch self {
        case .gmScreen, .journals: [.section]
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
