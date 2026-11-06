import Foundation

/// Finds the product in Scrollkeeper's catalog that Foundry's title for a book names. Paizo's product names and
/// Foundry's titles word the same book differently: "Pathfinder Adventure Path: Hellbreakers" is "PZO15222E
/// Pathfinder Adventure Path: Hellbreakers Single File"; "Pathfinder Society Quest #15: In the Footsteps of Horror" is
/// "Pathfinder Quest (Series 2) #15: In the Footsteps of Horror"; "Pathfinder Lost Omens The Grand Bazaar" is
/// "Pathfinder Lost Omens Grand Bazaar". A numbered book (a scenario, a quest, an adventure path volume) matches a
/// product of its number; any book matches the product sharing most of its words.
struct ProductMatcher {
    /// A name reduced to what tells books apart.
    struct Key: Equatable {
        /// The book's number, such as "5-09" or "192"; empty for none.
        var number: String
        var words: Set<String>
    }

    /// Words that name a product line or an edition rather than the book.
    static let ignoredWords: Set<String> = [
        "pathfinder", "starfinder", "adventure", "adventures", "path", "hardcover", "compilation", "remastered", "the",
        "a", "an", "of", "society", "scenario", "special", "quest", "series", "intro", "to", "pdf", "single", "file",
        "per", "chapter", "download", "deluxe", "game", "night", "module", "and"
    ]
    /// The share of words two names must have in common; less for products of the book's number, where it only
    /// picks among them.
    static let threshold = 0.6
    static let numberedThreshold = 0.4

    let products: [LoreBooks.Product]

    /// The product `title`, a book of `game` ("Pathfinder" or "Starfinder"), names, or nil when none does
    /// unambiguously. A product naming the other game never matches, even when the title names none ("Invasion's
    /// Edge Player's Guide" is Starfinder's, not Pathfinder's "Ironfang Invasion Player's Guide").
    func product(for title: String, game: String) -> LoreBooks.Product? {
        let key = Self.key(of: title)
        let candidates = products.filter { product in
            product.name.range(of: LoreBooks.accessories, options: .regularExpression) == nil
                && Survey.isSameGame(title, product.name) && Survey.isSameGame(game, product.name)
        }
        let numbered = key.number.isEmpty ? [] : candidates.filter { Self.key(of: $0.name).number == key.number }
        return best(numbered, for: key, threshold: Self.numberedThreshold)
            ?? best(candidates, for: key, threshold: Self.threshold)
    }

    /// The product sharing most words with `key`, at least `threshold` of them; nil when different products tie.
    /// Entries for one product's editions (PZO2103E and the special edition's PZO2103SEE) count as one, under the
    /// SKU Scrollkeeper knows a regular edition's entry by.
    private func best(_ products: [LoreBooks.Product], for key: Key, threshold: Double) -> LoreBooks.Product? {
        let scored = products.map { (product: $0, score: Self.similarity(Self.key(of: $0.name).words, key.words)) }
            .filter { $0.score >= threshold }
        guard let top = scored.map(\.score).max() else { return nil }
        let winners = scored.filter { $0.score == top }.map(\.product)
        let shared = winners.dropFirst().reduce(Set(winners[0].skus)) { $0.intersection($1.skus) }
        guard !shared.isEmpty, let sku = Set(winners.map(\.sku)).min(by: Self.isRegularEdition)
        else { return nil }
        return LoreBooks.Product(name: winners[0].name, sku: sku, skus: winners[0].skus)
    }

    /// Orders a regular edition's SKU ("PZO2103E") before others ("PZO2103SEE", "PZO12001-SEE").
    static func isRegularEdition(_ first: String, _ second: String) -> Bool {
        let regular = { (sku: String) in sku.hasSuffix("E") && !sku.hasSuffix("SEE") }
        return regular(first) != regular(second) ? regular(first) : first < second
    }

    static func key(of name: String) -> Key {
        var text = name.lowercased().replacingOccurrences(of: #"[–—]"#, with: "-", options: .regularExpression)
        text = text.replacingOccurrences(of: #"^pzo\w+\s*(-\s*)?"#, with: "", options: .regularExpression)
        let number = text.range(of: #"#\s*\d+(-\d+)?"#, options: .regularExpression)
            .map { String(text[$0]).filter { $0.isNumber || $0 == "-" } } ?? ""
        if let range = text.range(of: #"#\s*\d+(-\d+)?"#, options: .regularExpression) { text.removeSubrange(range) }
        // One-letter words are what apostrophes leave ("Invasion's" reads as "invasion" and "s").
        let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .filter { $0.count > 1 && !ignoredWords.contains($0) }
            .map { word in word.hasSuffix("s") && word.count > 3 ? String(word.dropLast()) : word }
        return Key(number: number, words: Set(words))
    }

    static func similarity(_ first: Set<String>, _ second: Set<String>) -> Double {
        guard !first.isEmpty || !second.isEmpty else { return 0 }
        return Double(first.intersection(second).count) / Double(first.union(second).count)
    }
}
