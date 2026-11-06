import FieldGuideKit
import Foundation
import Observation
import SourcebookLore

/// Deity, creature, ancestry and class lore from the user's own sourcebooks (`LoreStore`), and the books it can come
/// from.
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
    @ObservationIgnored private var detailsLore: [String: DetailsLore] = [:]
    /// Each ancestry and class, with the book it is credited to, by entry ID, to name both when the book hasn't been
    /// read.
    @ObservationIgnored private var detailsEntries: [String: EntryReference] = [:]
    /// How many creatures, ancestries and classes Foundry credits to each book, for the Sourcebooks screen.
    @ObservationIgnored private var counts: [String: SourcebookRow.Counts] = [:]

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

    /// An ancestry's or class's lore for its Details tab: from the user's book, else a note naming the book to add;
    /// nil for other entries.
    public func detailsHTML(of entryID: String) -> String? {
        if let lore = detailsLore[entryID] { return lore.html }
        return detailsEntries[entryID].map { entry in
            "<p class=\"note\"><em>Add your copy of \(entry.credited) in Sourcebooks to read the lore for "
                + "\(entry.name).</em></p>"
        }
    }

    /// Reads what the store holds; with `addingNew`, first reads the books that have appeared or changed in the
    /// watched folders, as at launch.
    public func refresh(addingNew: Bool = false, subjects: LoreSubjects) async {
        guard let store else { return }
        if addingNew {
            progress = "Looking for new sourcebooks…"
            report(await Self.attempt { try await store.addNewFiles(subjects: subjects) }, quietWhenNone: true)
        }
        books = await store.books
        var lore: [String: DeityLore] = [:]
        for id in Set(list.deities.keys).union(subjects.deityNames.keys) {
            lore[id] = await store.lore(of: id)
        }
        self.lore = lore
        creatureLore = await Self.lore(of: subjects.creatures) { await store.lore(of: $0) }
        detailsLore = await Self.lore(of: subjects.details) { await store.details(of: $0) }
        detailsEntries = Dictionary(subjects.details.map { ($0.id, $0) }) { first, _ in first }
        counts = SourcebookRow.Counts.of(subjects)
        progress = nil
    }

    private static func lore<Lore>(of entries: [EntryReference],
                                   _ read: (EntryReference) async -> Lore?) async -> [String: Lore] {
        var lore: [String: Lore] = [:]
        for entry in entries {
            lore[entry.id] = await read(entry)
        }
        return lore
    }

    /// Watches Scrollkeeper's download folder and reads the sourcebooks in it.
    public func importFolder(_ folder: URL, subjects: LoreSubjects) async {
        guard let store else { return }
        progress = "Reading sourcebooks…"
        report(await Self.attempt { try await store.importFolder(folder, subjects: subjects) }, quietWhenNone: false)
        await refresh(subjects: subjects)
    }

    /// Reads the sourcebooks among PDFs the user chose.
    public func addFiles(_ files: [URL], subjects: LoreSubjects) async {
        guard let store else { return }
        progress = Self.readingMessage(for: files, list: list)
        report(await Self.attempt { try await store.addFiles(files, subjects: subjects) }, quietWhenNone: false)
        await refresh(subjects: subjects)
    }

    /// The state of each book in the list, for the Sourcebooks screen.
    public var rows: [SourcebookRow] {
        var counts = self.counts
        for sources in list.deities.values {
            sources.books.forEach { counts[$0, default: .init()].deities += 1 }
        }
        return list.books.map { book in
            SourcebookRow(book: book, counts: counts[book.title] ?? .init(), read: books[book.title])
        }
    }

    /// "Reading Pathfinder Monster Core…" for one book, else "Reading sourcebooks…".
    static func readingMessage(for files: [URL], list: SourcebookList) -> String {
        guard files.count == 1, let file = files.first else { return "Reading sourcebooks…" }
        let title = SourcebookIdentifier(list: list).book(namedBy: file)?.title
            ?? file.deletingPathExtension().lastPathComponent
        return "Reading \(title)…"
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
    /// How many entries' lore a book supplies or may supply.
    public struct Counts: Equatable, Sendable {
        public var deities = 0
        /// The creatures Foundry credits to the book.
        public var creatures = 0
        /// The ancestries and classes Foundry credits to the book.
        public var details = 0

        public init(deities: Int = 0, creatures: Int = 0, details: Int = 0) {
            self.deities = deities
            self.creatures = creatures
            self.details = details
        }

        /// The creatures', ancestries' and classes' counts by the book Foundry credits them to.
        static func of(_ subjects: LoreSubjects) -> [String: Counts] {
            var counts: [String: Counts] = [:]
            subjects.creatures.forEach { counts[$0.credited, default: .init()].creatures += 1 }
            subjects.details.forEach { counts[$0.credited, default: .init()].details += 1 }
            return counts
        }
    }

    public let book: Sourcebook
    public let counts: Counts
    /// The book as read, or nil when Field Guide hasn't read it.
    public let read: BookLore?

    public var id: String { book.id }
    public var isRead: Bool { read != nil }

    /// What the book supplies, such as "Deity lore: 3 deities · Creature lore: 497 creatures".
    public var supplies: String {
        if book == SourcebookList.sample { return "Placeholder lore for trying Field Guide" }
        let parts = [Wording(label: "Deity lore", one: "deity", many: "deities").text(counts.deities),
                     Wording(label: "Creature lore", one: "creature", many: "creatures").text(counts.creatures),
                     Wording(label: "Ancestry and class lore", one: "entry", many: "entries").text(counts.details)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// How a count of what a book supplies reads.
    private struct Wording {
        let label: String
        let one: String
        let many: String

        /// "Deity lore: 3 deities", or nil for none.
        func text(_ count: Int) -> String? {
            count > 0 ? "\(label): \(count) \(count == 1 ? one : many)" : nil
        }
    }
}
