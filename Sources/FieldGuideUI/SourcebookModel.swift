import FieldGuideKit
import Foundation
import Observation
import SourcebookLore

/// What the user's books give: the deities and creatures whose lore Field Guide reads from them.
public struct LoreSubjects: Sendable {
    /// Each deity's name by entry ID.
    public var deityNames: [String: String]
    public var creatures: [CreatureReference]

    public init(deityNames: [String: String] = [:], creatures: [CreatureReference] = []) {
        self.deityNames = deityNames
        self.creatures = creatures
    }
}

/// Deity and creature lore from the user's own sourcebooks (`LoreStore`), and the books it can come from.
@MainActor
@Observable
public final class SourcebookModel {
    /// The books Field Guide reads, and which deities' lore each supplies.
    public let list: SourcebookList
    /// The books read, by title.
    public private(set) var books: [String: BookLore] = [:]
    /// What reading books is doing, while it runs.
    public private(set) var progress: String?
    /// The result of the last import, shown until dismissed.
    public var message: String?
    @ObservationIgnored private let store: LoreStore?
    @ObservationIgnored private var lore: [String: DeityLore] = [:]
    @ObservationIgnored private var creatureLore: [String: CreatureLore] = [:]
    /// How many creatures Foundry credits to each book, for the Sourcebooks screen.
    @ObservationIgnored private var creatureCounts: [String: Int] = [:]

    public init(store: LoreStore?, list: SourcebookList = .bundled) {
        self.store = store
        self.list = list
    }

    /// The model over the store in `Application Support/Field Guide/Sourcebooks`.
    public static func standard() -> SourcebookModel {
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Field Guide/Sourcebooks")
        return SourcebookModel(store: try? LoreStore(folder: folder))
    }

    /// The deity's lore from the user's books; nil when none of its books has been read.
    public func lore(of entryID: String) -> DeityLore? {
        lore[entryID]
    }

    /// The creature's lore from the user's books; nil when none of its books has been read.
    public func creatureLore(of entryID: String) -> CreatureLore? {
        creatureLore[entryID]
    }

    /// Reads what the store holds; with `addingNew`, first reads the books that have appeared or changed in the
    /// watched folders, as at launch.
    public func refresh(addingNew: Bool = false, subjects: LoreSubjects) async {
        guard let store else { return }
        if addingNew {
            progress = "Looking for new sourcebooks…"
            let names = subjects.deityNames
            report(await Self.attempt { try await store.addNewFiles(names: names) }, quietWhenNone: true)
        }
        books = await store.books
        var lore: [String: DeityLore] = [:]
        for id in Set(list.deities.keys).union(subjects.deityNames.keys) {
            lore[id] = await store.lore(of: id)
        }
        self.lore = lore
        var creatureLore: [String: CreatureLore] = [:]
        for creature in subjects.creatures {
            creatureLore[creature.id] = await store.lore(of: creature)
        }
        self.creatureLore = creatureLore
        creatureCounts = subjects.creatures.reduce(into: [:]) { counts, creature in
            counts[creature.credited, default: 0] += 1
        }
        progress = nil
    }

    /// Watches Scrollkeeper's download folder and reads the sourcebooks in it.
    public func importFolder(_ folder: URL, subjects: LoreSubjects) async {
        guard let store else { return }
        progress = "Reading sourcebooks…"
        let names = subjects.deityNames
        report(await Self.attempt { try await store.importFolder(folder, names: names) }, quietWhenNone: false)
        await refresh(subjects: subjects)
    }

    /// Reads the sourcebooks among PDFs the user chose.
    public func addFiles(_ files: [URL], subjects: LoreSubjects) async {
        guard let store else { return }
        progress = "Reading sourcebooks…"
        let names = subjects.deityNames
        report(await Self.attempt { try await store.addFiles(files, names: names) }, quietWhenNone: false)
        await refresh(subjects: subjects)
    }

    /// The state of each book in the list, for the Sourcebooks screen.
    public var rows: [SourcebookRow] {
        let counts = list.deities.values.reduce(into: [String: Int]()) { counts, sources in
            sources.books.forEach { counts[$0, default: 0] += 1 }
        }
        return list.books.map { book in
            SourcebookRow(book: book, deityCount: counts[book.title] ?? 0,
                          creatureCount: creatureCounts[book.title] ?? 0, read: books[book.title])
        }
    }

    private func report(_ result: Result<[String], Error>, quietWhenNone: Bool) {
        switch result {
        case .success(let titles) where titles.isEmpty:
            if !quietWhenNone { message = "No new sourcebooks found." }
        case .success(let titles):
            message = titles.count == 1 ? "Read \(titles[0])." : "Read \(titles.count) sourcebooks."
        case .failure(let error):
            message = "Reading sourcebooks failed: \(error.localizedDescription)"
        }
    }

    private static func attempt(_ body: () async throws -> [String]) async -> Result<[String], Error> {
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }
}

/// A sourcebook on the Sourcebooks screen: what it supplies, and whether Field Guide has read it.
public struct SourcebookRow: Identifiable, Equatable {
    public let book: Sourcebook
    /// How many deities' lore the book supplies.
    public let deityCount: Int
    /// How many creatures Foundry credits to the book, whose lore it may supply.
    public let creatureCount: Int
    /// The book as read, or nil when Field Guide hasn't read it.
    public let read: BookLore?

    public var id: String { book.id }
    public var isRead: Bool { read != nil }

    /// What the book supplies, such as "Deity lore: 3 deities · Creature lore: 497 creatures".
    public var supplies: String {
        if book == SourcebookList.sample { return "Placeholder lore for trying Field Guide" }
        var parts: [String] = []
        if deityCount > 0 { parts.append("Deity lore: \(deityCount) \(deityCount == 1 ? "deity" : "deities")") }
        if creatureCount > 0 {
            parts.append("Creature lore: \(creatureCount) \(creatureCount == 1 ? "creature" : "creatures")")
        }
        return parts.joined(separator: " · ")
    }
}
