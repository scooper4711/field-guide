import FieldGuideKit
import Foundation

/// The icon most entries like an entry show, learned from the entries whose icons were found: entries sharing
/// its weapon or armor group, its consumable category, then a trait, and for items their type. pf2e gives
/// items without art only a placeholder for their type, so there is no mapping to follow instead. There is no
/// fallback for a whole category: one icon on every action or deity would say nothing.
struct LearnedIcons {
    /// A key needs this many entries with icons before its most common icon stands for it.
    static let minimumEntries = 3
    /// The share of a key's entries its most common icon must exceed: otherwise the entries don't share an icon
    /// and the most common one is as good as random.
    static let minimumShare = 1.0 / 3

    /// How often each icon is shown, by key.
    private var counts: [String: [String: Int]] = [:]

    init(documents: [SourceDocument], choices: [String: IconMap.Choice]) {
        for document in documents {
            guard let file = choices[document.uuid]?.file else { continue }
            for key in Self.keys(of: document).flatMap({ $0 }) {
                counts[key, default: [:]][file, default: 0] += 1
            }
        }
    }

    func choice(for document: SourceDocument) -> IconMap.Choice? {
        for keys in Self.keys(of: document) {
            // Of several traits, the one whose entries agree most is the most telling.
            let shared = keys.compactMap { key in counts[key].flatMap { Self.sharedIcon(of: $0, key: key) } }
            if let best = shared.max(by: { $0.share < $1.share }) { return best.choice }
        }
        return nil
    }

    /// The icon most of a key's entries show, when enough of them do.
    private static func sharedIcon(of icons: [String: Int], key: String) -> (choice: IconMap.Choice, share: Double)? {
        let total = icons.values.reduce(0, +)
        guard total >= minimumEntries,
              let top = icons.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return nil }
        let share = Double(top.value) / Double(total)
        return share > minimumShare ? (IconMap.Choice(file: top.key, rule: .learned, detail: key), share) : nil
    }

    /// An entry's keys, most specific first; the keys in one group are equally specific.
    static func keys(of document: SourceDocument) -> [[String]] {
        let prefix = "\(document.system.rawValue).\(document.category.rawValue)."
        let groups = document.category == .equipment ? itemKeys(of: document) : traitKeys(of: document)
        return groups.filter { !$0.isEmpty }.map { $0.map { prefix + $0 } }
    }

    /// An item's group, consumable category and type. An item's traits (deadly, aeon) say little about what it
    /// looks like.
    private static func itemKeys(of document: SourceDocument) -> [[String]] {
        let system = document.systemData
        let type = document.type
        return [
            [system["group"].string].filter { !$0.isEmpty }.map { "group:\(type).\($0)" },
            type == "consumable" ? [system["category"].string].filter { !$0.isEmpty }.map { "consumable:\($0)" } : [],
            ["type:\(type)"]
        ]
    }

    /// The traits of anything else, with a spell's traditions: a fire spell looks like other fire spells.
    private static func traitKeys(of document: SourceDocument) -> [[String]] {
        let traits = document.systemData[path: "traits.value"].strings
            + document.systemData[path: "traits.traditions"].strings
        return [traits.map { "trait:\($0)" }]
    }
}
