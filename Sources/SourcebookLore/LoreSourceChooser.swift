import Foundation

/// Picks the books each deity's lore comes from, given what a survey of the books found (FieldGuideLoreSurvey):
/// stat lines from a table when one lists the deity (the Web Supplement lists nearly all of them, in their current
/// wording), else from the write-up in the book Foundry credits, else from the write-up whose edicts match Foundry's;
/// prose from the credited book's write-up, else from the write-up that opens as Foundry's text does.
public enum LoreSourceChooser {
    /// What Foundry says about a deity.
    public struct Deity: Sendable {
        public var name: String
        /// The book Foundry credits.
        public var credited: String
        public var edicts: String
        /// Foundry's prose about the deity, as plain text.
        public var prose: String

        public init(name: String, credited: String, edicts: String = "", prose: String = "") {
            self.name = name
            self.credited = credited
            self.edicts = edicts
            self.prose = prose
        }
    }

    /// The lore one book gave a deity.
    public struct Finding: Sendable {
        public var book: String
        public var lore: DeityLore
        /// True when the book gave it as a table row.
        public var isTable: Bool

        public init(book: String, lore: DeityLore, isTable: Bool = false) {
            self.book = book
            self.lore = lore
            self.isTable = isTable
        }
    }

    /// The deity's sources; `preferredTables` are the tables tried first, such as the free Web Supplement, which
    /// every user can have.
    public static func sources(of deity: Deity, findings: [Finding], preferredTables: [String] = [],
                               legacyBooks: Set<String> = []) -> LoreSources {
        LoreSources(stats: statsSource(of: deity, findings: findings, preferredTables: preferredTables),
                    prose: proseSource(of: deity, findings: findings),
                    intercession: intercessionSource(of: deity, findings: findings, legacyBooks: legacyBooks))
    }

    /// The credited book's intercession, else one written for the current rules, else one from `legacyBooks`.
    static func intercessionSource(of deity: Deity, findings: [Finding], legacyBooks: Set<String> = []) -> String? {
        let withIntercession = findings.filter { $0.lore.intercession != nil }
        if let credited = withIntercession.first(where: { $0.book == deity.credited }) { return credited.book }
        return (withIntercession.first { !legacyBooks.contains($0.book) } ?? withIntercession.first)?.book
    }

    static func statsSource(of deity: Deity, findings: [Finding], preferredTables: [String] = []) -> String? {
        let withStats = findings.filter { $0.lore.statLines.contains { $0.label == "Edicts" || $0.label == "Title" } }
        let tables = withStats.filter(\.isTable)
        if let preferred = preferredTables.first(where: { title in tables.contains { $0.book == title } }) {
            return preferred
        }
        if let table = tables.first { return table.book }
        if let credited = withStats.first(where: { $0.book == deity.credited }) { return credited.book }
        return withStats.max { similarity(edicts(of: $0), deity.edicts) < similarity(edicts(of: $1), deity.edicts) }?
            .book
    }

    static func proseSource(of deity: Deity, findings: [Finding]) -> String? {
        let withProse = findings.filter { !$0.isTable && !$0.lore.paragraphs.isEmpty }
        if let credited = withProse.first(where: { $0.book == deity.credited }) { return credited.book }
        let opening = String(TextRepair.matchKey(deity.prose).prefix(60))
        guard !opening.isEmpty else { return nil }
        return withProse.first { TextRepair.matchKey($0.lore.paragraphs.joined(separator: " ")).contains(opening) }?
            .book
    }

    private static func edicts(of finding: Finding) -> String {
        finding.lore.statLines.first { $0.label == "Edicts" }?.text ?? ""
    }

    /// The share of the two texts' words they have in common, from 0 to 1.
    static func similarity(_ first: String, _ second: String) -> Double {
        let words = { (text: String) in Set(text.lowercased().split { !$0.isLetter }.map(String.init)) }
        let (one, two) = (words(first), words(second))
        guard !one.isEmpty || !two.isEmpty else { return 0 }
        return Double(one.intersection(two).count) / Double(one.union(two).count)
    }
}
