import ArtExtraction
import Foundation
import SourcebookLore
import Testing
@testable import FieldGuideUI

@Suite("Saying whether lore syncs")
@MainActor
struct LoreSyncStatusTests {
    @Test("Only a build that may use iCloud says anything about it")
    func text() {
        #expect(LoreSyncStatus.unsupported.text == nil)
        #expect(LoreSyncStatus.off.text == "iCloud is off: lore stays on this device.")
        #expect(LoreSyncStatus.on.text?.hasPrefix("Lore syncs through your iCloud") == true)
        #expect(LoreSyncStatus.bundleContainer.isEmpty)
    }

    @Test("A build without the iCloud container doesn't start syncing")
    func noContainer() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Sync-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = SourcebookModel(store: try LoreStore(folder: folder), folder: folder)
        await model.startSync()
        #expect(model.syncStatus == .unsupported)
        await SourcebookModel(store: nil).startSync(containerIdentifier: "iCloud.example")
    }

    @Test("A book whose lore came from another device says so")
    func readElsewhere() throws {
        let book = Sourcebook(title: "Test Gods", sku: nil, aliases: [], supplies: [.deityLore])
        let lore = BookLore(title: "Test Gods", location: nil, sourceDigest: "a", sourceDate: nil, readerVersion: 1,
                            importedAt: Date(), deities: [:])
        #expect(SourcebookRow(book: book, counts: .init(), read: lore).isReadElsewhere)
        var here = lore
        here.location = try FileReferenceFixture.reference()
        #expect(!SourcebookRow(book: book, counts: .init(), read: here).isReadElsewhere)
        #expect(!SourcebookRow(book: book, counts: .init(), read: nil).isReadElsewhere)
    }
}

/// A bookmark of a real folder, for records read on this device.
enum FileReferenceFixture {
    static func reference() throws -> FileReference {
        try FileReference(FileManager.default.temporaryDirectory)
    }
}
