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

    public init(title: String, location: FileReference?, sourceDigest: String, sourceDate: Date?,
                readerVersion: Int, importedAt: Date, deities: [String: DeityLore],
                creatures: [String: CreatureLore] = [:]) {
        self.title = title
        self.location = location
        self.sourceDigest = sourceDigest
        self.sourceDate = sourceDate
        self.readerVersion = readerVersion
        self.importedAt = importedAt
        self.deities = deities
        self.creatures = creatures
    }

    /// Reads a record, which a version before creature lore wrote without `creatures`.
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
    }
}

/// Reads a sourcebook's lore for the deities `sourcebooks.json` assigns it.
public struct BookReader: Sendable {
    /// Raised when the rules for reading books change, so books are read again. 2: creature lore.
    public static let version = 2

    public let list: SourcebookList
    /// Each deity's name by entry ID, as the catalog spells it.
    public let names: [String: String]

    public init(list: SourcebookList, names: [String: String]) {
        self.list = list
        self.names = names
    }

    /// The book's lore, read from `document`, the PDF at `file`.
    public func read(_ book: Sourcebook, from document: PDFDocument, file: URL) throws -> BookLore {
        let deities = deityLore(of: book, from: document)
        let creatures = book.supplies.contains(.creatureLore) ? CreatureWriteups().writeups(in: document) : [:]
        let modified = document.documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        return BookLore(title: book.title, location: try? FileReference(file), sourceDigest: try Self.digest(of: file),
                        sourceDate: modified, readerVersion: Self.version, importedAt: Date(), deities: deities,
                        creatures: creatures)
    }

    /// The lore the book gives the deities `sourcebooks.json` assigns it; the sample's, every deity it prints.
    private func deityLore(of book: Sourcebook, from document: PDFDocument) -> [String: DeityLore] {
        if book.title == SourcebookList.sample.title { return sampleDeityLore(from: document) }
        let sources = list.deities(from: book)
        guard !sources.isEmpty else { return [:] }
        let ids = Dictionary(sources.keys.compactMap { id in names[id].map { ($0, id) } }) { first, _ in first }
        var deities: [String: DeityLore] = [:]
        if sources.values.contains(where: { $0.stats == book.title }) {
            for (name, lines) in DeityTable(names: Array(ids.keys)).rows(in: document) {
                if let id = ids[name], sources[id]?.stats == book.title { deities[id] = DeityLore(statLines: lines) }
            }
        }
        for (name, writeup) in DeityWriteups(names: Array(ids.keys)).writeups(in: document) {
            guard let id = ids[name], let source = sources[id] else { continue }
            let lore = Self.lore(deities[id] ?? DeityLore(), adding: writeup, from: source, book: book.title)
            if !lore.isEmpty { deities[id] = lore }
        }
        return deities
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

    private func sampleDeityLore(from document: PDFDocument) -> [String: DeityLore] {
        let ids = Dictionary(names.map { ($1, $0) }) { first, _ in first }
        let writeups = DeityWriteups(names: Array(ids.keys)).writeups(in: document)
        return Dictionary(writeups.compactMap { name, lore in ids[name].map { ($0, lore) } }) { first, _ in first }
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
