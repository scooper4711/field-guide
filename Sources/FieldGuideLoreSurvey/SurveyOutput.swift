import Foundation
import SourcebookLore

/// The survey's results: the sourcebook list the app ships, and a report of what was found.
struct SurveyOutput {
    /// Paizo's free Divine Mysteries Web Supplement, which Scrollkeeper offers to every library under this SKU.
    static let webSupplement = Sourcebook(
        title: "Pathfinder Lost Omens Divine Mysteries Web Supplement", sku: "PZO13003WS",
        aliases: ["PZO13003_SupplementalGodTable", "Divine Mysteries Web Supplement"],
        downloadURL: URL(string: "https://downloads.paizo.com/PZO13003_SupplementalGodTable.pdf"),
        supplies: [.deityLore])

    /// Paizo's free Gods & Magic Web Supplement: divine intercessions for twenty deities, written before the remaster.
    static let godsAndMagicSupplement = Sourcebook(
        title: "Pathfinder Lost Omens Gods & Magic Web Supplement", sku: "PZO9303WS",
        aliases: ["PZO9303 Gods & Magic Web Supplement", "Gods & Magic Web Supplement"],
        downloadURL: URL(string: "https://paizo-images.s3-us-west-2.amazonaws.com/image/download/"
                         + "PZO9303+Gods+%26+Magic+Web+Supplement.pdf"),
        supplies: [.deityLore], isLegacy: true)

    /// Books written for the rules before the remaster: their intercessions are used only where no newer book has
    /// one, and say so.
    static let legacyBooks: Set<String> = [
        "Pathfinder Lost Omens Gods & Magic", "Pathfinder Lost Omens Gods & Magic Web Supplement"
    ]

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    let list: SourcebookList
    let report: String

    init(deities: [FoundryDeity], books: [LibraryBook], findings: [String: [LoreSourceChooser.Finding]]) {
        let inLibrary = Set(books.map(\.title))
        var sources: [String: LoreSources] = [:]
        for deity in deities {
            var chosen = LoreSourceChooser.sources(of: deity.facts, findings: findings[deity.id] ?? [],
                                                   preferredTables: [Self.webSupplement.title],
                                                   legacyBooks: Self.legacyBooks)
            // A credited book that isn't in the library is assumed to hold what is missing, so the app can name it.
            let credited = deity.facts.credited
            if !credited.isEmpty, !inLibrary.contains(credited), credited != "Pathfinder Blog" {
                chosen.stats = chosen.stats ?? credited
                chosen.prose = chosen.prose ?? credited
            }
            if !chosen.books.isEmpty { sources[deity.id] = chosen }
        }
        let used = Set(sources.values.flatMap(\.books))
        let sourcebooks = used.sorted().map { title in Self.sourcebook(titled: title, books: books) }
        list = SourcebookList(books: sourcebooks, deities: sources)
        report = Self.report(deities: deities, sources: sources, inLibrary: inLibrary)
    }

    private static func sourcebook(titled title: String, books: [LibraryBook]) -> Sourcebook {
        if title == webSupplement.title { return webSupplement }
        if title == godsAndMagicSupplement.title { return godsAndMagicSupplement }
        let book = books.first { $0.title == title }
        let aliases = [book?.folderName].compactMap { $0 }.filter { $0 != title }
        return Sourcebook(title: title, sku: book?.sku, aliases: aliases, supplies: [.deityLore],
                          isLegacy: legacyBooks.contains(title) ? true : nil)
    }

    private static func report(deities: [FoundryDeity], sources: [String: LoreSources],
                               inLibrary: Set<String>) -> String {
        var lines = ["# Deity lore survey", ""]
        let stats = Dictionary(grouping: sources.values.compactMap(\.stats), by: { $0 }).mapValues(\.count)
        let prose = Dictionary(grouping: sources.values.compactMap(\.prose), by: { $0 }).mapValues(\.count)
        lines += ["| Book | In library | Stat lines | Prose |", "|---|---|---|---|"]
        for title in Set(stats.keys).union(prose.keys).sorted() {
            lines.append("| \(title) | \(inLibrary.contains(title) ? "yes" : "no") | \(stats[title] ?? 0) | "
                + "\(prose[title] ?? 0) |")
        }
        let withoutStats = deities.filter { sources[$0.id]?.stats == nil }.map(\.facts.name).sorted()
        let withoutProse = deities.filter { sources[$0.id]?.prose == nil }.map(\.facts.name).sorted()
        lines += ["", "\(withoutStats.count) deities without stat lines: \(withoutStats.joined(separator: ", "))"]
        lines += ["", "\(withoutProse.count) deities without prose: \(withoutProse.joined(separator: ", "))", ""]
        return lines.joined(separator: "\n")
    }
}
