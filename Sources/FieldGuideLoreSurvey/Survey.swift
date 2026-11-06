import Foundation
import PDFKit
import SourcebookLore

/// Reads every book for deity lore and picks each deity's sources (`LoreSourceChooser`).
struct Survey {
    let deities: [FoundryDeity]
    let books: [LibraryBook]

    /// The books' titles as Foundry credits them where one matches ("Pathfinder #218: Titanbane" for Scrollkeeper's
    /// "Pathfinder Adventure Path #218: Titanbane (Myth-Speaker 3 of 3)"), else as the library names them.
    var titledBooks: [LibraryBook] {
        let credited = Set(deities.map(\.facts.credited)).filter { !$0.isEmpty }
        return books.map { book in
            guard !book.keepsTitle else { return book }
            var book = book
            let key = TextRepair.matchKey(book.title)
            let matches = credited.filter { key.contains(Self.distinctiveKey(of: $0)) }
            if let title = matches.max(by: { Self.distinctiveKey(of: $0).count < Self.distinctiveKey(of: $1).count }) {
                book.title = title
            }
            return book
        }
    }

    /// A title's match key without the game's name, which Paizo's and Foundry's titles place differently.
    static func distinctiveKey(of title: String) -> String {
        let key = TextRepair.matchKey(title)
        for prefix in ["pathfinder", "starfinder"] where key.hasPrefix(prefix) {
            return String(key.dropFirst(prefix.count))
        }
        return key
    }

    /// What each book gives each deity, by entry ID.
    func findings(log: (String) -> Void) -> [String: [LoreSourceChooser.Finding]] {
        var findings: [String: [LoreSourceChooser.Finding]] = [:]
        for book in titledBooks {
            guard let document = PDFDocument(url: book.pdf) else { continue }
            let system = book.isStarfinder ? "sf2e" : "pf2e"
            let pairs = deities.filter { $0.system == system }.map { ($0.facts.name, $0.id) }
            let ids = Dictionary(pairs) { first, _ in first }
            let names = Array(ids.keys)
            let tables = DeityTable(names: names).rows(in: document)
            let writeups = DeityWriteups(names: names).writeups(in: document)
            for (name, lines) in tables {
                guard let id = ids[name] else { continue }
                let lore = DeityLore(statLines: lines)
                findings[id, default: []].append(.init(book: book.title, lore: lore, isTable: true))
            }
            for (name, lore) in writeups {
                guard let id = ids[name] else { continue }
                findings[id, default: []].append(.init(book: book.title, lore: lore))
            }
            log("\(book.title): \(writeups.count) write-ups, \(tables.count) table rows")
        }
        return findings
    }
}
