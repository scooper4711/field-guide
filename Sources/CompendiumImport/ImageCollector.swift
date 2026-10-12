import Foundation
import ImageIO

/// Where Foundry's image paths point on this Mac.
public struct FoundryPaths: Sendable {
    /// The pf2e repository; `systems/<system>/…` paths are in its `static` folder.
    public var repository: URL
    /// The Foundry app's `public` folder, holding `icons/…`.
    public var appPublic: URL

    public init(repository: URL, appPublic: URL) {
        self.repository = repository
        self.appPublic = appPublic
    }

    /// The file a Foundry path names, or nil for paths that lead nowhere on this Mac.
    public func file(for foundryPath: String) -> URL? {
        let path = foundryPath.removingPercentEncoding ?? foundryPath
        let parts = path.split(separator: "/", maxSplits: 2).map(String.init)
        guard let first = parts.first else { return nil }
        switch first {
        case "systems" where parts.count == 3: return repository.appendingPathComponent("static/\(parts[2])")
        case "icons": return appPublic.appendingPathComponent(path)
        default: return nil
        }
    }
}

/// Copies the Rexard icons entries show into the output folder, once each, as WebP of at most 256 pixels.
public final class ImageCollector {
    /// The folder in the output that holds the icons, by their paths in the packs.
    static let folder = "rexard"
    static let iconSize = 256

    let icons: IconMap
    private let packs: URL?
    private let output: URL
    private var stored: [String: String] = [:]

    init(icons: IconMap, packs: URL?, output: URL) {
        self.icons = icons
        self.packs = packs
        self.output = output
    }

    /// The stored path of an entry's icon, or "" for none.
    func icon(of document: SourceDocument) -> String {
        guard let packs, let file = icons.choice(for: document)?.file else { return "" }
        if let path = stored[file] { return path }
        let path = copy(packs.appendingPathComponent(file), as: file)
        stored[file] = path
        return path
    }

    /// Writes the picture as WebP, or as it is when it can't be converted; "" when it can't be read.
    private func copy(_ source: URL, as file: String) -> String {
        guard FileManager.default.fileExists(atPath: source.path) else { return "" }
        let webp = "\(Self.folder)/\((file as NSString).deletingPathExtension).webp"
        let destination = output.appendingPathComponent(webp)
        if Self.isUpToDate(destination, comparedWith: source) { return webp }
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if ArtScaler.scale(source, to: destination, maximumSize: Self.iconSize) { return webp }
        let plain = "\(Self.folder)/\(file)"
        let target = output.appendingPathComponent(plain)
        try? FileManager.default.removeItem(at: target)
        return (try? FileManager.default.copyItem(at: source, to: target)) == nil ? "" : plain
    }

    static func isUpToDate(_ destination: URL, comparedWith source: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let made = try? destination.resourceValues(forKeys: keys).contentModificationDate,
              let changed = try? source.resourceValues(forKeys: keys).contentModificationDate else { return false }
        return made >= changed
    }
}

/// Scales the area diagrams with `cwebp`, which reads WebP, PNG and JPEG and writes WebP.
enum ArtScaler {
    static let tool = ["/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp"].first {
        FileManager.default.isExecutableFile(atPath: $0)
    }

    static func scale(_ source: URL, to destination: URL, maximumSize: Int) -> Bool {
        guard let tool, let size = pixelSize(of: source) else { return false }
        var arguments = ["-quiet", "-q", "82"]
        if max(size.width, size.height) > maximumSize {
            arguments += size.width >= size.height ? ["-resize", "\(maximumSize)", "0"] : ["-resize", "0",
                "\(maximumSize)"]
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments + [source.path, "-o", destination.path]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }
}
