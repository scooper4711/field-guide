import FieldGuideKit
import Foundation

/// The icon most entries like an entry show, learned from the entries whose icons were found: entries sharing
/// its weapon or armor group, its consumable category, then a trait, and for items their type. pf2e gives
/// items without art only a placeholder for their type, so there is no mapping to follow instead.
/// `CategoryIcons` covers the entries nothing here fits.
struct LearnedIcons {
    /// How much a key's entries must agree before their most common icon stands for it.
    struct Agreement {
        /// A key needs this many entries with icons.
        var minimumEntries: Int
        /// The share of a key's entries its most common icon must exceed.
        var minimumShare: Double
        var rule: IconMap.Rule

        /// Otherwise the entries don't share an icon and the most common one is as good as random.
        static let shared = Agreement(minimumEntries: 3, minimumShare: 1.0 / 3, rule: .learned)
        /// The most common icon of the nearest key, however few show it: a potion whose potions all show
        /// different bottles still gets a bottle.
        static let any = Agreement(minimumEntries: 1, minimumShare: 0, rule: .similar)
    }

    private let agreement: Agreement
    /// Rexard files by key, chosen by hand where the entries' own icons say little.
    private let overrides: [String: String]
    /// How often each icon is shown, by key.
    private var counts: [String: [String: Int]] = [:]

    init(documents: [SourceDocument], choices: [String: IconMap.Choice], agreement: Agreement = .shared,
         overrides: [String: String] = [:]) {
        self.agreement = agreement
        self.overrides = overrides
        for document in documents {
            guard let file = choices[document.uuid]?.file else { continue }
            for key in Self.keys(of: document).flatMap({ $0 }) {
                counts[key, default: [:]][file, default: 0] += 1
            }
        }
    }

    func choice(for document: SourceDocument) -> IconMap.Choice? {
        for keys in Self.keys(of: document) {
            if let key = keys.first(where: { overrides[$0] != nil }), let file = overrides[key] {
                return IconMap.Choice(file: file, rule: .override, detail: key)
            }
            // Of several traits, the one whose entries agree most is the most telling.
            let shared = keys.compactMap { key in counts[key].flatMap { sharedIcon(of: $0, key: key) } }
            if let best = shared.max(by: { $0.share < $1.share }) { return best.choice }
        }
        return nil
    }

    /// The icon most of a key's entries show, when enough of them do.
    private func sharedIcon(of icons: [String: Int], key: String) -> (choice: IconMap.Choice, share: Double)? {
        let total = icons.values.reduce(0, +)
        guard total >= agreement.minimumEntries,
              let top = icons.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return nil }
        let share = Double(top.value) / Double(total)
        guard share > agreement.minimumShare else { return nil }
        return (IconMap.Choice(file: top.key, rule: agreement.rule, detail: key), share)
    }

    /// An entry's keys, most specific first; the keys in one group are equally specific.
    static func keys(of document: SourceDocument) -> [[String]] {
        let prefix = "\(document.system.rawValue).\(document.category.rawValue)."
        let groups = document.category == .equipment ? itemKeys(of: document) : traitKeys(of: document)
        return groups.filter { !$0.isEmpty }.map { $0.map { prefix + $0 } }
    }

    /// An item's group, consumable category, traits and type. Of the traits, the one whose items agree most
    /// decides, so a potion's `potion` outweighs its `magical`.
    private static func itemKeys(of document: SourceDocument) -> [[String]] {
        let system = document.systemData
        let type = document.type
        return [
            [system["group"].string].filter { !$0.isEmpty }.map { "group:\(type).\($0)" },
            type == "consumable" ? [system["category"].string].filter { !$0.isEmpty }.map { "consumable:\($0)" } : [],
            traits(of: document).map { "trait:\($0)" },
            ["type:\(type)"]
        ]
    }

    /// The traits of anything else, with a spell's traditions: a fire spell looks like other fire spells.
    private static func traitKeys(of document: SourceDocument) -> [[String]] {
        [(traits(of: document) + document.systemData[path: "traits.traditions"].strings).map { "trait:\($0)" }]
    }

    /// The rarities, which pf2e keeps apart from the traits but which older data lists among them; they say
    /// nothing about what an entry looks like.
    private static let rarities: Set<String> = ["common", "uncommon", "rare", "unique"]

    private static func traits(of document: SourceDocument) -> [String] {
        document.systemData[path: "traits.value"].strings.filter { !rarities.contains($0) }
    }
}

/// The icon standing for a category, for the entries no closer rule gives one, in place of the category's
/// symbol: the one chosen by hand (`category:<category>`), else the one most of its matched entries show over both
/// systems, a tie going to the first file by path.
struct CategoryIcons {
    static let overridePrefix = "category:"
    private var files: [EntryCategory: String] = [:]

    init(documents: [SourceDocument], choices: [String: IconMap.Choice], overrides: [String: String] = [:]) {
        var counts: [EntryCategory: [String: Int]] = [:]
        for document in documents {
            guard let file = choices[document.uuid]?.file else { continue }
            counts[document.category, default: [:]][file, default: 0] += 1
        }
        files = counts.compactMapValues { icons in icons.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key }
        for category in EntryCategory.allCases {
            if let file = overrides[Self.overridePrefix + category.rawValue] { files[category] = file }
        }
    }

    func file(for category: EntryCategory) -> String? { files[category] }

    func choice(for document: SourceDocument) -> IconMap.Choice? {
        file(for: document.category).map {
            IconMap.Choice(file: $0, rule: .category, detail: document.category.rawValue)
        }
    }
}
