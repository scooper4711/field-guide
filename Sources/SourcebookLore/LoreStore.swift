import ArtExtraction
import Foundation
import PDFKit

/// The deity and creature lore read from the user's sourcebooks, kept in `lore.json` in the store's folder, with the
/// folders whose new PDFs are read (Scrollkeeper's downloads).
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
        guard let sources = list.deities[entryID] else { return sampleLore(of: entryID) }
        let stats = sources.stats.flatMap { stored.books[$0]?.deities[entryID]?.statLines } ?? []
        let prose = sources.prose.flatMap { stored.books[$0]?.deities[entryID]?.paragraphs } ?? []
        let intercession = sources.intercession.flatMap { stored.books[$0]?.deities[entryID]?.intercession }
        let lore = DeityLore(statLines: stats, paragraphs: prose, intercession: intercession,
                             intercessionNote: intercession == nil ? nil : legacyNote(for: sources.intercession))
        return lore.isEmpty ? sampleLore(of: entryID) : lore
    }

    /// The deity's lore from the sample sourcebook, which stands in for books the user hasn't read.
    private func sampleLore(of entryID: String) -> DeityLore? {
        stored.books[SourcebookList.sample.title]?.deities[entryID]
    }

    /// What the user's books give the creature: for an adventure's creature whose lore is a bestiary creature's
    /// (`SourcebookList.creatures`), that creature's; else from the first of its books
    /// (`SourcebookList.creatureBooks(for:)`) that has been read and prints it, so Monster Core's lore is used over a
    /// Bestiary's whichever was read first; nil when none has.
    public func lore(of creature: EntryReference) -> CreatureLore? {
        if let source = list.creatures[creature.id],
           let lore = printedLore(of: EntryReference(id: creature.id, name: source.name, credited: source.book)) {
            return lore
        }
        return printedLore(of: creature)
    }

    /// What the user's books give the ancestry or class for its Details: from the book Foundry credits, else the
    /// sample; nil when neither has been read.
    public func details(of entry: EntryReference) -> DetailsLore? {
        let key = TextRepair.matchKey(entry.name)
        return [list.title(of: entry.credited), SourcebookList.sample.title].lazy
            .compactMap { self.stored.books[$0]?.details[key] }
            .first
    }

    private func printedLore(of creature: EntryReference) -> CreatureLore? {
        let keys = CreatureLore.keys(for: creature.name)
        for title in list.creatureBookTitles(for: creature.credited) {
            guard let creatures = stored.books[title]?.creatures else { continue }
            if let lore = keys.lazy.compactMap({ creatures[$0] }).first { return lore }
        }
        return nil
    }

    /// The note an intercession from a book written for the rules before the remaster carries.
    private func legacyNote(for title: String?) -> String? {
        guard let book = list.books.first(where: { $0.title == title }), book.isLegacy == true else { return nil }
        return "From \(book.title), written for the rules before the remaster."
    }

    /// Reads the sourcebooks among `files`, which the user chose; returns the titles read.
    public func addFiles(_ files: [URL], subjects: LoreSubjects) throws -> [String] {
        let read = files.compactMap { file in
            withAccess(to: file) { readIfNew(file, subjects: subjects, openingToIdentify: true) }
        }
        try save()
        return read
    }

    /// Watches `folder` and reads the sourcebooks in it; returns the titles read.
    public func importFolder(_ folder: URL, subjects: LoreSubjects) throws -> [String] {
        let reference = try FileReference(folder)
        if !stored.watchedFolders.contains(where: { $0.path == reference.path }) {
            stored.watchedFolders.append(reference)
        }
        let read = reference.withAccess { readFolder($0, subjects: subjects) } ?? []
        try save()
        return read
    }

    /// Reads the sourcebooks that have appeared in the watched folders, or changed, or that an older reader read.
    public func addNewFiles(subjects: LoreSubjects) throws -> [String] {
        let read = stored.watchedFolders.flatMap { $0.withAccess { readFolder($0, subjects: subjects) } ?? [] }
        try save()
        return read
    }

    public func unwatch(_ path: String) throws {
        stored.watchedFolders.removeAll { $0.path == path }
        try save()
    }

    private func readFolder(_ folder: URL, subjects: LoreSubjects) -> [String] {
        Self.sourcebookFiles(in: folder, list: list).compactMap {
            readIfNew($0, subjects: subjects, openingToIdentify: false)
        }
    }

    /// The PDFs in `folder` that are sourcebooks, by their names: for each book the largest, its single-file edition
    /// rather than one of the chapters of a file-per-chapter download, which name the book too.
    public static func sourcebookFiles(in folder: URL, list: SourcebookList) -> [URL] {
        let identifier = SourcebookIdentifier(list: list)
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        let pdfs = (enumerator?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension.lowercased() == "pdf" }
        let named = pdfs.compactMap { file in identifier.book(namedBy: file).map { ($0.title, file) } }
        let byBook = Dictionary(grouping: named, by: \.0)
        return byBook.values.compactMap { files in files.map(\.1).max { size(of: $0) < size(of: $1) } }
            .sorted { $0.path < $1.path }
    }

    private static func size(of file: URL) -> Int {
        (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    /// Reads the PDF when it is a sourcebook whose lore isn't stored yet from this file and reader; returns its title.
    private func readIfNew(_ file: URL, subjects: LoreSubjects, openingToIdentify: Bool) -> String? {
        let identifier = SourcebookIdentifier(list: list)
        let named = identifier.book(namedBy: file)
        guard named != nil || openingToIdentify, let document = PDFDocument(url: file),
              let book = named ?? identifier.book(of: file, document: document) else { return nil }
        if let existing = stored.books[book.title] {
            // A newer app's reading, from another device, is better than this app's.
            if existing.readerVersion > BookReader.version { return nil }
            if existing.readerVersion == BookReader.version, let digest = try? BookReader.digest(of: file),
               digest == existing.sourceDigest { return nil }
        }
        guard let lore = try? BookReader(list: list, subjects: subjects).read(book, from: document, file: file)
        else { return nil }
        stored.books[book.title] = lore
        return book.title
    }

    private func withAccess<Result>(to file: URL, _ body: () -> Result) -> Result {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }
        return body()
    }

    /// Keeps `record`, from another device, when it is better than the stored one; returns its title when kept.
    func adopt(_ record: BookLore) -> String? {
        let existing = stored.books[record.title]
        if let existing, !record.isPreferred(over: existing) { return nil }
        var adopted = record
        adopted.location = existing?.sourceDigest == record.sourceDigest ? existing?.location : nil
        stored.books[record.title] = adopted
        return record.title
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(stored).write(to: file, options: .atomic)
    }
}
