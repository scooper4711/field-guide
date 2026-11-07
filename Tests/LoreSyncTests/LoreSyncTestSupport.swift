import CloudKit
import Foundation
import SourcebookLore
import Synchronization
@testable import LoreSync

/// Records what syncing queues for the engine.
final class RecordingQueue: LoreChangeQueue {
    private let queued = Mutex<(zones: Int, records: [CKRecord.ID])>((0, []))

    var zones: Int { queued.withLock { $0.zones } }
    var records: [CKRecord.ID] { queued.withLock { $0.records } }

    func saveZone() { queued.withLock { $0.zones += 1 } }
    func saveRecords(_ recordIDs: [CKRecord.ID]) { queued.withLock { $0.records += recordIDs } }
}

/// Collects the titles syncing reports as changed.
actor ChangeLog {
    private(set) var titles: [String] = []
    func add(_ changed: [String]) { titles += changed }
}

/// Lore records and a store in a temporary folder.
enum LoreFixture {
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    static func lore(title: String = "Test Gods", digest: String = "a", edition: Double = 0,
                     paragraph: String = "Lore.") -> BookLore {
        BookLore(title: title, location: nil, sourceDigest: digest, sourceDate: base.addingTimeInterval(edition),
                 readerVersion: BookReader.version, importedAt: base,
                 deities: ["id.abadar": DeityLore(paragraphs: [paragraph])])
    }

    static func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// A store in `folder` holding `books`.
    static func store(in folder: URL, holding books: [BookLore]) async throws -> LoreStore {
        let store = try LoreStore(folder: folder)
        _ = try await store.merge(books)
        return store
    }
}
