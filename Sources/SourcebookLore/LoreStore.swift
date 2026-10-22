import ArtExtraction
import Foundation
import PDFKit

/// The deity lore read from the user's sourcebooks, kept in `lore.json` in the store's folder, with the folders
/// whose new PDFs are read (Scrollkeeper's downloads).
public actor LoreStore {
    struct Stored: Codable {
        var books: [String: BookLore] = [:]
        var watchedFolders: [FileReference] = []
    }

    private let file: URL
    private let list: SourcebookList
    private var stored: Stored

    public init(folder: URL, list: SourcebookList = .bundled) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("lore.json")
        self.list = list
        stored = (try? JSONDecoder().decode(Stored.self, from: Data(contentsOf: file))) ?? Stored()
    }

    /// The books read, by title.
    public var books: [String: BookLore] { stored.books }

    public var watchedFolders: [String] { stored.watchedFolders.map(\.path) }

    /// What the user's books give the deity: its stat lines from one book and its prose from another, as
    /// `sourcebooks.json` assigns them; nil when none of its books has been read.
    public func lore(of entryID: String) -> DeityLore? {
        guard let sources = list.deities[entryID] else { return nil }
        let stats = sources.stats.flatMap { stored.books[$0]?.deities[entryID]?.statLines } ?? []
        let prose = sources.prose.flatMap { stored.books[$0]?.deities[entryID]?.paragraphs } ?? []
        let intercession = sources.intercession.flatMap { stored.books[$0]?.deities[entryID]?.intercession }
        let lore = DeityLore(statLines: stats, paragraphs: prose, intercession: intercession,
                             intercessionNote: intercession == nil ? nil : legacyNote(for: sources.intercession))
        return lore.isEmpty ? nil : lore
    }

    /// The note an intercession from a book written for the rules before the remaster carries.
    private func legacyNote(for title: String?) -> String? {
        guard let book = list.books.first(where: { $0.title == title }), book.isLegacy == true else { return nil }
        return "From \(book.title), written for the rules before the remaster."
    }

    /// Reads the sourcebooks among `files`, which the user chose; returns the titles read.
    public func addFiles(_ files: [URL], names: [String: String]) throws -> [String] {
        let read = files.compactMap { file in
            withAccess(to: file) { readIfNew(file, names: names, openingToIdentify: true) }
        }
        try save()
        return read
    }

    /// Watches `folder` and reads the sourcebooks in it; returns the titles read.
    public func importFolder(_ folder: URL, names: [String: String]) throws -> [String] {
        let reference = try FileReference(folder)
        if !stored.watchedFolders.contains(where: { $0.path == reference.path }) {
            stored.watchedFolders.append(reference)
        }
        let read = reference.withAccess { readFolder($0, names: names) } ?? []
        try save()
        return read
    }

    /// Reads the sourcebooks that have appeared in the watched folders, or changed, or that an older reader read.
    public func addNewFiles(names: [String: String]) throws -> [String] {
        let read = stored.watchedFolders.flatMap { $0.withAccess { readFolder($0, names: names) } ?? [] }
        try save()
        return read
    }

    public func unwatch(_ path: String) throws {
        stored.watchedFolders.removeAll { $0.path == path }
        try save()
    }

    private func readFolder(_ folder: URL, names: [String: String]) -> [String] {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        let pdfs = (enumerator?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension.lowercased() == "pdf" }
        return pdfs.compactMap { readIfNew($0, names: names, openingToIdentify: false) }
    }

    /// Reads the PDF when it is a sourcebook whose lore isn't stored yet from this file and reader; returns its title.
    private func readIfNew(_ file: URL, names: [String: String], openingToIdentify: Bool) -> String? {
        let identifier = SourcebookIdentifier(list: list)
        let named = identifier.book(namedBy: file)
        guard named != nil || openingToIdentify, let document = PDFDocument(url: file),
              let book = named ?? identifier.book(of: file, document: document) else { return nil }
        if let existing = stored.books[book.title], existing.readerVersion == BookReader.version,
           let digest = try? BookReader.digest(of: file), digest == existing.sourceDigest { return nil }
        guard let lore = try? BookReader(list: list, names: names).read(book, from: document, file: file)
        else { return nil }
        stored.books[book.title] = lore
        return book.title
    }

    private func withAccess<Result>(to file: URL, _ body: () -> Result) -> Result {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }
        return body()
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(stored).write(to: file, options: .atomic)
    }
}
