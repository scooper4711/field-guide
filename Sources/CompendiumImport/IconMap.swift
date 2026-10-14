import FieldGuideKit
import Foundation

/// Where an entry's icon comes from, since Foundry's and Paizo's icons may not ship.
public struct IconSources: Sendable {
    public var paths: FoundryPaths
    /// The user's Rexard packs; nil for no icons.
    public var rexard: RexardIcons?
    /// Rexard files (paths in the packs) by Foundry path or entry id, for icons the rules pick badly.
    public var overrides: [String: String]
    /// The matches of an earlier import, by Foundry path, used for Foundry icons not on this machine, such as
    /// the Foundry app's on GitHub.
    public var savedMatches: [String: IconMatch]

    public init(paths: FoundryPaths, rexard: RexardIcons?, overrides: [String: String] = [:],
                savedMatches: [String: IconMatch] = [:]) {
        self.paths = paths
        self.rexard = rexard
        self.overrides = overrides
        self.savedMatches = savedMatches
    }

    /// The overrides in a JSON object of Foundry paths or entry ids to Rexard files; none when there is no file.
    public static func overrides(in url: URL) throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
}

/// The Rexard picture a Foundry icon matched, and how many hash bits (of 256) differ.
public struct IconMatch: Equatable, Sendable {
    public var file: String
    public var distance: Int

    public init(file: String, distance: Int) {
        self.file = file
        self.distance = distance
    }

    /// Matches as tab-separated lines of Foundry path, Rexard file and distance, sorted, under a header.
    public static func table(_ matches: [String: IconMatch]) -> String {
        let lines = matches.sorted { $0.key < $1.key }.map { "\($0.key)\t\($0.value.file)\t\($0.value.distance)" }
        return (["foundry\trexard\tdistance"] + lines).joined(separator: "\n") + "\n"
    }

    /// The matches in a table written by `table(_:)`; none when there is no file.
    public static func matches(in url: URL) throws -> [String: IconMatch] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let rows = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst()
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        return Dictionary(rows.compactMap { fields in
            guard fields.count == 3, let distance = Int(fields[2]) else { return nil }
            return (fields[0], IconMatch(file: fields[1], distance: distance))
        }, uniquingKeysWith: { first, _ in first })
    }
}

/// Which of the user's Rexard icons each entry shows: the Rexard original of its Foundry icon, else its base
/// item's icon, else the icon most entries like it show.
final class IconMap {
    enum Rule: String, CaseIterable, Sendable {
        case override, match, baseItem = "base item", learned
    }

    struct Choice: Sendable {
        var file: String
        var rule: Rule
        /// Why: a match's distance to the Foundry icon, or the key a learned icon was learned from.
        var detail = ""
    }

    /// The largest number of differing hash bits (of 256) at which a Foundry icon still counts as the Rexard
    /// picture. Checked by eye: core icons match their Rexard originals up to about 20, and the first wrong
    /// picks (thin bars) come at 16 to 26; pf2e's own icons within 12 are Rexard pictures recolored.
    static let maximumDistance = 12

    /// The choice for each entry id; entries without one show their category's symbol.
    private(set) var choices: [String: Choice] = [:]
    /// The Foundry icons of entries left without one, with how many entries use each.
    private(set) var unresolved: [String: Int] = [:]
    /// The Rexard picture each Foundry icon matched, compared here or saved by an earlier import.
    private(set) var matches: [String: IconMatch] = [:]

    init(documents: [SourceDocument], sources: IconSources) {
        guard let rexard = sources.rexard else { return }
        let documents = documents.filter { !$0.category.isCreature }
        matches = Self.matches(of: documents, sources: sources, rexard: rexard)
        for document in documents {
            let path = document.json["img"].string
            if let file = sources.overrides[document.uuid] ?? sources.overrides[path] {
                choices[document.uuid] = Choice(file: file, rule: .override)
            } else if let match = matches[path] {
                choices[document.uuid] = Choice(file: match.file, rule: .match, detail: "\(match.distance)")
            }
        }
        let resolved = documents.filter { choices[$0.uuid] != nil }
        let baseItems = Self.baseItems(in: resolved, choices: choices)
        let learned = LearnedIcons(documents: resolved, choices: choices)
        for document in documents where choices[document.uuid] == nil {
            choices[document.uuid] = baseItems.choice(for: document) ?? learned.choice(for: document)
            if choices[document.uuid] == nil { unresolved[document.json["img"].string, default: 0] += 1 }
        }
    }

    func choice(for document: SourceDocument) -> Choice? { choices[document.uuid] }

    /// How many entries got their icon by each rule.
    var counts: [Rule: Int] {
        Dictionary(grouping: choices.values, by: \.rule).mapValues(\.count)
    }

    /// A tab-separated line per entry with an icon: id, name, Foundry icon, Rexard file, rule and why, for
    /// checking the choices and writing overrides.
    func table(of documents: [SourceDocument]) -> String {
        let lines = documents.compactMap { document -> String? in
            guard let choice = choices[document.uuid] else { return nil }
            return [document.uuid, document.name, document.json["img"].string, choice.file, choice.rule.rawValue,
                    choice.detail].joined(separator: "\t")
        }
        return (["id\tname\tfoundry\trexard\trule\tdetail"] + lines).joined(separator: "\n") + "\n"
    }

    /// The nearest Rexard picture of each Foundry icon the documents use, when near enough. Icons whose files
    /// aren't on this machine take their saved match.
    private static func matches(of documents: [SourceDocument], sources: IconSources,
                                rexard: RexardIcons) -> [String: IconMatch] {
        let icons = Set(documents.map { $0.json["img"].string }).filter { !$0.isEmpty && !$0.hasSuffix(".svg") }
        let files = Dictionary(uniqueKeysWithValues: icons.map { ($0, sources.paths.file(for: $0)) })
        let present = files.compactMap { path, file in
            file.flatMap { FileManager.default.fileExists(atPath: $0.path) ? (path, $0) : nil }
        }
        let found = parallelMap(present) { path, file in (path, rexard.bestMatch(for: file)) }
        let compared = found.compactMap { path, match -> (String, IconMatch)? in
            guard let match, match.distance <= maximumDistance else { return nil }
            return (path, IconMatch(file: match.file, distance: match.distance))
        }
        let saved = icons.subtracting(present.map(\.0))
            .compactMap { path in sources.savedMatches[path].map { (path, $0) } }
        return Dictionary(uniqueKeysWithValues: compared + saved)
    }

    /// The icons of base items (a longsword's for a +1 longsword), by system and slug.
    private static func baseItems(in documents: [SourceDocument], choices: [String: Choice]) -> BaseItems {
        var icons: [String: String] = [:]
        for document in documents where document.category == .equipment {
            let base = document.systemData["baseItem"].string
            guard !base.isEmpty, base == slug(document.name), let file = choices[document.uuid]?.file else { continue }
            icons["\(document.system.rawValue).\(base)"] = file
        }
        return BaseItems(icons: icons)
    }

    /// pf2e's slug of a name: lowercase letters and digits joined by hyphens.
    static func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "'", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
    }
}

/// The icons of base items, by `<system>.<slug>`.
private struct BaseItems {
    let icons: [String: String]

    func choice(for document: SourceDocument) -> IconMap.Choice? {
        let base = document.systemData["baseItem"].string
        guard !base.isEmpty, let file = icons["\(document.system.rawValue).\(base)"] else { return nil }
        return IconMap.Choice(file: file, rule: .baseItem)
    }
}

extension EntryCategory {
    /// Creatures and hazards show art from the user's PDFs instead of an icon.
    var isCreature: Bool { self == .bestiary || self == .hazards }
}
