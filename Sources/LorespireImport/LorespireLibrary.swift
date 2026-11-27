import Foundation

/// A page of an Organized Play guide, as an entry: one page of the original wiki.
public struct LorespireEntry: Sendable, Equatable {
    /// `lorespire.<system>.<wiki page>`, such as `lorespire.pf2e.popguide._.Boons`.
    public let id: String
    public let name: String
    /// The part of the guide: Introduction, Core Guide, …, or Venture-Officer Handbook.
    public let part: String
    /// The entry's place among the system's guide pages, from 0.
    public let order: Int
    /// The page's body, without its heading.
    public let html: String
    /// The page on Lorespire.
    public let source: URL
}

/// A download made by ``LorespireDownloader``, read as entries.
public struct LorespireLibrary: Sendable {
    public let folder: URL
    let documents: [LorespireDocument]

    public init(folder: URL, documents: [LorespireDocument] = Lorespire.documents) {
        self.folder = folder
        self.documents = documents
    }

    /// The downloaded images and attachments, which the entries show from `images/lorespire/`.
    public var filesFolder: URL { folder.appendingPathComponent("files") }

    /// The entries of one system's guides: its own guide's, then those of the guides for both systems.
    public func entries(for system: LorespireDocument.System) throws -> [LorespireEntry] {
        let guides = documents.filter { $0.isGuide && ($0.system == system || $0.system == .both) }
        let sections = try guides.map { LorespireOutline(document: $0, content: try content(of: $0)).sections }
        let prefix = "lorespire.\(system.rawValue)."
        let rewriter = try rewriter(guides: guides, sections: sections, prefix: prefix)
        let pages = zip(guides, sections).flatMap { guide, sections in sections.map { (guide, $0) } }
        return pages.enumerated().map { order, page in
            let (guide, section) = page
            let html = LorespireMarkup.simplify(Self.shiftingHeadings(section.html, below: section.level))
            return LorespireEntry(id: prefix + section.key, name: section.name, part: section.part, order: order,
                                  html: rewriter.rewrite(html, in: guide.id),
                                  source: Self.source(of: section, in: guide))
        }
    }

    /// The licenses page, as Markdown.
    public func licenses() throws -> String {
        guard let document = documents.first(where: { !$0.isGuide }) else { return "" }
        return LorespireMarkdown.markdown(from: LorespireMarkup.simplify(try content(of: document)))
    }

    /// A section's own page, or for a section without one, its heading in the document.
    static func source(of section: LorespireSection, in document: LorespireDocument) -> URL {
        guard section.key.hasPrefix(document.page + ".") else { return Lorespire.pageURL(section.key) }
        return URL(string: Lorespire.pageURL(document.page).absoluteString + "#" + section.headingID)
            ?? Lorespire.pageURL(document.page)
    }

    private func content(of document: LorespireDocument) throws -> String {
        let url = folder.appendingPathComponent(document.fileName)
        guard let html = try? String(contentsOf: url, encoding: .utf8) else {
            throw LorespireError.missingDownload(path: url.path)
        }
        return html
    }

    private func rewriter(guides: [LorespireDocument], sections: [[LorespireSection]],
                          prefix: String) throws -> LorespireLinkRewriter {
        var pages: [String: String] = [:]
        var headings: [String: [String: String]] = [:]
        var firstEntries: [String: String] = [:]
        for (guide, sections) in zip(guides, sections) {
            for section in sections {
                for key in [section.key] + section.aliases { pages[key] = pages[key] ?? prefix + section.key }
                for id in section.headingIDs { headings[guide.id, default: [:]][id] = prefix + section.key }
            }
            firstEntries[guide.id] = sections.first.map { prefix + $0.key }
        }
        return LorespireLinkRewriter(documents: documents, pages: pages, headings: headings,
                                     firstEntries: firstEntries, files: try savedFiles())
    }

    /// The saved files by Lorespire file ID: each is named `<file ID>-<name>` or `<file ID>.<extension>`.
    private func savedFiles() throws -> [Int: String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: filesFolder.path)) ?? []
        let numbered = names.compactMap { name in Int(name.prefix { $0.isNumber }).map { ($0, name) } }
        return Dictionary(numbered) { first, _ in first }
    }

    /// Moves a page's headings up so its first level of sub-headings is `h2`, below the entry's own `h1`.
    static func shiftingHeadings(_ html: String, below level: Int) -> String {
        html.replacing(/<(\/?)h([1-6])\b/) { match in
            let shifted = min(6, max(2, (Int(match.2) ?? level) - level + 1))
            return "<\(match.1)h\(shifted)"
        }
    }
}
