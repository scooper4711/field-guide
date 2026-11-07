import CloudKit
import Foundation

/// What syncing remembers between launches: the engine's own state, and the server's last known system fields of
/// each book's record (its change tag), so the next save of a book doesn't conflict with itself.
struct LoreSyncState: Codable {
    var engine: CKSyncEngine.State.Serialization?
    /// Each record's archived system fields, by record name.
    var systemFields: [String: Data] = [:]

    /// The state saved in `file`, or a fresh one.
    static func load(from file: URL) -> LoreSyncState {
        (try? Data(contentsOf: file)).flatMap { try? PropertyListDecoder().decode(Self.self, from: $0) }
            ?? LoreSyncState()
    }

    func save(to file: URL) throws {
        try PropertyListEncoder().encode(self).write(to: file, options: .atomic)
    }

    /// Remembers the server's copy of a record.
    mutating func remember(_ record: CKRecord) {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        systemFields[record.recordID.recordName] = archiver.encodedData
    }

    /// The server's last known copy of a record, with its system fields only; nil when none is known.
    func knownRecord(_ recordID: CKRecord.ID) -> CKRecord? {
        guard let data = systemFields[recordID.recordName],
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
