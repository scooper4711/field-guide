import Bestiary
import CreatureArt
import FieldGuideKit
import Foundation
import SharedLibraries

/// What Field Guide reads from the creature library the Tableside apps share (shared libraries R4): the custom
/// creatures that have a stat block, the art chosen for each creature, and where custom art's images are. Field
/// Guide shows them but never changes them; making and editing stat blocks stays in Turnkeeper (R4.3).
struct CreatureLibraryContents: Equatable {
    /// The prefix of a custom creature's key, `custom.<id>`, as Turnkeeper keys it.
    static let keyPrefix = "custom."

    /// Custom creatures by key, with the row's name and size over the record's (R4.4a, R4.7).
    var creatures: [String: Creature] = [:]
    /// The art chosen for each creature, by its bestiary key or `custom.<id>` (R3.4).
    var choices: [String: CreatureArtChoice] = [:]
    /// Custom art's image files, by the art's ID.
    var customFiles: [UUID: URL] = [:]

    init() {}

    init(reading library: SharedLibrary) throws {
        for row in try library.customCreatures() {
            guard let creature = Self.creature(from: row) else { continue }
            creatures[creature.key] = creature
        }
        choices = try library.creatureArt()
        for art in try library.customArt() {
            customFiles[art.id] = library.customFile(art.fileName)
        }
    }

    static func isCustomKey(_ key: String) -> Bool { key.hasPrefix(keyPrefix) }

    /// The creature a row holds; nil for one without a stat block (a custom pawn made in Pawn Shop, R4.6) or with a
    /// record this version can't read.
    static func creature(from row: CustomCreatureRecord) -> Creature? {
        guard row.hasStatBlock, let stored = try? JSONDecoder().decode(StoredCreature.self, from: row.record)
        else { return nil }
        var creature = stored.creature.applying(name: row.name, size: row.size)
        creature.key = keyPrefix + row.id.uuidString
        return creature
    }

    /// The list entries of the custom creatures: creatures in the Bestiary, complex hazards in Hazards.
    var summaries: [EntrySummary] {
        creatures.values.map(Self.summary(of:))
    }

    static func summary(of creature: Creature) -> EntrySummary {
        let isHazard = creature.kind == .hazard
        let category: EntryCategory = isHazard ? .hazards : .bestiary
        return EntrySummary(
            id: creature.key, system: creature.game == .starfinder ? .starfinder : .pathfinder, category: category,
            name: creature.name, level: creature.level, subtitle: "\(category.singularTitle) \(creature.level)",
            image: Thumbnail.creaturePrefix + creature.key, facets: facets(of: creature)
        )
    }

    /// The values the list filters by, without empty ones, as the import leaves them out. Turnkeeper's hazards are
    /// all complex, since only complex hazards take a turn; size is a creature's facet.
    private static func facets(of creature: Creature) -> [Facet: [String]] {
        let traits = creature.traits
        let isHazard = creature.kind == .hazard
        let facets: [Facet: [String]] = [
            .rarity: [traits.rarity.capitalized], .traits: traits.traits.map(\.capitalized),
            .source: [customSource], isHazard ? .complexity : .size: [isHazard ? "Complex" : traits.size.capitalized]
        ]
        return facets.mapValues { $0.filter { !$0.isEmpty } }.filter { !$0.value.isEmpty }
    }

    /// The source custom creatures are filtered by.
    static let customSource = "Custom"
}

/// Turnkeeper's `CustomCreature` as stored in the library's `record`: Field Guide reads only its stat block.
private struct StoredCreature: Decodable {
    let creature: Creature
}
