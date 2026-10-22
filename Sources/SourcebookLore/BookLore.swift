import ArtExtraction
import CryptoKit
import Foundation
import PDFKit

/// A book's deity lore as read from the user's PDF, and where it came from: which file (its digest) of which
/// edition (its date), read by which version of the rules. A later sync between devices keeps the record from the
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
}

/// Reads a sourcebook's lore for the deities `sourcebooks.json` assigns it.
public struct BookReader: Sendable {
    /// Raised when the rules for reading books change, so books are read again.
    public static let version = 1

    public let list: SourcebookList
    /// Each deity's name by entry ID, as the catalog spells it.
    public let names: [String: String]

    public init(list: SourcebookList, names: [String: String]) {
        self.list = list
        self.names = names
    }

    /// The book's lore, read from `document`, the PDF at `file`.
    public func read(_ book: Sourcebook, from document: PDFDocument, file: URL) throws -> BookLore {
        let sources = list.deities(from: book)
        let ids = Dictionary(sources.keys.compactMap { id in names[id].map { ($0, id) } }) { first, _ in first }
        var deities: [String: DeityLore] = [:]
        if sources.values.contains(where: { $0.stats == book.title }) {
            for (name, lines) in DeityTable(names: Array(ids.keys)).rows(in: document) {
                if let id = ids[name], sources[id]?.stats == book.title { deities[id] = DeityLore(statLines: lines) }
            }
        }
        for (name, writeup) in DeityWriteups(names: Array(ids.keys)).writeups(in: document) {
            guard let id = ids[name], let source = sources[id] else { continue }
            var lore = deities[id] ?? DeityLore()
            if source.stats == book.title, lore.statLines.isEmpty { lore.statLines = writeup.statLines }
            if source.prose == book.title { lore.paragraphs = writeup.paragraphs }
            if !lore.isEmpty { deities[id] = lore }
        }
        let modified = document.documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date
        return BookLore(title: book.title, location: try? FileReference(file), sourceDigest: try Self.digest(of: file),
                        sourceDate: modified, readerVersion: Self.version, importedAt: Date(), deities: deities)
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
