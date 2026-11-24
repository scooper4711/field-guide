import Bestiary
import CoreGraphics
import Foundation
import ImageIO
import SharedLibraries
import UniformTypeIdentifiers

/// A shared library in a folder of its own, with custom creatures and art written as Turnkeeper and Pawn Shop write
/// them.
struct SharedLibraryFixture {
    let folder: URL
    let library: SharedLibrary

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("SharedLibrary-\(UUID())")
        library = try SharedLibrary(folder: folder, app: .fieldGuide)
    }

    /// A custom creature Turnkeeper saved, with a stat block; the row's name and size can differ from the record's.
    @discardableResult
    func addCreature(_ creature: Creature, rowName: String? = nil, size: CreatureSize? = nil) throws -> UUID {
        let id = UUID()
        let record = try JSONEncoder().encode(["creature": creature])
        try library.save(CustomCreatureRecord(id: id, name: rowName ?? creature.name, campaignID: nil,
                                              sharedVersion: nil, record: record, game: .pathfinder, size: size))
        return id
    }

    /// A custom pawn Pawn Shop made: a name and a size, and no stat block.
    @discardableResult
    func addPawn(named name: String) throws -> UUID {
        let id = UUID()
        try library.save(CustomCreatureRecord(id: id, name: name, campaignID: nil, sharedVersion: nil, record: Data(),
                                              size: .tiny))
        return id
    }

    /// Custom art with a `pixels`-wide image, chosen for `subject`.
    @discardableResult
    func addArt(for subject: String, pixels: Int = 200) throws -> UUID {
        let id = UUID()
        try library.save(CustomArtRecord(id: id, fileName: "\(id).png", sharedVersion: nil, record: Data()),
                         image: Self.png(pixels: pixels))
        try library.setCreatureArt(.custom(id), for: subject)
        return id
    }

    static func creature(_ name: String, game: Game = .pathfinder, kind: CreatureKind = .creature) -> Creature {
        var creature = Creature(key: "custom.stored", name: name, game: game)
        creature.kind = kind
        creature.level = 3
        creature.traits = TraitLine(rarity: "uncommon", size: "Medium", traits: ["goblin", "humanoid"])
        return creature
    }

    static func png(pixels: Int) -> Data {
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let data = NSMutableData()
        guard let image = context?.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
