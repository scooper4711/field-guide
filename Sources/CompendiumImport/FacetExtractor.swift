import FieldGuideKit
import Foundation

/// An entry's level, subtitle and filter values.
struct EntryFacets: Equatable {
    var level: Int?
    var subtitle: String
    var values: [Facet: [String]]
}

/// Reads level, subtitle and facets from a document.
enum FacetExtractor {
    static func facets(of document: SourceDocument, traitLabels: [String]) -> EntryFacets {
        let traits = traitsJSON(of: document)
        var values: [Facet: [String]] = [
            .rarity: [Words.title(traits["rarity"].string.isEmpty ? "common" : traits["rarity"].string)],
            .traits: traitLabels,
            .source: [sourceTitle(of: document)].filter { !$0.isEmpty }
        ]
        values.merge(own(document), uniquingKeysWith: { _, own in own })
        let level = level(of: document)
        return EntryFacets(level: level, subtitle: subtitle(document, level: level),
                           values: values.filter { !$0.value.isEmpty && $0.value != [""] })
    }

    /// Actors keep traits and publication under `details`/`traits`; items directly under `system`.
    static func traitsJSON(of document: SourceDocument) -> JSONValue {
        document.systemData["traits"]
    }

    static func sourceTitle(of document: SourceDocument) -> String {
        let system = document.systemData
        let title = system[path: "publication.title"].string
        return title.isEmpty ? system[path: "details.publication.title"].string : title
    }

    static func level(of document: SourceDocument) -> Int? {
        let system = document.systemData
        switch document.category {
        case .bestiary, .hazards: return system[path: "details.level.value"].optionalInt
        case .actions, .conditions, .ancestries, .heritages, .backgrounds, .classes, .deities: return nil
        default: return system[path: "level.value"].optionalInt
        }
    }

    private static func own(_ document: SourceDocument) -> [Facet: [String]] {
        let system = document.systemData
        switch document.category {
        case .actions:
            return [.actionType: [Formatting.actionTypeName(type: system[path: "actionType.value"].string,
                                                            count: system[path: "actions.value"].optionalInt)]]
        case .bestiary: return [.size: [Formatting.sizes[system[path: "traits.size.value"].string] ?? ""]]
        case .feats, .campaignFeatures: return [.featCategory: [featCategory(system["category"].string)]]
        case .equipment: return [.itemType: [itemType(document.type)]]
        case .hazards: return [.complexity: [system[path: "details.isComplex"].bool ? "Complex" : "Simple"]]
        case .spells: return SpellFacets.values(system)
        default: return [:]
        }
    }

    static func featCategory(_ slug: String) -> String {
        let names = ["classfeature": "Class Feature", "ancestryfeature": "Ancestry Feature", "pfsboon": "PFS Boon",
                     "deityboon": "Deity Boon"]
        return names[slug] ?? Words.title(slug)
    }

    static func itemType(_ type: String) -> String {
        ["backpack": "Container", "ammo": "Ammunition"][type] ?? Words.title(type)
    }

    private static func subtitle(_ document: SourceDocument, level: Int?) -> String {
        let levelText = level.map { " \($0)" } ?? ""
        switch document.category {
        case .spells: return SpellFacets.kindName(document.systemData) + levelText
        case .bestiary: return "Creature" + levelText
        case .hazards: return "Hazard" + levelText
        case .feats, .campaignFeatures: return featCategory(document.systemData["category"].string) + levelText
        case .equipment: return itemType(document.type) + levelText
        case .actions:
            let system = document.systemData
            return Formatting.actionTypeName(type: system[path: "actionType.value"].string,
                                             count: system[path: "actions.value"].optionalInt)
        case .deities:
            // A deity, pantheon, covenant or philosophy.
            let kind = document.systemData["category"].string
            return kind.isEmpty ? document.category.singularTitle : Words.title(kind)
        default: return document.category.singularTitle
        }
    }
}

/// A spell's rank, kind, traditions and casting time.
enum SpellFacets {
    static func values(_ system: JSONValue) -> [Facet: [String]] {
        let traits = system[path: "traits.value"].strings
        let isCantrip = traits.contains("cantrip")
        return [
            .rank: [isCantrip ? "Cantrip" : system[path: "level.value"].string],
            .spellKind: kinds(system),
            .tradition: system[path: "traits.traditions"].strings.map(Words.title),
            .castingTime: [Formatting.castingTimeName(system[path: "time.value"].string)].filter { !$0.isEmpty }
        ]
    }

    static func kinds(_ system: JSONValue) -> [String] {
        let traits = system[path: "traits.value"].strings
        var kinds: [String] = []
        if traits.contains("cantrip") { kinds.append("Cantrip") }
        if traits.contains("focus") { kinds.append("Focus") }
        if system["ritual"].object.isEmpty == false || traits.contains("ritual") { kinds.append("Ritual") }
        return kinds.isEmpty ? ["Spell"] : kinds
    }

    /// "Cantrip", "Focus", "Ritual" or "Spell", as the subtitle says it.
    static func kindName(_ system: JSONValue) -> String {
        let kinds = kinds(system)
        if kinds.contains("Focus") { return "Focus" }
        return kinds.first ?? "Spell"
    }
}
