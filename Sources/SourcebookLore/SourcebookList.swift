import Foundation

/// A product whose PDF supplies content Field Guide reads on the device: lore (deities', creatures', or ancestries'
/// and classes' Details), creature art or item art.
public struct Sourcebook: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// What a product supplies.
    public enum Supply: String, Codable, Sendable, CaseIterable {
        case deityLore, creatureLore, detailsLore, creatureArt, itemArt
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

/// A creature in a bestiary whose lore another creature's is: an adventure's "Hooktongue Hydra" has the hydra's.
public struct CreatureSource: Codable, Equatable, Hashable, Sendable {
    public var name: String
    /// The book Foundry credits the bestiary creature to.
    public var book: String

    public init(name: String, book: String) {
        self.name = name
        self.book = book
    }
}

/// The sourcebooks Field Guide can read, the books each deity's lore comes from, and the bestiary creatures whose
/// lore adventures' creatures share (`sourcebooks.json`, written by FieldGuideLoreSurvey).
public struct SourcebookList: Codable, Equatable, Sendable {
    /// Monster Core and Monster Core 2 remaster the three Bestiaries: a creature from any of them takes its lore from
    /// the first of these books the user has that prints it.
    public static let pathfinderBestiaries = [
        "Pathfinder Monster Core", "Pathfinder Monster Core 2", "Pathfinder Bestiary", "Pathfinder Bestiary 2",
        "Pathfinder Bestiary 3"
    ]
    /// The sample sourcebook (`SampleSourcebook`): placeholder text under real creatures' and deities' names, for
    /// App Review and anyone without Paizo's books to try reading lore. Its lore comes after any real book's.
    public static let sample = Sourcebook(
        title: "Field Guide Sample Monster Core",
        downloadURL: URL(string: "https://github.com/scooper4711/field-guide/raw/main/Resources/Review/"
                         + "Field%20Guide%20Sample%20Monster%20Core.pdf"),
        supplies: [.deityLore, .creatureLore, .detailsLore])

    /// The new editions, which come first in `pathfinderBestiaries`.
    static let newEditions: Set<String> = ["Pathfinder Monster Core", "Pathfinder Monster Core 2"]

    public var books: [Sourcebook]
    /// The sources of each deity's lore, by entry ID.
    public var deities: [String: LoreSources]
    /// The bestiary creature whose lore each adventure creature shares, by entry ID.
    public var creatures: [String: CreatureSource]
    /// The volumes a compilation collects ("Pathfinder Season of Ghosts Hardcover Compilation" collects #196–199),
    /// by the compilation's title: a user with the volumes has its lore.
    public var volumes: [String: [String]]

    public init(books: [Sourcebook] = [], deities: [String: LoreSources] = [:],
                creatures: [String: CreatureSource] = [:], volumes: [String: [String]] = [:]) {
        self.books = books
        self.deities = deities
        self.creatures = creatures
        self.volumes = volumes
    }

    /// Reads a list, which a version before creature lore wrote without `creatures` and `volumes`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        books = try container.decode([Sourcebook].self, forKey: .books)
        deities = try container.decode([String: LoreSources].self, forKey: .deities)
        creatures = try container.decodeIfPresent([String: CreatureSource].self, forKey: .creatures) ?? [:]
        volumes = try container.decodeIfPresent([String: [String]].self, forKey: .volumes) ?? [:]
    }

    /// The books a creature Foundry credits to `credited` may take its lore from, best first: for a bestiary, the
    /// new editions, then the book itself, then the other bestiaries; for any other book, that book.
    public static func creatureBooks(for credited: String) -> [String] {
        guard pathfinderBestiaries.contains(credited) else { return [credited, sample.title] }
        let others = pathfinderBestiaries.filter { $0 != credited }
        return others.filter(newEditions.contains) + [credited] + others.filter { !newEditions.contains($0) }
            + [sample.title]
    }

    /// The list shipped with the app, with the sample sourcebook; only the sample when the list is missing.
    public static let bundled: SourcebookList = {
        let url = Bundle.module.url(forResource: "sourcebooks", withExtension: "json")
        var list = url.flatMap { try? JSONDecoder().decode(SourcebookList.self, from: Data(contentsOf: $0)) }
            ?? SourcebookList()
        list.books.append(sample)
        return list
    }()

    /// The books a creature Foundry credits to `credited` may take its lore from, best first: as
    /// `creatureBooks(for:)` says, with a compilation's volumes after the compilation.
    public func creatureBookTitles(for credited: String) -> [String] {
        let title = title(of: credited)
        return Self.creatureBooks(for: title).flatMap { book in
            book == title ? [book] + (volumes[book] ?? []) : [book]
        }
    }

    /// The title of the book Foundry credits as `credited`: Foundry credits some books under two titles, one of them
    /// listed as the other's alias.
    public func title(of credited: String) -> String {
        books.first { $0.title == credited }?.title ?? book(named: credited)?.title ?? credited
    }

    /// The book `name` (a file's or folder's name, or a copyright line) names, if any.
    public func book(named name: String) -> Sourcebook? {
        books.first { $0.isNamed(name) }
    }

    /// The deities whose stat lines or prose `book` supplies, by entry ID.
    public func deities(from book: Sourcebook) -> [String: LoreSources] {
        deities.filter { $0.value.books.contains(book.title) }
    }
}
