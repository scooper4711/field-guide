import Foundation

/// How a list is narrowed and ordered: name search, level range, chosen facet values and sort.
public struct EntryQuery: Equatable, Sendable {
    public enum Sort: String, CaseIterable, Sendable {
        case name, level
    }

    public var text = ""
    /// When true, `text` is matched against the entries' whole text by the catalog instead of their names.
    public var searchesText = false
    public var minimumLevel: Int?
    public var maximumLevel: Int?
    public var chosen: [Facet: Set<String>] = [:]
    public var sort = Sort.name

    public init(text: String = "", searchesText: Bool = false) {
        self.text = text
        self.searchesText = searchesText
    }

    public var isFiltered: Bool {
        minimumLevel != nil || maximumLevel != nil || chosen.values.contains { !$0.isEmpty }
    }

    /// The matching entries in order. `textMatches` holds the catalog's text-search results when
    /// `searchesText` is on.
    public func apply(to entries: [EntrySummary], textMatches: Set<String>? = nil) -> [EntrySummary] {
        let words = Self.folded(text).split(separator: " ").map(String.init)
        let matching = entries.filter { entry in
            matchesText(entry, words: words, textMatches: textMatches) && matchesLevel(entry) && matchesFacets(entry)
        }
        return sort == .level ? matching.sorted(by: Self.byLevel) : matching
    }

    private func matchesText(_ entry: EntrySummary, words: [String], textMatches: Set<String>?) -> Bool {
        if searchesText, let textMatches { return words.isEmpty || textMatches.contains(entry.id) }
        let name = Self.folded(entry.name)
        return words.allSatisfy(name.contains)
    }

    private func matchesLevel(_ entry: EntrySummary) -> Bool {
        guard minimumLevel != nil || maximumLevel != nil else { return true }
        guard let level = entry.level else { return false }
        return level >= (minimumLevel ?? .min) && level <= (maximumLevel ?? .max)
    }

    private func matchesFacets(_ entry: EntrySummary) -> Bool {
        chosen.allSatisfy { facet, values in
            guard !values.isEmpty else { return true }
            let entryValues = Set(entry.values(of: facet))
            return facet.matchesAll ? values.isSubset(of: entryValues) : !values.isDisjoint(with: entryValues)
        }
    }

    /// Lowest level first, entries without a level last, then by name.
    private static func byLevel(_ first: EntrySummary, _ second: EntrySummary) -> Bool {
        let firstLevel = first.level ?? .max
        let secondLevel = second.level ?? .max
        if firstLevel != secondLevel { return firstLevel < secondLevel }
        return first.name.localizedStandardCompare(second.name) == .orderedAscending
    }

    /// Lowercased, without accents, so "Elan" finds "Élan".
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// The values each facet takes among some entries, with how many entries have each.
public struct FacetOptions: Equatable, Sendable {
    public let counts: [Facet: [String: Int]]

    public init(entries: [EntrySummary], facets: [Facet]) {
        var counts: [Facet: [String: Int]] = [:]
        for entry in entries {
            for facet in facets {
                for value in entry.values(of: facet) { counts[facet, default: [:]][value, default: 0] += 1 }
            }
        }
        self.counts = counts
    }

    /// The facet's values in display order.
    public func values(of facet: Facet) -> [String] {
        facet.sorted(Array(counts[facet, default: [:]].keys))
    }

    public func count(of value: String, in facet: Facet) -> Int { counts[facet]?[value] ?? 0 }

    /// The lowest and highest level among the entries, or nil when none has a level.
    public static func levelRange(of entries: [EntrySummary]) -> ClosedRange<Int>? {
        let levels = entries.compactMap(\.level)
        guard let low = levels.min(), let high = levels.max() else { return nil }
        return low...high
    }
}
