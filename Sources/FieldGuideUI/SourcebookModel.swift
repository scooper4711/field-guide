import FieldGuideKit
import Foundation
import LoreSync
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
    /// Whether lore syncs with the user's other devices.
    public private(set) var syncStatus = LoreSyncStatus.unsupported
    @ObservationIgnored private let store: LoreStore?
    /// The store's folder, which syncing keeps its state in.
    @ObservationIgnored private let folder: URL?
    @ObservationIgnored private var sync: LoreSync?
    /// What the catalog asks the books for, kept to show lore that arrives from another device.
    @ObservationIgnored private var subjects = LoreSubjects()
    @ObservationIgnored private var lore: [String: DeityLore] = [:]
    @ObservationIgnored private var creatureLore: [String: CreatureLore] = [:]
    @ObservationIgnored private var detailsLore: [String: DetailsLore] = [:]
    /// Each ancestry and class, with the book it is credited to, by entry ID, to name both when the book hasn't been
    /// read.
    @ObservationIgnored private var detailsEntries: [String: EntryReference] = [:]
    /// How many creatures, ancestries and classes Foundry credits to each book, for the Sourcebooks screen.
    @ObservationIgnored private var counts: [String: SourcebookRow.Counts] = [:]

    public init(store: LoreStore?, list: SourcebookList = .bundled, folder: URL? = nil) {
        self.store = store
        self.list = list
        self.folder = folder
    }

    /// The model over the store in `Application Support/Field Guide/Sourcebooks`.
    public static func standard() -> SourcebookModel {
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Field Guide/Sourcebooks")
        return SourcebookModel(store: try? LoreStore(folder: folder), folder: folder)
    }

    /// Syncs the books' lore with the user's other devices when this build may use iCloud (its Info.plist names the
    /// container, `containerIdentifier`) and iCloud is on.
    public func startSync(containerIdentifier: String = LoreSyncStatus.bundleContainer) async {
        guard sync == nil, let store, let folder, !containerIdentifier.isEmpty else { return }
        let onChange: @Sendable ([String]) async -> Void = { [weak self] _ in await self?.showSyncedLore() }
        sync = await LoreSync.start(containerIdentifier: containerIdentifier, store: store, folder: folder,
                                    onChange: onChange)
        syncStatus = sync == nil ? .off : .on
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
            await finish(await Self.attempt { try await store.addNewFiles(subjects: subjects) }, quietWhenNone: true)
        }
        self.subjects = subjects
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
        progress = "Processing sourcebooks…"
        await finish(await Self.attempt { try await store.importFolder(folder, subjects: subjects) },
                     quietWhenNone: false)
        await refresh(subjects: subjects)
    }

    /// Reads the sourcebooks among PDFs the user chose.
    public func addFiles(_ files: [URL], subjects: LoreSubjects) async {
        guard let store else { return }
        progress = Self.readingMessage(for: files, list: list)
        await finish(await Self.attempt { try await store.addFiles(files, subjects: subjects) }, quietWhenNone: false)
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

    /// "Processing Pathfinder Monster Core…" for one book, else "Processing sourcebooks…".
    static func readingMessage(for files: [URL], list: SourcebookList) -> String {
        guard files.count == 1, let file = files.first else { return "Processing sourcebooks…" }
        let title = SourcebookIdentifier(list: list).book(namedBy: file)?.title
            ?? file.deletingPathExtension().lastPathComponent
        return "Processing \(title)…"
    }

    /// Shows lore that arrived from another device.
    private func showSyncedLore() async {
        await refresh(subjects: subjects)
    }

    /// Reports what reading did, and uploads the books it read.
    private func finish(_ result: Result<[String], Error>, quietWhenNone: Bool) async {
        report(result, quietWhenNone: quietWhenNone)
        if case .success(let titles) = result, !titles.isEmpty { await sync?.booksChanged(titles) }
    }

    private func report(_ result: Result<[String], Error>, quietWhenNone: Bool) {
        switch result {
        case .success(let titles) where titles.isEmpty:
            if !quietWhenNone { message = "No new sourcebooks found." }
        case .success(let titles):
            message = titles.count == 1 ? "Processed \(titles[0])." : "Processed \(titles.count) sourcebooks."
        case .failure(let error):
            message = "Processing sourcebooks failed: \(error.localizedDescription)"
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
    /// Whether the book was read on another device: this one has its lore but not its PDF.
    public var isReadElsewhere: Bool { read != nil && read?.location == nil }

    /// What the book supplies, such as "Deity lore: 3 deities · Creature lore: 497 creatures".
    public var supplies: String {
        if SourcebookList.isSample(book.title) { return "Placeholder lore for trying Field Guide" }
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

/// Whether lore syncs with the user's other devices, for the Sourcebooks screen.
public enum LoreSyncStatus: Equatable, Sendable {
    /// This build can't use iCloud, so nothing is said.
    case unsupported
    /// iCloud is off or signed out: lore stays on this device.
    case off
    case on

    /// The Info.plist key naming the iCloud container, which builds with the iCloud entitlements write.
    public static let containerKey = "LoreSyncContainer"

    /// The container this build names, or empty.
    public static var bundleContainer: String {
        Bundle.main.object(forInfoDictionaryKey: containerKey) as? String ?? ""
    }

    /// The Sourcebooks screen's line about syncing, or nil for none.
    public var text: String? {
        switch self {
        case .unsupported: nil
        case .off: "iCloud is off: lore stays on this device."
        case .on: "Lore syncs through your iCloud, so books read on your other devices show here too."
        }
    }
}
