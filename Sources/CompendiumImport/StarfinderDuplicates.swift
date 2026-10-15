import FieldGuideKit
import Foundation

/// Pathfinder entries the Starfinder build copies into its own packs, as listed in `build/duplicates.json`
/// (conditions, basic actions, many spells and feats), with the Starfinder publication where one is given.
struct StarfinderDuplicates {
    struct Listing: Equatable {
        var folder: String
        var name: String
        var publication: String?
    }

    let listings: [Listing]

    init(listings: [Listing]) {
        self.listings = listings
    }

    init(repository: URL) {
        let file = repository.appendingPathComponent("build/duplicates.json")
        let groups = (try? JSONValue(contentsOf: file))?.array ?? []
        listings = groups.flatMap(Self.listings(in:))
    }

    /// Starfinder copies of the listed Pathfinder documents, in the Starfinder pack of the same folder.
    func copies(of pathfinder: [SourceDocument], into starfinderPacks: [PackLocation]) -> [SourceDocument] {
        let packs = Dictionary(starfinderPacks.map { ($0.folder, $0) }, uniquingKeysWith: { first, _ in first })
        let byFolderAndName = Dictionary(pathfinder.map { ("\($0.pack.folder)/\($0.name)", $0) },
                                         uniquingKeysWith: { first, _ in first })
        return listings.compactMap { listing in
            guard let pack = packs[listing.folder],
                  let source = byFolderAndName["\(listing.folder)/\(listing.name)"] else {
                return nil
            }
            var json = source.json
            if let publication = listing.publication {
                json = json.setting("system.publication.title", to: .string(publication))
            }
            return SourceDocument(pack: pack, json: json, category: source.category)
        }
    }

    /// The listings of one group in `duplicates.json`: its entries by folder, under its publication.
    private static func listings(in group: JSONValue) -> [Listing] {
        let publication = group["publication"].string
        return group["entries"].object.flatMap { folder, names in
            names.strings.map { Listing(folder: folder, name: $0,
                                        publication: publication.isEmpty ? nil : publication) }
        }
    }
}

extension JSONValue {
    /// A copy with the value at a dotted path replaced, creating objects along the way.
    func setting(_ path: String, to value: JSONValue) -> JSONValue {
        let keys = path.split(separator: ".").map(String.init)
        guard let first = keys.first else { return value }
        var object = self.object
        object[first] = keys.count == 1 ? value : self[first].setting(keys.dropFirst().joined(separator: "."),
                                                                      to: value)
        return .object(object)
    }
}
