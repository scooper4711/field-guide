import CloudKit
import Foundation
import SourcebookLore

/// Where syncing queues changes for the engine to send: `CKSyncEngine`'s state, or a recorder in tests.
protocol LoreChangeQueue: Sendable {
    func saveZone()
    func saveRecords(_ recordIDs: [CKRecord.ID])
}

/// Syncs the books' lore in a `LoreStore` through the user's private CloudKit database (docs/specs/lore-sync): books
/// read here are uploaded, books read on other devices are merged in, and conflicts are settled by the merge rule.
public actor LoreSync {
    private let store: LoreStore
    private let coder: LoreRecordCoder
    private let stateFile: URL
    var state: LoreSyncState
    private var queue: (any LoreChangeQueue)?
    var engine: CKSyncEngine?
    /// Called with the titles whose lore arrived from another device.
    private let onChange: @Sendable ([String]) async -> Void

    init(store: LoreStore, folder: URL, onChange: @escaping @Sendable ([String]) async -> Void) {
        self.store = store
        coder = LoreRecordCoder(assetFolder: folder.appendingPathComponent("Lore Sync", isDirectory: true))
        stateFile = folder.appendingPathComponent("lore-sync-state.plist")
        state = LoreSyncState.load(from: stateFile)
        self.onChange = onChange
    }

    /// Sends changes to `queue`; the first time, with the zone and every book.
    func use(_ queue: any LoreChangeQueue, uploadingEverything: Bool) async {
        self.queue = queue
        if uploadingEverything { await uploadEverything() }
    }

    /// Uploads the books whose lore was read here.
    public func booksChanged(_ titles: [String]) {
        queue?.saveRecords(titles.map(LoreRecordCoder.recordID(of:)))
    }

    /// Queues the zone and every book, for a first sync or after the zone was deleted.
    func uploadEverything() async {
        queue?.saveZone()
        booksChanged(Array(await store.books.keys))
    }

    /// The record to send for a book; nil when the book is no longer here.
    func record(for recordID: CKRecord.ID) async -> CKRecord? {
        let books = await store.books
        guard let lore = books.values.first(where: { LoreRecordCoder.recordID(of: $0.title) == recordID })
        else { return nil }
        return try? coder.record(for: lore.shared, over: state.knownRecord(recordID))
    }

    /// Merges records fetched from the server.
    func receive(_ records: [CKRecord]) async {
        records.forEach { state.remember($0) }
        saveState()
        let lore = records.compactMap(LoreRecordCoder.lore(in:))
        let changed = (try? await store.merge(lore)) ?? []
        if !changed.isEmpty { await onChange(changed) }
    }

    /// Remembers the records the server saved.
    func saved(_ records: [CKRecord]) {
        records.forEach { state.remember($0) }
        saveState()
    }

    /// Settles saves the server refused.
    func settle(_ failures: [(record: CKRecord, error: CKError)]) async {
        var serverLore: [BookLore] = []
        for failure in failures {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                guard let server = failure.error.serverRecord else { continue }
                state.remember(server)
                let books = await store.books
                let local = LoreRecordCoder.title(of: server).flatMap { books[$0] }
                let lore = LoreRecordCoder.lore(in: server)
                switch LoreConflict.resolve(local: local, server: lore) {
                case .keepLocal: queue?.saveRecords([recordID])
                case .takeServer: lore.map { serverLore.append($0) }
                }
            case .zoneNotFound:
                queue?.saveZone()
                queue?.saveRecords([recordID])
            case .unknownItem:
                state.systemFields[recordID.recordName] = nil
                queue?.saveRecords([recordID])
            default:
                break // CKSyncEngine retries network and throttling failures itself.
            }
        }
        saveState()
        let changed = (try? await store.merge(serverLore)) ?? []
        if !changed.isEmpty { await onChange(changed) }
    }

    /// Starts over after another account signed in: the server holds none of this device's books yet.
    func accountChanged(_ change: CKSyncEngine.Event.AccountChange.ChangeType) async {
        forgetServer()
        switch change {
        case .signIn, .switchAccounts: await uploadEverything()
        case .signOut: break
        @unknown default: break
        }
    }

    /// Uploads every book again when the lore zone was deleted, as resetting iCloud data does.
    func zonesDeleted(_ zoneIDs: [CKRecordZone.ID]) async {
        guard zoneIDs.contains(LoreRecordCoder.zoneID) else { return }
        forgetServer()
        await uploadEverything()
    }

    /// Forgets what the server held, after the account changed or the zone was deleted.
    func forgetServer() {
        state.systemFields = [:]
        saveState()
    }

    func saveState() {
        try? state.save(to: stateFile)
    }
}
