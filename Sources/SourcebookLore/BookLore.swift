import ArtExtraction
import CryptoKit
import Foundation
import PDFKit

/// A book's deity and creature lore as read from the user's PDF, and where it came from: which file (its digest) of
/// which edition (its date), read by which version of the rules. A later sync between devices keeps the record from the
/// newer edition, then the newer reader, then the later import.
public struct BookLore: Codable, Equatable, Sendable {
    public var title: String
    /// The PDF, for reading it again; nil once it can't be found.
    public var location: FileReference?
    /// The PDF's SHA-256, in hexadecimal.
    public var sourceDigest: String
    /// When the PDF was last modified, from its own metadata: a reissue with errata has a later date.
    public var sourceDate: Date?
    public var readerVersion: Int
    public var importedAt: Date
    /// What the book gives each deity it supplies, by entry ID.
    public var deities: [String: DeityLore]
    /// What the book gives each creature it prints, by the match key of the creature's name
    /// (`CreatureLore.keys(for:)`): the editions of a bestiary are matched by name.
    public var creatures: [String: CreatureLore]
    /// What the book gives each ancestry and class it introduces, by the match key of its name.
    public var details: [String: DetailsLore]

    public init(title: String, location: FileReference?, sourceDigest: String, sourceDate: Date?,
                readerVersion: Int, importedAt: Date, deities: [String: DeityLore],
                creatures: [String: CreatureLore] = [:], details: [String: DetailsLore] = [:]) {
        self.title = title
        self.location = location
        self.sourceDigest = sourceDigest
        self.sourceDate = sourceDate
        self.readerVersion = readerVersion
        self.importedAt = importedAt
        self.deities = deities
        self.creatures = creatures
        self.details = details
    }

    /// Reads a record, which a version before creature lore wrote without `creatures` and `details`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decodeIfPresent(FileReference.self, forKey: .location)
        sourceDigest = try container.decode(String.self, forKey: .sourceDigest)
        sourceDate = try container.decodeIfPresent(Date.self, forKey: .sourceDate)
        readerVersion = try container.decode(Int.self, forKey: .readerVersion)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        deities = try container.decode([String: DeityLore].self, forKey: .deities)
        creatures = try container.decodeIfPresent([String: CreatureLore].self, forKey: .creatures) ?? [:]
        details = try container.decodeIfPresent([String: DetailsLore].self, forKey: .details) ?? [:]
    }
}

/// Reads a sourcebook's lore for the deities `sourcebooks.json` assigns it.
public struct BookReader: Sendable {
    /// Raised when the rules for reading books change, so books are read again. 2: creature lore; 3: ancestries'
    /// and classes' Details; 4: a sample per game, whose lore goes only to its own game's entries.
    public static let version = 4

    public let list: SourcebookList
    /// The deities, creatures, ancestries and classes, as the catalog names them.
    public let subjects: LoreSubjects

    public init(list: SourcebookList, subjects: LoreSubjects) {
        self.list = list
        self.subjects = subjects
    }

    /// Each deity's name by entry ID.
    private var names: [String: String] { subjects.deityNames }

    /// The book's lore, read from `document`, the PDF at `file`.
    public func read(_ book: Sourcebook, from document: PDFDocument, file: URL) throws -> BookLore {
        let deities = deityLore(of: book, from: document)
        let creatures = book.supplies.contains(.creatureLore) ? CreatureWriteups().writeups(in: document) : [:]
        let modified = document.documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        return BookLore(title: book.title, location: try? FileReference(file), sourceDigest: try Self.digest(of: file),
                        sourceDate: modified, readerVersion: Self.version, importedAt: Date(), deities: deities,
                        creatures: creatures, details: detailsLore(of: book, from: document))
    }

    /// The Details of the ancestries and classes Foundry credits to the book (to a sample, every one of its game it
    /// prints), by the match key of their names.
    private func detailsLore(of book: Sourcebook, from document: PDFDocument) -> [String: DetailsLore] {
        guard book.supplies.contains(.detailsLore) else { return [:] }
        let isSample = SourcebookList.isSample(book.title)
        let names = Set(subjects.details.filter { entry in
            isSample
                ? SourcebookList.sample(book.title, covers: entry.id)
                : list.title(of: entry.credited) == book.title
        }.map(\.name))
        guard !names.isEmpty else { return [:] }
        let writeups = DetailsWriteups(names: Array(names)).writeups(in: document)
        return Dictionary(writeups.map { (TextRepair.matchKey($0.key), $0.value) }) { first, _ in first }
    }

    /// The lore the book gives the deities `sourcebooks.json` assigns it; a sample's, every deity of its game it
    /// prints.
    private func deityLore(of book: Sourcebook, from document: PDFDocument) -> [String: DeityLore] {
        if SourcebookList.isSample(book.title) { return sampleDeityLore(of: book, from: document) }
        let sources = list.deities(from: book)
        guard !sources.isEmpty else { return [:] }
        let ids = ids(byName: sources.keys)
        var deities: [String: DeityLore] = [:]
        if sources.values.contains(where: { $0.stats == book.title }) {
            for (name, lines) in DeityTable(names: Array(ids.keys)).rows(in: document) {
                for id in ids[name, default: []] where sources[id]?.stats == book.title {
                    deities[id] = DeityLore(statLines: lines)
                }
            }
        }
        for (name, writeup) in DeityWriteups(names: Array(ids.keys)).writeups(in: document) {
            for id in ids[name, default: []] {
                guard let source = sources[id] else { continue }
                let lore = Self.lore(deities[id] ?? DeityLore(), adding: writeup, from: source, book: book.title)
                if !lore.isEmpty { deities[id] = lore }
            }
        }
        return deities
    }

    /// The entry IDs among `entryIDs` by each deity's name. Two games' deities may share a name, so a name can have
    /// more than one ID.
    private func ids(byName entryIDs: some Sequence<String>) -> [String: [String]] {
        entryIDs.reduce(into: [:]) { ids, id in
            if let name = names[id] { ids[name, default: []].append(id) }
        }
    }

    /// `lore` with the parts of `writeup` that `source` assigns to `book`.
    private static func lore(_ lore: DeityLore, adding writeup: DeityLore, from source: LoreSources,
                             book: String) -> DeityLore {
        var lore = lore
        if source.stats == book, lore.statLines.isEmpty { lore.statLines = writeup.statLines }
        if source.prose == book { lore.paragraphs = writeup.paragraphs }
        if source.intercession == book { lore.intercession = writeup.intercession }
        return lore
    }

    /// The sample's deity lore, given to every deity of the sample's game with the name it prints.
    private func sampleDeityLore(of sample: Sourcebook, from document: PDFDocument) -> [String: DeityLore] {
        let ids = ids(byName: names.keys.filter { SourcebookList.sample(sample.title, covers: $0) })
        let writeups = DeityWriteups(names: Array(ids.keys)).writeups(in: document)
        return writeups.reduce(into: [:]) { deities, writeup in
            for id in ids[writeup.key, default: []] { deities[id] = writeup.value }
        }
    }

    /// The file's SHA-256, in hexadecimal, read a megabyte at a time.
    static func digest(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
