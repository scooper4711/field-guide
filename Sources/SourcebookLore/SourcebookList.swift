import Foundation

/// A product whose PDF supplies content Field Guide reads on the device: deity lore, creature art or item art.
public struct Sourcebook: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// What a product supplies.
    public enum Supply: String, Codable, Sendable, CaseIterable {
        case deityLore, creatureArt, itemArt
    }

    /// The product's name as Foundry credits it, such as "Pathfinder Lost Omens Divine Mysteries".
    public var title: String
    /// Paizo's SKU, which Scrollkeeper knows the product by; nil when no copy was at hand to read it from.
    public var sku: String?
    /// Other names the product's PDF or folder goes by, such as Scrollkeeper's "Pathfinder Lost Omens- Divine
    /// Mysteries".
    public var aliases: [String]
    /// Where a free product can be downloaded; nil for one that is sold.
    public var downloadURL: URL?
    public var supplies: [Supply]
    /// True for a book written for the rules before the remaster, whose intercessions say so.
    public var isLegacy: Bool?

    public var id: String { title }

    public init(title: String, sku: String? = nil, aliases: [String] = [], downloadURL: URL? = nil,
                supplies: [Supply], isLegacy: Bool? = nil) {
        self.title = title
        self.sku = sku
        self.aliases = aliases
        self.downloadURL = downloadURL
        self.supplies = supplies
        self.isLegacy = isLegacy
    }

    /// True when `name`, a file's or folder's name or a PDF's copyright line, names this product.
    public func isNamed(_ name: String) -> Bool {
        let key = Self.key(name)
        return ([title] + aliases).contains { Self.key($0) == key }
    }

    /// A name without the "PDF", "Single File" and SKU decorations Paizo's file names add, as a match key.
    static func key(_ name: String) -> String {
        var name = name.replacingOccurrences(of: #"\.pdf$"#, with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"^PZO\w+\s+"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s*(PDF)?\s*(-\s*)?(Single[- ]File)?\s*(PDF)?$"#, with: "",
                                         options: [.regularExpression, .caseInsensitive])
        return TextRepair.matchKey(name)
    }
}

/// Which books a deity's lore comes from: one for its stat lines, one for its prose.
public struct LoreSources: Codable, Equatable, Sendable {
    /// The title of the book whose write-up or table gives the stat lines.
    public var stats: String?
    /// The title of the book whose write-up gives the prose.
    public var prose: String?
    /// The title of the book that gives the divine intercession.
    public var intercession: String?

    public init(stats: String? = nil, prose: String? = nil, intercession: String? = nil) {
        self.stats = stats
        self.prose = prose
        self.intercession = intercession
    }

    /// The books named, without repeats.
    public var books: [String] {
        [stats, prose, intercession].compactMap { $0 }.reduce(into: []) { books, book in
            if !books.contains(book) { books.append(book) }
        }
    }
}

/// The sourcebooks Field Guide can read, and the books each deity's lore comes from (`sourcebooks.json`, written
/// by FieldGuideLoreSurvey).
public struct SourcebookList: Codable, Equatable, Sendable {
    public var books: [Sourcebook]
    /// The sources of each deity's lore, by entry ID.
    public var deities: [String: LoreSources]

    public init(books: [Sourcebook] = [], deities: [String: LoreSources] = [:]) {
        self.books = books
        self.deities = deities
    }

    /// The list shipped with the app; empty when it is missing.
    public static let bundled: SourcebookList = {
        guard let url = Bundle.module.url(forResource: "sourcebooks", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return SourcebookList() }
        return (try? JSONDecoder().decode(SourcebookList.self, from: data)) ?? SourcebookList()
    }()

    /// The book `name` (a file's or folder's name, or a copyright line) names, if any.
    public func book(named name: String) -> Sourcebook? {
        books.first { $0.isNamed(name) }
    }

    /// The deities whose stat lines or prose `book` supplies, by entry ID.
    public func deities(from book: Sourcebook) -> [String: LoreSources] {
        deities.filter { $0.value.books.contains(book.title) }
    }
}
