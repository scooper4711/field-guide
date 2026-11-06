import Foundation

/// Where Scrollkeeper for the Mac keeps its downloads. In the sandbox that is the Tableside Toolkit's shared App
/// Group folder, `~/Library/Group Containers/<team ID>.io.github.scooper4711.tableside/Scrollkeeper/Files`, which
/// Field Guide reaches when it was signed into the group (`build-app.sh` writes the group's identifier into the
/// Info.plist). Scrollkeeper's folder from before the sandbox is the fallback, which only an unsandboxed build reaches.
struct ScrollkeeperDownloads {
    /// The Info.plist key with the App Group's identifier, present only in builds signed by the team.
    static let groupKey = "TablesideAppGroup"
    static let relativePath = "Scrollkeeper/Files"

    /// The group's container, or nil when the app isn't in the group.
    let groupContainer: (String) -> URL?
    /// Where Scrollkeeper kept its downloads before the sandbox.
    let previousFolder: URL
    let folderExists: (URL) -> Bool

    /// The folders to look in, the shared one first.
    func candidates(group: String) -> [URL] {
        let shared = group.isEmpty ? nil : groupContainer(group)?.appendingPathComponent(Self.relativePath,
                                                                                          isDirectory: true)
        return [shared, previousFolder].compactMap { $0 }
    }

    /// The first folder that is there, if any.
    func folder(group: String) -> URL? {
        candidates(group: group).first(where: folderExists)
    }
}

extension ScrollkeeperDownloads {
    /// Scrollkeeper's downloads as this app can see them.
    static var standard: ScrollkeeperDownloads {
        ScrollkeeperDownloads(
            groupContainer: { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) },
            previousFolder: URL.applicationSupportDirectory.appendingPathComponent(relativePath, isDirectory: true),
            folderExists: { folder in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
        )
    }

    /// The App Group this build was signed into, or empty.
    static var bundleGroup: String {
        Bundle.main.object(forInfoDictionaryKey: groupKey) as? String ?? ""
    }
}
