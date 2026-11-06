import Foundation

/// What a creature's Lore tab shows, read from the user's bestiary: the paragraphs about the creature, then those
/// introducing its family, as the books print them before its stat block.
public struct CreatureLore: Codable, Equatable, Sendable {
    public var paragraphs: [String]
    /// The family's name as its heading prints it, such as "Serpentfolk"; empty for a creature without one.
    public var family: String
    public var familyParagraphs: [String]

    public init(paragraphs: [String] = [], family: String = "", familyParagraphs: [String] = []) {
        self.paragraphs = paragraphs
        self.family = family
        self.familyParagraphs = familyParagraphs
    }

    /// The match keys a book may print `name` under, best first: the name itself, then for a variant such as
    /// "Adamantine Dragon (Adult, Spellcaster)" the stat block's own "Adult Adamantine Dragon", then the base name.
    public static func keys(for name: String) -> [String] {
        var keys = [TextRepair.matchKey(name)]
        if let open = name.lastIndex(of: "("), name.hasSuffix(")") {
            let base = name[..<open].trimmingCharacters(in: .whitespaces)
            let qualifiers = name[name.index(after: open)..<name.index(before: name.endIndex)]
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.caseInsensitiveCompare("Spellcaster") != .orderedSame }
            keys += [TextRepair.matchKey((qualifiers + [base]).joined(separator: " ")), TextRepair.matchKey(base)]
        }
        return keys.reduce(into: []) { unique, key in if !unique.contains(key) { unique.append(key) } }
    }

    public var isEmpty: Bool { paragraphs.isEmpty && familyParagraphs.isEmpty }

    /// The lore as the Lore tab's HTML: the creature's paragraphs, then its family's under the family's name.
    public var html: String {
        let own = paragraphs.map { "<p>\(HTMLText.escape($0))</p>" }.joined()
        let heading = family.isEmpty ? "" : "<h3>\(HTMLText.escape(family))</h3>"
        let family = familyParagraphs.isEmpty
            ? "" : heading + familyParagraphs.map { "<p>\(HTMLText.escape($0))</p>" }.joined()
        let rule = own.isEmpty || family.isEmpty ? "" : "<hr>"
        return "<section class=\"description\">" + own + rule + family + "</section>"
    }
}

/// A creature in the catalog whose lore the user's books may give.
public struct CreatureReference: Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// The book Foundry credits, such as "Pathfinder Bestiary".
    public var credited: String

    public init(id: String, name: String, credited: String) {
        self.id = id
        self.name = name
        self.credited = credited
    }
}

/// Text made safe to put in HTML.
enum HTMLText {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
