import CoreGraphics
import FieldGuideKit
import Foundation
import Testing
import ImageIO
import UniformTypeIdentifiers
@testable import CompendiumImport

/// Pictures whose difference hashes differ in almost every bit.
enum Pattern {
    /// Brighter to the right.
    case rising
    /// Darker to the right.
    case falling
    /// Light and dark columns.
    case stripes

    func gray(atColumn column: Int, of width: Int) -> CGFloat {
        let position = CGFloat(column) / CGFloat(max(width - 1, 1))
        switch self {
        case .rising: return position
        case .falling: return 1 - position
        case .stripes: return (column * 8 / width).isMultiple(of: 2) ? 0.1 : 0.9
        }
    }

    /// Writes the pattern as a square PNG, whatever the file's extension.
    func write(to url: URL, size: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let context = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for column in 0..<size {
            let gray = gray(atColumn: column, of: size)
            context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1))
            context.fill(CGRect(x: column, y: 0, width: 1, height: size))
        }
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                                       1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        CGImageDestinationFinalize(destination)
    }
}

/// A Rexard pack folder and Foundry icons in a temporary folder, and documents that use them.
struct IconFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("IconTests-\(UUID().uuidString)")
    var packs: URL { root.appendingPathComponent("rexard") }
    var appPublic: URL { root.appendingPathComponent("app") }
    var cache: URL { root.appendingPathComponent("Generated/rexard-hashes.json") }
    var paths: FoundryPaths { FoundryPaths(repository: root.appendingPathComponent("pf2e"), appPublic: appPublic) }

    init() throws {
        try Pattern.rising.write(to: packs.appendingPathComponent("Weapons/sword.png"), size: 96)
        try Pattern.falling.write(to: packs.appendingPathComponent("Potions/red.png"), size: 96)
        try Pattern.stripes.write(to: packs.appendingPathComponent("Misc/stripes.png"), size: 96)
        try Data("not a picture".utf8).write(to: packs.appendingPathComponent("Misc/broken.png"))
        try Pattern.rising.write(to: appPublic.appendingPathComponent("icons/weapons/sword.webp"), size: 40)
        try Pattern.stripes.write(to: appPublic.appendingPathComponent("icons/feats/other.webp"), size: 40)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func sources(overrides: [String: String] = [:]) -> IconSources {
        IconSources(paths: paths, rexard: RexardIcons.load(folder: packs, cache: cache), overrides: overrides)
    }

    static func document(_ id: String, _ name: String, type: String, img: String = "",
                         category: EntryCategory = .equipment, system: [String: Any] = [:]) -> SourceDocument {
        let pack = PackLocation(system: .pathfinder, folder: category.rawValue, linkName: category.rawValue,
                                documentType: category == .bestiary ? "Actor" : "Item",
                                directory: URL(fileURLWithPath: "/"))
        let json = JSONValue(any: ["_id": id, "name": name, "type": type, "img": img, "system": system])
        return SourceDocument(pack: pack, json: json, category: category)
    }
}
