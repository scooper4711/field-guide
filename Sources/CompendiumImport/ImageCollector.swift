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

/// Copies the icons entries use into the output folder, once each.
public final class ImageCollector {
    private let paths: FoundryPaths
    private let output: URL
    private var stored: [String: String] = [:]
    public private(set) var missing: [String: Int] = [:]

    public init(paths: FoundryPaths, output: URL) {
        self.paths = paths
        self.output = output
    }

    /// The stored path of a Foundry icon, or "" for none: SVG placeholders and missing files are left out.
    public func icon(_ foundryPath: String) -> String {
        guard !foundryPath.isEmpty, !foundryPath.hasSuffix(".svg") else { return "" }
        if let path = stored[foundryPath] { return path }
        let relative = foundryPath.removingPercentEncoding ?? foundryPath
        guard let source = paths.file(for: foundryPath), FileManager.default.fileExists(atPath: source.path) else {
            missing[foundryPath, default: 0] += 1
            return ""
        }
        let path = copy(source, to: relative) ? relative : ""
        stored[foundryPath] = path
        return path
    }

    private func copy(_ source: URL, to relative: String) -> Bool {
        let destination = output.appendingPathComponent(relative)
        if Self.isUpToDate(destination, comparedWith: source) { return true }
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            return true
        } catch {
            missing[relative, default: 0] += 1
            return false
        }
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
