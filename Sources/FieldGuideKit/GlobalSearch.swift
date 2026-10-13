import Foundation

/// Search across every category of a system, grouped by category with the first few matches of each, the group
/// with the best match first: entries whose name has every word, as the lists match them, or the catalog's ranked
/// matches of their text.
public struct GlobalSearch: Sendable {
    /// One category's matches: the first few, and how many there are in all.
    public struct Group: Identifiable, Equatable, Sendable {
        public let category: EntryCategory
        public let entries: [EntrySummary]
        public let total: Int

        public var id: EntryCategory { category }
    }

    /// How many matches a group shows.
    public static let limit = 10

    private struct Named: Sendable {
        let entry: EntrySummary
        /// The name folded for matching, as `EntryQuery` folds it.
        let name: String
    }

    private let entries: [Named]
    private let entriesByID: [String: EntrySummary]

    /// `entries` are every entry of the system, in the order ties are broken: by name.
    public init(entries: [EntrySummary]) {
        self.entries = entries.map { Named(entry: $0, name: EntryQuery.folded($0.name)) }
        entriesByID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Entries whose name contains every word of `text`: names starting with it first, then names with a word
    /// starting with each word, then the rest.
    public func byName(_ text: String, limit: Int = Self.limit) -> [Group] {
        let query = EntryQuery.folded(text).trimmingCharacters(in: .whitespaces)
        let words = query.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let matching = entries.filter { named in words.allSatisfy(named.name.contains) }
        let ranked = matching.enumerated()
            .sorted { first, second in
                let firstRank = Self.rank(first.element.name, query: query, words: words)
                let secondRank = Self.rank(second.element.name, query: query, words: words)
                return firstRank == secondRank ? first.offset < second.offset : firstRank < secondRank
            }
            .map(\.element.entry)
        return Self.grouped(ranked, limit: limit)
    }

    /// The entries `ids` names, in their order: the catalog's text matches, best first.
    public func byIDs(_ ids: [String], limit: Int = Self.limit) -> [Group] {
        Self.grouped(ids.compactMap { entriesByID[$0] }, limit: limit)
    }

    private static func rank(_ name: String, query: String, words: [String]) -> Int {
        if name.hasPrefix(query) { return 0 }
        let starts = words.allSatisfy { name.hasPrefix($0) || name.contains(" " + $0) || name.contains("(" + $0) }
        return starts ? 1 : 2
    }

    /// `ordered`, best first, by category: each keeping its order, the category of the best match first.
    private static func grouped(_ ordered: [EntrySummary], limit: Int) -> [Group] {
        var categories: [EntryCategory] = []
        var byCategory: [EntryCategory: [EntrySummary]] = [:]
        for entry in ordered {
            if byCategory[entry.category] == nil { categories.append(entry.category) }
            byCategory[entry.category, default: []].append(entry)
        }
        return categories.map { category in
            let entries = byCategory[category] ?? []
            return Group(category: category, entries: Array(entries.prefix(limit)), total: entries.count)
        }
    }
}

/// Runs the catalog's ranked text search away from the main thread, on a connection of its own.
public actor TextSearcher {
    private let catalog: Catalog?

    public init(url: URL) {
        catalog = try? Catalog(url: url)
    }

    public func rankedSearch(_ text: String, in system: GameSystem) -> [String] {
        (try? catalog?.rankedSearch(text, in: system)) ?? []
    }
}
