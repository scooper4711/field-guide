import Foundation
import TablesideShared

/// Where Scrollkeeper keeps its downloads. In the sandbox, and on an iPad, that is its folder in the Tableside
/// Toolkit's App Group (`ToolkitGroup.scrollkeeperFolder()`), `Scrollkeeper/Files`, which Field Guide reaches when it
/// was signed into the group. Scrollkeeper's Mac folder from before the sandbox is the fallback, which only an
/// unsandboxed build reaches.
struct ScrollkeeperDownloads {
    static let relativePath = "Scrollkeeper/Files"

    /// Scrollkeeper's folder in the group, or nil when the app isn't in the group.
    let sharedFolder: URL?
    /// Where Scrollkeeper kept its downloads before the sandbox.
    let previousFolder: URL
    let folderExists: (URL) -> Bool

    /// The folders to look in, the shared one first.
    var candidates: [URL] {
        [sharedFolder?.appendingPathComponent("Files", isDirectory: true), previousFolder].compactMap { $0 }
    }

    /// The first folder that is there, if any.
    var folder: URL? {
        candidates.first(where: folderExists)
    }
}

extension ScrollkeeperDownloads {
    /// Scrollkeeper's downloads as this app can see them.
    static var standard: ScrollkeeperDownloads {
        ScrollkeeperDownloads(
            sharedFolder: ToolkitGroup.scrollkeeperFolder(),
            previousFolder: URL.applicationSupportDirectory.appendingPathComponent(relativePath, isDirectory: true),
            folderExists: { folder in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
        )
    }
}
