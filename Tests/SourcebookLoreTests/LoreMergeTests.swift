import ArtExtraction
import Foundation
import Testing
@testable import SourcebookLore

@Suite("Settling a book's lore read on two devices")
struct LoreMergeTests {
    static let title = "Pathfinder Lost Omens Test Gods"
    static let day: TimeInterval = 86_400
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// A record of the test book; `days` after the base for its PDF date and its read.
    static func record(digest: String = "a", edition: Double? = 0, reader: Int = BookReader.version,
                       read: Double = 0, paragraph: String = "Lore.") -> BookLore {
        BookLore(title: title, location: nil, sourceDigest: digest,
                 sourceDate: edition.map { base.addingTimeInterval($0 * day) }, readerVersion: reader,
                 importedAt: base.addingTimeInterval(read * day),
                 deities: ["id.abadar": DeityLore(paragraphs: [paragraph])])
    }

    @Test("From the same PDF, only a newer reader's record wins")
    func samePDF() {
        #expect(!Self.record(read: 5).isPreferred(over: Self.record()))
        #expect(Self.record(reader: BookReader.version + 1).isPreferred(over: Self.record()))
        #expect(!Self.record().isPreferred(over: Self.record(reader: BookReader.version + 1)))
    }

    @Test("From different PDFs, the newer edition wins, then the newer reader, then the later read", arguments: [
        (record(digest: "new", edition: 2), record(digest: "old", edition: 1, reader: 9, read: 9), true),
        (record(digest: "old", edition: 1, read: 9), record(digest: "new", edition: 2), false),
        (record(digest: "dated", edition: 0), record(digest: "undated", edition: nil, read: 9), true),
        (record(digest: "undated", edition: nil), record(digest: "dated", edition: 0), false),
        (record(digest: "b", reader: 9), record(digest: "a", read: 9), true),
        (record(digest: "b", read: 1), record(digest: "a"), true),
        (record(digest: "b"), record(digest: "a", read: 1), false)
    ])
    func differentPDFs(record: BookLore, other: BookLore, wins: Bool) {
        #expect(record.isPreferred(over: other) == wins)
    }

    @Test("Other devices get a record without this device's location")
    func shared() throws {
        var record = Self.record()
        record.location = try FileReference(FileManager.default.temporaryDirectory)
        #expect(record.shared.location == nil)
        #expect(record.shared.deities == record.deities)
    }

    @Test("Merging keeps better records, this device's location of the same PDF, and saves")
    func merge() async throws {
        let folder = try LoreStoreTests.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try LoreStoreTests.writeBook(named: "Pathfinder Lost Omens- Test Gods PDF - Single File.pdf",
                                                in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: LoreStoreTests.list)
        _ = try await store.addFiles([file], subjects: LoreStoreTests.subjects)
        let local = try #require(await store.books[Self.title])
        let location = try #require(local.location)
        let older = Self.record(digest: local.sourceDigest, read: 3, paragraph: "Older reading.")
        #expect(try await store.merge([older]).isEmpty)

        let upgraded = Self.record(digest: local.sourceDigest, reader: BookReader.version + 1,
                                   paragraph: "Newer reader.")
        #expect(try await store.merge([upgraded]) == [Self.title])
        #expect(await store.books[Self.title]?.location == location)
        #expect(await store.books[Self.title]?.deities["id.abadar"]?.paragraphs == ["Newer reader."])

        let edition = Self.record(digest: "errata", edition: 1e5, reader: BookReader.version + 1,
                                  paragraph: "Errata.")
        #expect(try await store.merge([edition]) == [Self.title])
        let reopened = try LoreStore(folder: folder.appendingPathComponent("Store"), list: LoreStoreTests.list)
        let stored = try #require(await reopened.books[Self.title])
        #expect(stored.location == nil && stored.deities["id.abadar"]?.paragraphs == ["Errata."])
        #expect(await reopened.sharedRecords([Self.title, "Unread"]).map(\.title) == [Self.title])
    }

    @Test("A book a newer app read, on another device, isn't read again over it")
    func newerReaderIsKept() async throws {
        let folder = try LoreStoreTests.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try LoreStoreTests.writeBook(named: "Pathfinder Lost Omens- Test Gods PDF - Single File.pdf",
                                                in: folder)
        let store = try LoreStore(folder: folder.appendingPathComponent("Store"), list: LoreStoreTests.list)
        let newer = Self.record(digest: "other", reader: BookReader.version + 1, paragraph: "From a newer app.")
        _ = try await store.merge([newer])
        #expect(try await store.addFiles([file], subjects: LoreStoreTests.subjects).isEmpty)
        #expect(await store.books[Self.title]?.deities["id.abadar"]?.paragraphs == ["From a newer app."])
    }
}
