import Foundation
import SourcebookLore

/// The books whose creatures' lore the import leaves out, as sourcebooks the app reads it from: each with the SKU and
/// product name Scrollkeeper knows it by, when its catalog lists the product.
enum CreatureBooks {
    /// A product in Scrollkeeper's `catalog.json`.
    struct Product {
        var name: String
        var sku: String
    }

    /// Accessories that share a book's name but hold no stat blocks.
    static let accessories = #"(?i)pawn|battle cards|flip-?mat|map|token|deck|poster|interactive|audio|cards|pregen"#
    /// Words a product's name may start with that Foundry's title for the book leaves out.
    static let leadingWords = ["adventurepath", "adventure", "deluxeadventure"]

    /// `list` with a sourcebook for each book Foundry credits creatures with lore to: a book already listed for its
    /// deities also supplies creature lore.
    static func merge(into list: SourcebookList, creatures: [FoundryCreature], products: [Product]) -> SourcebookList {
        var list = list
        for title in Set(creatures.map(\.credited)).filter({ !$0.isEmpty }).sorted() {
            if let index = list.books.firstIndex(where: { $0.title == title }) {
                if !list.books[index].supplies.contains(.creatureLore) {
                    list.books[index].supplies.append(.creatureLore)
                }
                continue
            }
            let product = self.product(for: title, in: products)
            let aliases = [product?.name, product.map { scrollkeeperFolder(of: $0.name) }].compactMap { $0 }
            list.books.append(Sourcebook(title: title, sku: product?.sku,
                                         aliases: Array(Set(aliases)).filter { $0 != title }.sorted(),
                                         supplies: [.creatureLore]))
        }
        list.books.sort { $0.title < $1.title }
        return list
    }

    /// The product Foundry's `title` names: the one whose name, without "Adventure Path" or the game's name,
    /// starts with the title's ("Pathfinder #192: Worst of All Possible Worlds" names "Pathfinder Adventure Path
    /// #192: Worst of All Possible Worlds (Stolen Fate 3 of 3)"). Nil unless exactly one product does.
    static func product(for title: String, in products: [Product]) -> Product? {
        let key = Survey.distinctiveKey(of: title)
        guard !key.isEmpty else { return nil }
        let matches = products.filter { product in
            guard product.name.range(of: accessories, options: .regularExpression) == nil else { return false }
            return strippedKey(of: product.name).hasPrefix(key) || Survey.distinctiveKey(of: product.name) == key
        }
        let bySKU = Dictionary(grouping: matches, by: \.sku)
        if bySKU.count == 1 { return bySKU.values.first?.first }
        // Of several (a book and its deluxe edition, say), the one named exactly as the book.
        let exact = matches.filter { strippedKey(of: $0.name) == key }
        return Set(exact.map(\.sku)).count == 1 ? exact.first : nil
    }

    /// The name's match key without the game's name and the leading words Foundry's titles leave out.
    static func strippedKey(of name: String) -> String {
        var key = Survey.distinctiveKey(of: name)
        for word in leadingWords where key.hasPrefix(word) {
            key = String(key.dropFirst(word.count))
            break
        }
        return key
    }

    /// The folder Scrollkeeper downloads a product to: its name with colons as dashes.
    static func scrollkeeperFolder(of name: String) -> String {
        name.replacingOccurrences(of: ":", with: "-")
    }

    /// The products in Scrollkeeper's `catalog.json`, named without "PDF" and the like.
    static func products(inCatalog catalog: URL) throws -> [Product] {
        guard let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [[String: Any]]
        else { return [] }
        return entries.compactMap { entry in
            let name = (entry["productName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? entry["displayName"] as? String ?? ""
            let sku = (entry["providedBySKU"] as? String).flatMap { $0.isEmpty || $0 == "undefined" ? nil : $0 }
                ?? (entry["productSKUs"] as? [String])?.first ?? ""
            let title = name.replacingOccurrences(of: #"\s*(PDF|Single File|File[- ]Per[- ]Chapter).*$"#, with: "",
                                                  options: [.regularExpression, .caseInsensitive])
            return title.isEmpty || sku.isEmpty ? nil : Product(name: title, sku: sku)
        }
    }
}
