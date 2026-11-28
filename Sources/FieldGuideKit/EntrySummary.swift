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

    /// `entries` with `added` put among them by name, the order of `entries` kept: entries from outside the catalog,
    /// such as custom creatures, in a list the catalog ordered. Each goes after the last entry whose name comes before
    /// or with its own, so an entry the catalog put out of name order (a guide page) doesn't pull it along.
    public static func merging(_ added: [EntrySummary], into entries: [EntrySummary]) -> [EntrySummary] {
        var merged = entries
        for entry in added.sorted(by: Self.byName) {
            let index = merged.lastIndex { !byName(entry, $0) }.map { $0 + 1 } ?? merged.startIndex
            merged.insert(entry, at: index)
        }
        return merged
    }

    private static func byName(_ first: EntrySummary, _ second: EntrySummary) -> Bool {
        first.name.localizedStandardCompare(second.name) == .orderedAscending
    }
}

/// Entries under one section heading of a list.
public struct EntryGroup: Identifiable, Equatable, Sendable {
    public let title: String
    public let entries: [EntrySummary]

    public var id: String { title }

    /// `entries` grouped by their first section, the entries in their order and the groups in `order`.
    public static func bySection(_ entries: [EntrySummary], order: SectionOrder = .catalog) -> [EntryGroup] {
        let groups = inCatalogOrder(entries)
        guard order == .title else { return groups }
        return groups.sorted { first, second in
            if first.title.isEmpty || second.title.isEmpty { return second.title.isEmpty && !first.title.isEmpty }
            return first.title.localizedStandardCompare(second.title) == .orderedAscending
        }
    }

    /// The groups in the order their first entries come.
    private static func inCatalogOrder(_ entries: [EntrySummary]) -> [EntryGroup] {
        var titles: [String] = []
        var groups: [String: [EntrySummary]] = [:]
        for entry in entries {
            let title = entry.values(of: .section).first ?? ""
            if groups[title] == nil { titles.append(title) }
            groups[title, default: []].append(entry)
        }
        return titles.map { EntryGroup(title: $0, entries: groups[$0] ?? []) }
    }
}
