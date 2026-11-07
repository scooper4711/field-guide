import CloudKit
import CryptoKit
import Foundation
import SourcebookLore

/// Turns a book's lore into a CloudKit record and back: the provenance as plain fields, and the lore itself, as JSON
/// without the device's location of the PDF, as an asset, since a bestiary's lore can pass a record's 1 MB limit.
struct LoreRecordCoder: Sendable {
    static let recordType = "BookLore"
    static let zoneID = CKRecordZone.ID(zoneName: "Lore", ownerName: CKCurrentUserDefaultName)

    /// Where the lore's JSON is written for uploading, one file per book.
    let assetFolder: URL

    /// A book's record name: `book-` and the SHA-256 of its title, valid whatever the title holds.
    static func recordID(of title: String) -> CKRecord.ID {
        let hash = SHA256.hash(data: Data(title.utf8)).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: "book-\(hash)", zoneID: zoneID)
    }

    /// The record of `lore`, over the server's last known copy of it when there is one, so it saves without a
    /// conflict.
    func record(for lore: BookLore, over known: CKRecord?) throws -> CKRecord {
        let record = known ?? CKRecord(recordType: Self.recordType, recordID: Self.recordID(of: lore.title))
        try FileManager.default.createDirectory(at: assetFolder, withIntermediateDirectories: true)
        let file = assetFolder.appendingPathComponent(record.recordID.recordName + ".json")
        try JSONEncoder().encode(lore.shared).write(to: file, options: .atomic)
        record["title"] = lore.title
        record["sourceDigest"] = lore.sourceDigest
        record["sourceDate"] = lore.sourceDate.map { $0 as NSDate }
        record["readerVersion"] = Int64(lore.readerVersion)
        record["importedAt"] = lore.importedAt as NSDate
        record["lore"] = CKAsset(fileURL: file)
        return record
    }

    /// The lore a record holds, without a location; nil when it isn't a lore record or its asset can't be read.
    static func lore(in record: CKRecord) -> BookLore? {
        guard record.recordType == recordType, let asset = record["lore"] as? CKAsset, let file = asset.fileURL,
              let data = try? Data(contentsOf: file),
              let lore = try? JSONDecoder().decode(BookLore.self, from: data) else { return nil }
        return lore.shared
    }

    /// The title a record names.
    static func title(of record: CKRecord) -> String? {
        record["title"] as? String
    }
}

/// Which side keeps a book when the server already has a different record of it.
enum LoreConflict: Equatable {
    /// This device's record is better: save it again over the server's.
    case keepLocal
    /// The server's record is as good or better: merge it here.
    case takeServer

    static func resolve(local: BookLore?, server: BookLore?) -> LoreConflict {
        guard let server else { return .keepLocal }
        guard let local else { return .takeServer }
        return local.isPreferred(over: server) ? .keepLocal : .takeServer
    }
}
