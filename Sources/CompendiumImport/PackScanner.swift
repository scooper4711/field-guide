import FieldGuideKit
import Foundation

/// One compendium pack folder in the pf2e repository.
public struct PackLocation: Sendable, Equatable {
    public var system: GameSystem
    /// The pack's folder name, such as `spells`.
    public var folder: String
    /// The name links use, such as `spells-srd` in `Compendium.pf2e.spells-srd.Item.…`.
    public var linkName: String
    /// `Item` or `Actor`.
    public var documentType: String
    public var directory: URL
}

/// Finds packs through the system manifests and reads their documents.
public struct PackScanner {
    public var repository: URL

    public init(repository: URL) {
        self.repository = repository
    }

    /// Every Item and Actor pack of a system, in manifest order.
    public func packs(of system: GameSystem) throws -> [PackLocation] {
        let manifestURL = repository.appendingPathComponent("system.\(system.rawValue).json")
        let manifest = try JSONValue(contentsOf: manifestURL)
        return manifest["packs"].array.filter { ["Item", "Actor"].contains($0["type"].string) }.map { pack in
            let folder = (pack["path"].string as NSString).lastPathComponent
            return PackLocation(
                system: system, folder: folder, linkName: pack["name"].string, documentType: pack["type"].string,
                directory: repository.appendingPathComponent("packs/\(system.rawValue)/\(folder)")
            )
        }
    }

    /// The JSON documents in a pack, searched recursively and sorted, without folder files.
    public func documentFiles(in pack: PackLocation) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: pack.directory, includingPropertiesForKeys: nil)
        else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix("_") }
            .sorted { $0.path < $1.path }
    }

    /// The pack's documents with the category each belongs in; documents of no category are left out.
    public func documents(in pack: PackLocation) -> [SourceDocument] {
        documentFiles(in: pack).compactMap { file in
            guard let json = try? JSONValue(contentsOf: file),
                  let category = CategoryMapper.category(of: json["type"].string, pack: pack.folder) else { return nil }
            return SourceDocument(pack: pack, json: json, category: category)
        }
    }
}

/// A document from a pack that becomes an entry.
public struct SourceDocument: Sendable {
    public var pack: PackLocation
    public var json: JSONValue
    public var category: EntryCategory

    public var system: GameSystem { pack.system }
    public var name: String { json["name"].string }
    public var type: String { json["type"].string }
    public var systemData: JSONValue { json["system"] }

    /// The Foundry UUID other documents link to it by.
    public var uuid: String {
        "Compendium.\(pack.system.rawValue).\(pack.linkName).\(pack.documentType).\(json["_id"].string)"
    }
}

/// Which category a document belongs in, by its type and pack.
public enum CategoryMapper {
    private static let equipmentTypes: Set<String> = [
        "weapon", "armor", "shield", "equipment", "consumable", "treasure", "backpack", "ammo", "kit"
    ]

    private static let byType: [String: EntryCategory] = [
        "action": .actions, "npc": .bestiary, "campaignFeature": .campaignFeatures, "feat": .feats,
        "hazard": .hazards, "spell": .spells, "condition": .conditions, "ancestry": .ancestries,
        "heritage": .heritages, "background": .backgrounds, "class": .classes, "deity": .deities
    ]

    public static func category(of type: String, pack: String) -> EntryCategory? {
        // Starfinder's conditions are effect items in its conditions pack.
        if pack == "conditions" { return .conditions }
        if equipmentTypes.contains(type) { return .equipment }
        return byType[type]
    }
}
