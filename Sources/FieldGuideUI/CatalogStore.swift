import FieldGuideKit
import Foundation
import Observation

/// The app's state: the open catalog, the chosen system and category, and the list's query and results.
@MainActor
@Observable
public final class CatalogStore {
    public private(set) var catalog: Catalog?
    public private(set) var errorMessage: String?
    public private(set) var categories: [EntryCategory] = []
    public private(set) var entries: [EntrySummary] = []
    public private(set) var results: [EntrySummary] = []
    public private(set) var options = FacetOptions(entries: [], facets: [])
    public private(set) var levelRange: ClosedRange<Int>?
    public let data: DataLocation

    public var system: GameSystem {
        didSet {
            guard system != oldValue else { return }
            UserDefaults.standard.set(system.rawValue, forKey: Self.systemKey)
            loadCategories()
        }
    }

    public var category: EntryCategory? {
        didSet {
            guard category != oldValue else { return }
            UserDefaults.standard.set(category?.rawValue, forKey: Self.categoryKey)
            query = EntryQuery()
            loadEntries()
        }
    }

    public var query = EntryQuery() {
        didSet { if query != oldValue { applyQuery() } }
    }

    static let systemKey = "system"
    static let categoryKey = "category"

    public init(data: DataLocation = .standard) {
        self.data = data
        let defaults = UserDefaults.standard
        system = defaults.string(forKey: Self.systemKey).flatMap(GameSystem.init) ?? .pathfinder
        category = defaults.string(forKey: Self.categoryKey).flatMap(EntryCategory.init) ?? .spells
        do {
            catalog = try Catalog(url: data.catalog)
        } catch {
            errorMessage = "Opening the catalog failed: \(error). Run make import, then build the app again."
        }
        loadCategories()
    }

    /// The facets the current category filters by.
    public var facets: [Facet] {
        [.rarity, .traits, .source] + (category?.facets ?? [])
    }

    private func loadCategories() {
        categories = (try? catalog?.categories(in: system)) ?? []
        if let category, categories.contains(category) {
            loadEntries()
        } else {
            category = categories.first
        }
    }

    private func loadEntries() {
        guard let catalog, let category else {
            entries = []
            applyQuery()
            return
        }
        entries = (try? catalog.summaries(of: category, in: system)) ?? []
        options = FacetOptions(entries: entries, facets: [.rarity, .traits, .source] + category.facets)
        levelRange = category.hasLevels ? FacetOptions.levelRange(of: entries) : nil
        applyQuery()
    }

    private func applyQuery() {
        var matches: Set<String>?
        if query.searchesText, !query.text.isEmpty, let catalog, let category {
            matches = (try? catalog.search(query.text, in: category, of: system)) ?? []
        }
        results = query.apply(to: entries, textMatches: matches)
    }

    public func page(_ id: String) -> EntryPage? {
        try? catalog?.page(of: id)
    }

    public func trait(_ slug: String, in system: GameSystem) -> EntryPage? {
        try? catalog?.trait(slug, in: system)
    }
}

/// Where the imported data lives: in the app bundle on the iPad, in the repository's `Generated` folder on
/// the Mac (or wherever `FIELD_GUIDE_DATA` points).
public struct DataLocation: Sendable {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public static var standard: DataLocation {
        if let path = ProcessInfo.processInfo.environment["FIELD_GUIDE_DATA"] {
            return DataLocation(folder: URL(fileURLWithPath: path))
        }
        if let bundled = Bundle.main.url(forResource: "Generated", withExtension: nil) {
            return DataLocation(folder: bundled)
        }
        return DataLocation(folder: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Generated"))
    }

    public var catalog: URL { folder.appendingPathComponent("catalog.sqlite") }
    public var images: URL { folder.appendingPathComponent("Images") }
    public var fonts: URL { folder.appendingPathComponent("Fonts") }
}
