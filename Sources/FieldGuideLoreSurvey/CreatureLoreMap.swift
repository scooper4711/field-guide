import Foundation
import SourcebookLore

/// Finds the adventure creatures whose lore Foundry copied from a bestiary creature's, so the app can show the
/// bestiary's lore from the user's books without reading the adventure.
enum CreatureLoreMap {
    /// The books whose creatures' lore others share: the bestiaries the app reads reliably.
    static let bestiaries: Set<String> = Set(SourcebookList.pathfinderBestiaries).union([
        "Pathfinder NPC Core", "Pathfinder Howl of the Wild", "Pathfinder Rage of Elements", "Starfinder Alien Core"
    ])
    /// The share of words the two creatures' paragraphs must have in common.
    static let threshold = 0.6

    /// The bestiary creature each other creature's lore is, by entry ID.
    static func sources(of creatures: [FoundryCreature]) -> [String: CreatureSource] {
        let words = { (text: String) in Set(text.lowercased().split { !$0.isLetter }.map(String.init)) }
        let candidates = creatures.filter { bestiaries.contains($0.credited) && !$0.prose.isEmpty }
            .map { (creature: $0, words: words($0.prose)) }
        var sources: [String: CreatureSource] = [:]
        for creature in creatures where !bestiaries.contains(creature.credited) && !creature.prose.isEmpty {
            let own = words(creature.prose)
            let scored = candidates.filter { $0.creature.system == creature.system }
                .map { (creature: $0.creature, score: similarity(own, $0.words)) }
            guard let best = scored.max(by: { $0.score < $1.score }), best.score >= threshold else { continue }
            sources[creature.id] = CreatureSource(name: best.creature.name, book: best.creature.credited)
        }
        return sources
    }

    static func similarity(_ first: Set<String>, _ second: Set<String>) -> Double {
        guard !first.isEmpty || !second.isEmpty else { return 0 }
        return Double(first.intersection(second).count) / Double(first.union(second).count)
    }
}
