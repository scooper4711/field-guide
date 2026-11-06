import Foundation
import SourcebookLore

/// The books whose creatures' or ancestries' and classes' lore the import leaves out, as sourcebooks the app reads it
/// from: each with the SKU and product name Scrollkeeper knows it by, when its catalog lists the product.
enum LoreBooks {
    /// Scrollkeeper's products, and the game ("Pathfinder", "Starfinder") of each book Foundry credits, by title.
    struct Catalog {
        var products: [Product]
        var games: [String: String]
    }

    /// A product in Scrollkeeper's `catalog.json`.
    struct Product {
        var name: String
        /// The SKU Scrollkeeper knows the product by.
        var sku: String
        /// Every SKU the catalog lists for it, its editions' too.
        var skus: [String]
    }

    /// Accessories that share a book's name but hold no stat blocks.
    static let accessories = #"(?i)pawn|battle cards|flip-?mat|map|token|deck|poster|interactive|audio|cards|pregen"#

    /// `list` with the creature and Details books Foundry credits in `repository`, and the bestiary creatures
    /// adventures' creatures share lore with.
    static func adding(to list: SourcebookList, repository: URL, catalog: URL) throws -> SourcebookList {
        let creatures = try FoundryCreatures.read(repository: repository)
        let details = try FoundryDetailsPages.read(repository: repository)
        let products = try self.products(inCatalog: catalog)
        let systems = creatures.map { ($0.credited, $0.system) } + details.map { ($0.credited, $0.system) }
        let games = Dictionary(systems) { first, _ in first }.mapValues { $0 == "sf2e" ? "Starfinder" : "Pathfinder" }
        let catalog = Catalog(products: products, games: games)
        var list = merge(into: list, titles: Set(creatures.map(\.credited)), supply: .creatureLore, catalog: catalog)
        list = merge(into: list, titles: Set(details.map(\.credited)), supply: .detailsLore, catalog: catalog)
        list.creatures = CreatureLoreMap.sources(of: creatures)
        for title in Set(creatures.map(\.credited)) where title.localizedCaseInsensitiveContains("compilation") {
            list = addingVolumes(of: title, to: list, products: products)
        }
        return list
    }

    /// `list` with the volumes the compilation `title` collects: the products named "(<its name> n of m)", each
    /// listed as a book supplying creature lore.
    static func addingVolumes(of title: String, to list: SourcebookList, products: [Product]) -> SourcebookList {
        let name = ProductMatcher.key(of: title).words
        let volumes = products.filter { product in
            guard let range = product.name.range(of: #"\(([^()]+) \d+ of \d+\)"#, options: .regularExpression)
            else { return false }
            let series = product.name[range].replacingOccurrences(of: #"\s*\d+ of \d+\)|\("#, with: "",
                                                                  options: .regularExpression)
            return ProductMatcher.key(of: series).words == name
        }
        let bySKU = Dictionary(volumes.map { ($0.sku, $0) }) { first, _ in first }
        guard bySKU.count > 1 else { return list }
        var list = list
        let titles = bySKU.values.sorted { $0.name < $1.name }.map { volume in
            if let book = list.books.first(where: { $0.sku == volume.sku }) { return book.title }
            list.books.append(Sourcebook(title: volume.name, sku: volume.sku,
                                         aliases: [scrollkeeperFolder(of: volume.name)], supplies: [.creatureLore]))
            return volume.name
        }
        list.volumes[title] = titles
        list.books.sort { $0.title < $1.title }
        return list
    }

    /// `list` with a sourcebook supplying `supply` for each of `titles`: a book already listed supplies it too. Each
    /// book gets the SKU and names (product and download folder) Scrollkeeper knows it by, when it lacks them.
    static func merge(into list: SourcebookList, titles: Set<String>, supply: Sourcebook.Supply,
                      catalog: Catalog) -> SourcebookList {
        var list = list
        let matcher = ProductMatcher(products: catalog.products)
        for title in titles.filter({ !$0.isEmpty }).sorted() {
            let index = list.books.firstIndex { $0.title == title } ?? {
                list.books.append(Sourcebook(title: title, supplies: []))
                return list.books.count - 1
            }()
            if !list.books[index].supplies.contains(supply) { list.books[index].supplies.append(supply) }
            guard let product = matcher.product(for: title, game: catalog.games[title] ?? "") else { continue }
            // Foundry credits some books under two titles ("Pathfinder #217: Death Sails a Wine-Dark Sea" and
            // "Pathfinder Adventure Path #217: Death Sails a Wine-Dark Sea (Myth-Speaker 2 of 3)"): one product is
            // one book, the other title one of its names.
            if let other = list.books.indices.first(where: { $0 != index && list.books[$0].sku == product.sku }) {
                fold(index, into: other, of: &list)
                continue
            }
            list.books[index].sku = list.books[index].sku ?? product.sku
            let names = [product.name, scrollkeeperFolder(of: product.name)] + list.books[index].aliases
            list.books[index].aliases = Array(Set(names)).filter { $0 != title }.sorted()
        }
        list.books.sort { $0.title < $1.title }
        return list
    }

    /// Makes the book at `index` a name of the book at `other`: its title and names become the other's aliases and
    /// its supplies the other's too.
    private static func fold(_ index: Int, into other: Int, of list: inout SourcebookList) {
        let book = list.books[index]
        list.books[other].aliases = Array(Set(list.books[other].aliases + [book.title] + book.aliases))
            .filter { $0 != list.books[other].title }.sorted()
        for supply in book.supplies where !list.books[other].supplies.contains(supply) {
            list.books[other].supplies.append(supply)
        }
        list.books.remove(at: index)
    }

    /// The folder Scrollkeeper downloads a product to: its name with colons as dashes.
    static func scrollkeeperFolder(of name: String) -> String {
        name.replacingOccurrences(of: ":", with: "-")
    }

    /// The products in Scrollkeeper's `catalog.json`, named without "PDF" and the like: an entry under both its
    /// product name and its display name, since the catalog cuts some names short ("Demonic Afterpa").
    static func products(inCatalog catalog: URL) throws -> [Product] {
        guard let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [[String: Any]]
        else { return [] }
        return entries.flatMap { entry -> [Product] in
            let provided = (entry["providedBySKU"] as? String).flatMap { $0.isEmpty || $0 == "undefined" ? nil : $0 }
            let skus = ([provided] + ((entry["productSKUs"] as? [String]) ?? []).map { $0 })
                .compactMap { $0 }.filter { $0 != "undefined" }
            guard let sku = skus.first else { return [] }
            let names = [entry["productName"] as? String, entry["displayName"] as? String].compactMap { $0 }
            return Set(names.map(Self.title(of:))).filter { !$0.isEmpty }.map {
                Product(name: $0, sku: sku, skus: Array(Set(skus)))
            }
        }
    }

    /// A catalog name without "PDF", "Single File", "File per Chapter" and what follows.
    static func title(of name: String) -> String {
        name.replacingOccurrences(of: #"\s*(PDF|Single File|File[- ]Per[- ]Chapter).*$"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
    }
}
