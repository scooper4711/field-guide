import FieldGuideKit
import Foundation

/// The deities' religious symbols from Paizo's Community Use Package: the PNGs in its Religious Symbols
/// folders, named for their deities ("Abadar.png", "Thamir Gixx.png").
public struct ReligiousSymbols: Sendable {
    /// Each system's pictures by name, most wanted folder first.
    private let pictures: [GameSystem: [[String: URL]]]

    /// No symbols.
    public init() {
        pictures = [:]
    }

    /// The symbols in `pathfinder`, for both systems, and in `starfinder`, which Starfinder deities look in
    /// first; a folder that doesn't exist adds none.
    public init(pathfinder: URL?, starfinder: URL?) {
        let pathfinderPictures = Self.pictures(in: pathfinder)
        pictures = [.pathfinder: [pathfinderPictures], .starfinder: [Self.pictures(in: starfinder), pathfinderPictures]]
    }

    /// The symbol of the deity named `name` in `system`: the picture named as it is, else one whose name starts
    /// with its name and a space, ignoring a leading "The "; nil when there is none.
    public func file(forDeity name: String, in system: GameSystem) -> URL? {
        let wanted = name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
        for folder in pictures[system] ?? [] {
            if let file = folder[wanted] { return file }
            let longer = folder.keys.filter { $0.hasPrefix(wanted + " ") }.sorted()
            if let key = longer.first { return folder[key] }
        }
        return nil
    }

    /// The PNGs in the folder by name without extension; none when it can't be read.
    private static func pictures(in folder: URL?) -> [String: URL] {
        guard let folder, let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else {
            return [:]
        }
        let files = names.filter { $0.lowercased().hasSuffix(".png") }.map { folder.appendingPathComponent($0) }
        return Dictionary(files.map { ($0.deletingPathExtension().lastPathComponent, $0) }) { first, _ in first }
    }
}
