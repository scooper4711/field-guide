import Foundation
import SourcebookLore

/// A book PDF found in the library folder, with the name and SKU Scrollkeeper knows it by.
struct LibraryBook {
    var title: String
    var sku: String?
    var folderName: String
    var pdf: URL

    var isStarfinder: Bool { title.hasPrefix("Starfinder") }
}

/// Finds the second-edition books in a library folder laid out as Scrollkeeper downloads them: a folder per
/// product, holding a single-file PDF or a file per chapter.
enum LibraryBooks {
    /// Product lines and accessories that hold no deity write-ups: first-edition lines, maps, pawns and cards.
    static let skipped = [
        "Campaign Setting", "Chronicles", "Companion", "Roleplaying Game", "Pawn", "Flip-Mat", "Map", "Cards", "Deck",
        "Token", "Poster", "Scenario", "Quest", "Card Guild", "Battlecry", "Bounty", "Interactive"
    ]

    static func find(in folder: URL, scrollkeeperCatalog: URL?) throws -> [LibraryBook] {
        let products = try scrollkeeperCatalog.map(ScrollkeeperProducts.read(catalog:)) ?? [:]
        let folders = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        return folders.filter { name in !skipped.contains { name.lastPathComponent.contains($0) } }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { productFolder in
                guard let pdf = singleFilePDF(in: productFolder) else { return nil }
                let product = products[TextRepair.matchKey(productFolder.lastPathComponent)]
                return LibraryBook(title: product?.title ?? productFolder.lastPathComponent, sku: product?.sku,
                                   folderName: productFolder.lastPathComponent, pdf: pdf)
            }
    }

    /// The product's whole-book PDF: the largest PDF that isn't one chapter of a file-per-chapter download.
    static func singleFilePDF(in folder: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        else { return nil }
        let pdfs = enumerator.compactMap { $0 as? URL }.filter {
            $0.pathExtension.lowercased() == "pdf" && !$0.path.localizedCaseInsensitiveContains("chapter")
        }
        return pdfs.max { size(of: $0) < size(of: $1) }
    }

    private static func size(of file: URL) -> Int {
        (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}

/// The titles and SKUs of the products in Scrollkeeper's `catalog.json`, by the match key of the folder name
/// Scrollkeeper downloads them to.
enum ScrollkeeperProducts {
    static func read(catalog: URL) throws -> [String: (title: String, sku: String)] {
        guard let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [[String: Any]]
        else { return [:] }
        var products: [String: (title: String, sku: String)] = [:]
        for entry in entries {
            let name = (entry["productName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? entry["displayName"] as? String ?? ""
            let title = name.replacingOccurrences(of: #"\s*PDF.*$"#, with: "", options: .regularExpression)
            let sku = (entry["providedBySKU"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (entry["productSKUs"] as? [String])?.first ?? ""
            products[TextRepair.matchKey(title)] = (title, sku)
        }
        return products
    }
}
