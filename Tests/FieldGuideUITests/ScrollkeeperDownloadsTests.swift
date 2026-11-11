import Foundation
import Testing
@testable import FieldGuideUI

@Suite("Finding Scrollkeeper's downloads")
struct ScrollkeeperDownloadsTests {
    static let scrollkeeper = URL(
        fileURLWithPath: "/Group Containers/TEAM123.io.github.scooper4711.tableside/Scrollkeeper", isDirectory: true
    )
    static let previous = URL(fileURLWithPath: "/Application Support/Scrollkeeper/Files")
    static let shared = scrollkeeper.appendingPathComponent("Files", isDirectory: true)

    /// Downloads with Scrollkeeper's group folder `sharedFolder`, whose existing folders are `existing`.
    static func downloads(sharedFolder: URL? = scrollkeeper, existing: Set<URL>) -> ScrollkeeperDownloads {
        ScrollkeeperDownloads(sharedFolder: sharedFolder, previousFolder: previous,
                              folderExists: { existing.contains($0) })
    }

    @Test("The shared folder comes before the folder from before the sandbox")
    func order() {
        #expect(Self.downloads(existing: []).candidates == [Self.shared, Self.previous])
    }

    @Test("A build outside the group looks only in the previous folder")
    func noGroup() {
        #expect(Self.downloads(sharedFolder: nil, existing: []).candidates == [Self.previous])
    }

    @Test("The first folder that is there is used", arguments: [
        ([shared, previous], URL?.some(shared)), ([previous], previous), ([], nil)
    ])
    func found(existing: [URL], folder: URL?) {
        #expect(Self.downloads(existing: Set(existing)).folder == folder)
    }

    @Test("The standard lookup finds no group from a test bundle and finds a real folder")
    func standard() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let standard = ScrollkeeperDownloads.standard
        #expect(standard.sharedFolder == nil)
        #expect(standard.folderExists(folder))
        #expect(!standard.folderExists(folder.appendingPathComponent("missing")))
    }
}
