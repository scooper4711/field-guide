import ArtExtraction
import CloudKit
import Foundation
import SourcebookLore
import Testing
@testable import LoreSync

@Suite("Lore as CloudKit records")
struct LoreRecordCoderTests {
    @Test("A book's record holds its provenance and its lore without the device's location")
    func roundTrip() throws {
        let folder = try LoreFixture.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        var lore = LoreFixture.lore()
        lore.location = try FileReference(folder)
        let record = try LoreRecordCoder(assetFolder: folder).record(for: lore, over: nil)
        #expect(record.recordType == "BookLore" && record.recordID.zoneID.zoneName == "Lore")
        #expect(record["sourceDigest"] as? String == "a")
        #expect(record["readerVersion"] as? Int64 == Int64(BookReader.version))
        #expect(LoreRecordCoder.title(of: record) == "Test Gods")
        let decoded = try #require(LoreRecordCoder.lore(in: record))
        #expect(decoded == lore.shared && decoded.location == nil)
    }

    @Test("Record names are the same for a title, differ between titles, and suit any title")
    func recordNames() {
        let name = LoreRecordCoder.recordID(of: "Pathfinder Lost Omens: Gods & Magic").recordName
        #expect(name == LoreRecordCoder.recordID(of: "Pathfinder Lost Omens: Gods & Magic").recordName)
        #expect(name != LoreRecordCoder.recordID(of: "Monster Core").recordName)
        #expect(name.hasPrefix("book-") && name.count == 69)
        #expect(name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" })
    }

    @Test("A record saved over the server's copy keeps that copy's identity")
    func overKnown() throws {
        let folder = try LoreFixture.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let coder = LoreRecordCoder(assetFolder: folder)
        let known = try coder.record(for: LoreFixture.lore(), over: nil)
        let again = try coder.record(for: LoreFixture.lore(paragraph: "Changed."), over: known)
        #expect(again === known)
        #expect(LoreRecordCoder.lore(in: again)?.deities["id.abadar"]?.paragraphs == ["Changed."])
    }

    @Test("Records that aren't lore, or whose lore can't be read, give none")
    func notLore() {
        let other = CKRecord(recordType: "Other", recordID: LoreRecordCoder.recordID(of: "x"))
        let empty = CKRecord(recordType: "BookLore", recordID: LoreRecordCoder.recordID(of: "x"))
        let missing = CKRecord(recordType: "BookLore", recordID: LoreRecordCoder.recordID(of: "y"))
        missing["lore"] = CKAsset(fileURL: URL(fileURLWithPath: "/nonexistent/lore.json"))
        #expect(LoreRecordCoder.lore(in: other) == nil && LoreRecordCoder.lore(in: empty) == nil)
        #expect(LoreRecordCoder.lore(in: missing) == nil && LoreRecordCoder.title(of: empty) == nil)
    }

    @Test("A conflict keeps the better record", arguments: [
        (LoreFixture.lore(digest: "new", edition: 9), LoreFixture.lore(digest: "old"), LoreConflict.keepLocal),
        (LoreFixture.lore(digest: "old"), LoreFixture.lore(digest: "new", edition: 9), .takeServer),
        (LoreFixture.lore(), LoreFixture.lore(), .takeServer)
    ])
    func conflict(local: BookLore, server: BookLore, outcome: LoreConflict) {
        #expect(LoreConflict.resolve(local: local, server: server) == outcome)
    }

    @Test("A conflict without one side keeps the side there is")
    func oneSided() {
        #expect(LoreConflict.resolve(local: LoreFixture.lore(), server: nil) == .keepLocal)
        #expect(LoreConflict.resolve(local: nil, server: LoreFixture.lore()) == .takeServer)
    }

    @Test("Syncing remembers the server's copy of a record across launches")
    func state() throws {
        let folder = try LoreFixture.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = try LoreRecordCoder(assetFolder: folder).record(for: LoreFixture.lore(), over: nil)
        var state = LoreSyncState()
        state.remember(record)
        let file = folder.appendingPathComponent("state.plist")
        try state.save(to: file)
        let loaded = LoreSyncState.load(from: file)
        #expect(loaded.knownRecord(record.recordID)?.recordID == record.recordID)
        #expect(loaded.knownRecord(LoreRecordCoder.recordID(of: "other")) == nil)
        #expect(LoreSyncState.load(from: folder.appendingPathComponent("missing")).systemFields.isEmpty)
    }
}
