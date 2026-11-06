import CloudKit
import Foundation
import SourcebookLore
import Testing
@testable import LoreSync

@Suite("Syncing lore between devices")
struct LoreSyncTests {
    let folder: URL
    let queue = RecordingQueue()
    let log = ChangeLog()

    init() throws {
        folder = try LoreFixture.folder()
    }

    /// Syncing over a store holding `books`, queuing into `queue`.
    func sync(holding books: [BookLore] = [LoreFixture.lore()], uploadingEverything: Bool = false) async throws
        -> (LoreSync, LoreStore) {
        let store = try await LoreFixture.store(in: folder.appendingPathComponent("Store"), holding: books)
        let log = log
        let sync = LoreSync(store: store, folder: folder) { await log.add($0) }
        await sync.use(queue, uploadingEverything: uploadingEverything)
        return (sync, store)
    }

    /// A record of `lore` as the server holds it.
    func serverRecord(_ lore: BookLore) throws -> CKRecord {
        try LoreRecordCoder(assetFolder: folder.appendingPathComponent("Server")).record(for: lore, over: nil)
    }

    @Test("The first sync uploads the zone and every book; later reads upload their books")
    func uploads() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let books = [LoreFixture.lore(title: "A"), LoreFixture.lore(title: "B")]
        let (sync, _) = try await sync(holding: books, uploadingEverything: true)
        #expect(queue.zones == 1 && Set(queue.records) == Set(["A", "B"].map(LoreRecordCoder.recordID(of:))))
        await sync.booksChanged(["C"])
        #expect(queue.records.last == LoreRecordCoder.recordID(of: "C"))
    }

    @Test("A book's record is built from the store, and none for a book that isn't there")
    func records() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (sync, _) = try await sync()
        let record = await sync.record(for: LoreRecordCoder.recordID(of: "Test Gods"))
        #expect(record.flatMap(LoreRecordCoder.lore(in:)) == LoreFixture.lore())
        #expect(await sync.record(for: LoreRecordCoder.recordID(of: "Missing")) == nil)
    }

    @Test("Books from other devices are merged and reported; worse ones are not")
    func receives() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (sync, store) = try await sync()
        let newer = LoreFixture.lore(digest: "errata", edition: 9, paragraph: "Errata.")
        await sync.receive([try serverRecord(newer), try serverRecord(LoreFixture.lore(title: "Other"))])
        #expect(await log.titles == ["Test Gods", "Other"])
        #expect(await store.books["Test Gods"]?.deities["id.abadar"]?.paragraphs == ["Errata."])
        await sync.receive([try serverRecord(LoreFixture.lore(digest: "old", edition: -9))])
        #expect(await log.titles.count == 2)
    }

    @Test("A conflict saves this device's better record again, or merges the server's")
    func conflicts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (sync, store) = try await sync(holding: [LoreFixture.lore(), LoreFixture.lore(title: "Old here")])
        let worse = try serverRecord(LoreFixture.lore(digest: "old", edition: -9))
        let better = try serverRecord(LoreFixture.lore(title: "Old here", digest: "new", edition: 9,
                                                       paragraph: "Newer."))
        await sync.settle([(worse, Self.changed(worse)), (better, Self.changed(better))])
        #expect(queue.records == [worse.recordID])
        #expect(await store.books["Old here"]?.deities["id.abadar"]?.paragraphs == ["Newer."])
        #expect(await log.titles == ["Old here"])
    }

    @Test("A missing zone or record is saved again; other failures are left to the engine")
    func missing() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (sync, _) = try await sync()
        let record = try serverRecord(LoreFixture.lore())
        await sync.saved([record])
        await sync.settle([(record, CKError(.zoneNotFound)), (record, CKError(.unknownItem)),
                           (record, CKError(.networkFailure)), (record, CKError(.serverRecordChanged))])
        #expect(queue.zones == 1 && queue.records == [record.recordID, record.recordID])
        await sync.forgetServer()
        await sync.uploadEverything()
        #expect(queue.zones == 2)
    }

    @Test("Another account, or a deleted zone, uploads every book again; signing out uploads nothing")
    func startsOver() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (sync, _) = try await sync()
        let user = CKRecord.ID(recordName: "user")
        await sync.accountChanged(.signOut(previousUser: user))
        #expect(queue.zones == 0)
        await sync.accountChanged(.signIn(currentUser: user))
        await sync.accountChanged(.switchAccounts(previousUser: user, currentUser: CKRecord.ID(recordName: "other")))
        await sync.zonesDeleted([CKRecordZone.ID(zoneName: "Elsewhere")])
        #expect(queue.zones == 2)
        await sync.zonesDeleted([LoreRecordCoder.zoneID])
        #expect(queue.zones == 3 && queue.records.count == 3)
    }

    static func changed(_ server: CKRecord) -> CKError {
        CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
    }
}
