import Foundation
import Testing
@testable import FieldGuideUI

@Suite("Finding Scrollkeeper's downloads")
struct ScrollkeeperDownloadsTests {
    static let group = "TEAM123.io.github.scooper4711.tableside"
    static let container = URL(fileURLWithPath: "/Group Containers/\(group)")
    static let previous = URL(fileURLWithPath: "/Application Support/Scrollkeeper/Files")
    static let shared = container.appendingPathComponent("Scrollkeeper/Files", isDirectory: true)

    /// Downloads whose group container is there only for `group`, and whose existing folders are `existing`.
    static func downloads(existing: Set<URL>) -> ScrollkeeperDownloads {
        ScrollkeeperDownloads(groupContainer: { $0 == group ? container : nil }, previousFolder: previous,
                              folderExists: { existing.contains($0) })
    }

    @Test("The shared folder comes before the folder from before the sandbox")
    func order() {
        let downloads = Self.downloads(existing: [])
        #expect(downloads.candidates(group: Self.group) == [Self.shared, Self.previous])
    }

    @Test("A build outside the group looks only in the previous folder", arguments: ["", "OTHER.group"])
    func noGroup(group: String) {
        #expect(Self.downloads(existing: []).candidates(group: group) == [Self.previous])
    }

    @Test("The first folder that is there is used", arguments: [
        ([shared, previous], URL?.some(shared)), ([previous], previous), ([], nil)
    ])
    func found(existing: [URL], folder: URL?) {
        #expect(Self.downloads(existing: Set(existing)).folder(group: Self.group) == folder)
    }

    @Test("The standard lookup reads no group from a test bundle and finds a real folder")
    func standard() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let standard = ScrollkeeperDownloads.standard
        #expect(ScrollkeeperDownloads.bundleGroup.isEmpty)
        #expect(standard.folderExists(folder))
        #expect(!standard.folderExists(folder.appendingPathComponent("missing")))
    }
}
