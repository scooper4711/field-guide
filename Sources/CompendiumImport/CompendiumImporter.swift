import FieldGuideKit
import Foundation

/// Where the importer reads from and writes to.
public struct ImportOptions: Sendable {
    public var paths: FoundryPaths
    /// Scrollkeeper's `Files` folder, for the area diagrams in the Player Core PDFs; nil to leave them out.
    public var scrollkeeperFiles: URL?
    public var output: URL

    public init(paths: FoundryPaths, scrollkeeperFiles: URL? = nil, output: URL) {
        self.paths = paths
        self.scrollkeeperFiles = scrollkeeperFiles
        self.output = output
    }
}

/// Reads both systems' packs and writes `catalog.sqlite`, the images, the fonts and `import-report.md`.
public struct CompendiumImporter {
    public let options: ImportOptions

    public init(options: ImportOptions) {
        self.options = options
    }

    public func run() throws -> ImportReport {
        let repository = options.paths.repository
        let scanner = PackScanner(repository: repository)
        let documents = try documents(scanner: scanner)
        let localizer = try Localizer(languageDirectory: repository.appendingPathComponent("static/lang"))
        let glossary = TraitGlossary(repository: repository, localizer: localizer)
        let journalPages = GameSystem.allCases.flatMap { GMScreen.pages(repository: repository, system: $0) }
        var links = LinkIndex(documents: documents)
        journalPages.forEach { links.add($0) }
        let enricher = Enricher(localizer: localizer, links: links)
        let images = ImageCollector(paths: options.paths, output: options.output.appendingPathComponent("Images"))
        let context = PageContext(enricher: enricher, links: links, glossary: glossary, images: images)
        let builder = PageBuilder(context: context)
        let diagrams = options.scrollkeeperFiles.map {
            AreaDiagrams(scrollkeeperFiles: $0, images: options.output.appendingPathComponent("Images")).rows()
        } ?? []
        let areas = Dictionary(diagrams.map { ($0.system, $0.id) }, uniquingKeysWith: { first, _ in first })
        let journalRows = journalPages.map { GMScreen.row($0, context: context, areasEntry: areas[$0.system]) }
        let rows = documents.map(builder.row(for:)) + journalRows + diagrams
        let traits = traitRows(rows, glossary: glossary, enricher: enricher)
        try FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
        try CatalogWriter.write(rows, traits: traits, to: options.output.appendingPathComponent("catalog.sqlite"))
        try copyFonts()
        let report = ImportReport(rows: rows, enricher: enricher, images: images)
        try report.markdown.write(to: options.output.appendingPathComponent("import-report.md"), atomically: true,
                                  encoding: .utf8)
        return report
    }

    /// Both systems' documents, with the Pathfinder ones the Starfinder build copies into its packs.
    private func documents(scanner: PackScanner) throws -> [SourceDocument] {
        let pathfinder = try scanner.packs(of: .pathfinder).flatMap(scanner.documents(in:))
        let starfinderPacks = try scanner.packs(of: .starfinder)
        let starfinder = starfinderPacks.flatMap(scanner.documents(in:))
        let copies = StarfinderDuplicates(repository: options.paths.repository)
            .copies(of: pathfinder, into: starfinderPacks)
        return pathfinder + starfinder + copies
    }

    /// A page for each trait the entries show that has a description.
    private func traitRows(_ rows: [EntryRow], glossary: TraitGlossary,
                           enricher: Enricher) -> [CatalogWriter.TraitRow] {
        var seen: Set<String> = []
        var result: [CatalogWriter.TraitRow] = []
        for row in rows {
            for slug in row.traitSlugs where seen.insert("\(row.system.rawValue).\(slug)").inserted {
                guard let description = glossary.description(of: slug, in: row.system) else { continue }
                let label = glossary.label(of: slug, in: row.system)
                let html = "<header class=\"entry-header\"><div><h1>\(HTML.escape(label))</h1>"
                    + "<p class=\"subtitle\">Trait</p></div></header><section class=\"description\">"
                    + "\(enricher.enrich(description.hasPrefix("<") ? description : "<p>\(description)</p>"))</section>"
                result.append(.init(system: row.system, slug: slug, label: label, html: html))
            }
        }
        return result
    }

    /// The Pathfinder action glyphs and Foundry's text fonts, for the entry pages.
    private func copyFonts() throws {
        let fonts = options.paths.repository.appendingPathComponent("static/fonts")
        let destination = options.output.appendingPathComponent("Fonts")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let wanted = try FileManager.default.contentsOfDirectory(atPath: fonts.path).filter {
            $0.hasSuffix(".woff2") && ($0.hasPrefix("pathfinder-2e-actions") || $0.hasPrefix("gelasio")
                || $0.hasPrefix("roboto-condensed"))
        }
        for name in wanted {
            let target = destination.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: fonts.appendingPathComponent(name), to: target)
        }
    }
}

/// What an import produced, and what it could not convert.
public struct ImportReport {
    public let counts: [String: Int]
    public let unconverted: [String: Int]
    public let unresolvedLinks: [String: Int]
    public let missingImages: [String: Int]
    public let withImages: Int
    public let total: Int

    init(rows: [EntryRow], enricher: Enricher, images: ImageCollector) {
        counts = Dictionary(grouping: rows) { "\($0.system.title) \($0.category.title)" }.mapValues(\.count)
        unconverted = enricher.unconverted
        unresolvedLinks = enricher.unresolvedLinks
        missingImages = images.missing
        withImages = rows.filter { !$0.image.isEmpty }.count
        total = rows.count
    }

    public var summary: String {
        let unresolved = unresolvedLinks.values.reduce(0, +)
        return "Imported \(total) entries (\(withImages) with images); \(unresolved) unresolved links, "
            + "\(missingImages.count) missing images."
    }

    public var markdown: String {
        var lines = ["# Import report", "", summary, "", "## Entries", ""]
        lines += counts.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }
        lines += ["", "## Unconverted enrichers", ""] + Self.top(unconverted)
        lines += ["", "## Unresolved links (most frequent)", ""] + Self.top(unresolvedLinks)
        lines += ["", "## Missing images", ""] + Self.top(missingImages)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func top(_ counts: [String: Int], limit: Int = 50) -> [String] {
        counts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.prefix(limit).map { "- \($0.key): \($0.value)" }
    }
}
