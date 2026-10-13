import FieldGuideKit
import Foundation

/// Where the importer reads from and writes to.
public struct ImportOptions: Sendable {
    public var paths: FoundryPaths
    /// The user's Rexard packs, whose pictures stand in for Foundry's icons; nil for no icons.
    public var rexardPacks: URL?
    /// Rexard files by Foundry path or entry id, for icons the rules pick badly.
    public var iconOverrides: [String: String] = [:]
    /// The deities' religious symbols from the Community Use Package; none unless set.
    public var religiousSymbols = ReligiousSymbols()
    /// Paizo's Pathfinder-Icons font for the action icons, copied unaltered; nil (or a missing file) for none.
    public var actionIconsFont: URL?
    /// Scrollkeeper's `Files` folder, for the area diagrams in the Player Core PDFs; nil to leave them out.
    public var scrollkeeperFiles: URL?
    public var output: URL
    /// Where the import keeps what the app doesn't need: the Rexard hash cache and `icon-map.tsv`. The output
    /// goes into the app whole.
    public var workFolder: URL

    public init(paths: FoundryPaths, output: URL, workFolder: URL) {
        self.paths = paths
        self.output = output
        self.workFolder = workFolder
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
        let details = JournalDetails(pages: journalPages, documents: documents)
        var links = LinkIndex(documents: documents)
        journalPages.forEach { links.add($0, target: details.linkTarget(of: $0)) }
        let enricher = Enricher(localizer: localizer, links: links)
        let images = ImageCollector(icons: IconMap(documents: documents, sources: iconSources()),
                                    packs: options.rexardPacks, output: options.output.appendingPathComponent("Images"))
        images.symbols = options.religiousSymbols
        let context = PageContext(enricher: enricher, links: links, glossary: glossary, images: images)
        let builder = PageBuilder(context: context)
        let diagrams = areaDiagrams()
        let areas = Dictionary(diagrams.map { ($0.system, $0.id) }, uniquingKeysWith: { first, _ in first })
        let journalRows = details.entries.map { GMScreen.row($0, context: context, areasEntry: areas[$0.system]) }
        let rows = details.attaching(to: documents.map(builder.row(for:)), context: context) + journalRows + diagrams
        let traits = traitRows(rows, glossary: glossary, enricher: enricher)
        try FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
        try CatalogWriter.write(rows, traits: traits, to: options.output.appendingPathComponent("catalog.sqlite"))
        try copyFonts()
        try FileManager.default.createDirectory(at: options.workFolder, withIntermediateDirectories: true)
        try images.icons.table(of: documents).write(to: options.workFolder.appendingPathComponent("icon-map.tsv"),
                                                    atomically: true, encoding: .utf8)
        let report = ImportReport(rows: rows, enricher: enricher, images: images)
        try report.markdown.write(to: options.output.appendingPathComponent("import-report.md"), atomically: true,
                                  encoding: .utf8)
        return report
    }

    /// The GM Screen's area diagrams, from the Player Core PDFs Scrollkeeper downloaded; none without them.
    private func areaDiagrams() -> [EntryRow] {
        options.scrollkeeperFiles.map {
            AreaDiagrams(scrollkeeperFiles: $0, images: options.output.appendingPathComponent("Images")).rows()
        } ?? []
    }

    /// The Rexard packs' pictures, hashed, with the overrides.
    private func iconSources() -> IconSources {
        let rexard = options.rexardPacks.map {
            RexardIcons.load(folder: $0, cache: options.workFolder.appendingPathComponent("rexard-hashes.json"))
        }
        return IconSources(paths: options.paths, rexard: rexard, overrides: options.iconOverrides)
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

    /// Foundry's text fonts and the Pathfinder-Icons action font, for the entry pages. The pf2e action font
    /// that Pathfinder-Icons replaced is removed.
    private func copyFonts() throws {
        let fonts = options.paths.repository.appendingPathComponent("static/fonts")
        let destination = options.output.appendingPathComponent("Fonts")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination.appendingPathComponent("pathfinder-2e-actions.woff2"))
        let wanted = try FileManager.default.contentsOfDirectory(atPath: fonts.path).filter {
            $0.hasSuffix(".woff2") && ($0.hasPrefix("gelasio") || $0.hasPrefix("roboto-condensed"))
        }
        var sources = wanted.map { fonts.appendingPathComponent($0) }
        if let font = options.actionIconsFont, FileManager.default.fileExists(atPath: font.path) {
            sources.append(font)
        }
        for source in sources {
            let target = destination.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: source, to: target)
        }
    }
}

/// What an import produced, and what it could not convert.
public struct ImportReport {
    public let counts: [String: Int]
    public let unconverted: [String: Int]
    public let unresolvedLinks: [String: Int]
    /// How many entries got their icon by each rule.
    public let iconRules: [String: Int]
    /// The Foundry icons of entries left without one, with how many entries use each.
    public let unresolvedIcons: [String: Int]
    public let withImages: Int
    public let total: Int

    init(rows: [EntryRow], enricher: Enricher, images: ImageCollector) {
        counts = Dictionary(grouping: rows) { "\($0.system.title) \($0.category.title)" }.mapValues(\.count)
        unconverted = enricher.unconverted
        unresolvedLinks = enricher.unresolvedLinks
        iconRules = Dictionary(uniqueKeysWithValues: images.icons.counts.map { ($0.key.rawValue, $0.value) })
        unresolvedIcons = images.icons.unresolved
        withImages = rows.filter { !$0.image.isEmpty }.count
        total = rows.count
    }

    public var summary: String {
        let unresolved = unresolvedLinks.values.reduce(0, +)
        return "Imported \(total) entries (\(withImages) with images); \(unresolved) unresolved links, "
            + "\(unresolvedIcons.values.reduce(0, +)) entries without icons."
    }

    public var markdown: String {
        var lines = ["# Import report", "", summary, "", "## Entries", ""]
        lines += counts.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }
        lines += ["", "## Unconverted enrichers", ""] + Self.top(unconverted)
        lines += ["", "## Unresolved links (most frequent)", ""] + Self.top(unresolvedLinks)
        lines += ["", "## Icons by rule", ""] + Self.top(iconRules)
        lines += ["", "## Foundry icons left without a Rexard icon", ""] + Self.top(unresolvedIcons)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func top(_ counts: [String: Int], limit: Int = 50) -> [String] {
        counts.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.prefix(limit).map { "- \($0.key): \($0.value)" }
    }
}
