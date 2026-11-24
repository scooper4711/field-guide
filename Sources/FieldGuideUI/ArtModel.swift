import BattleCards
import Bestiary
import CoreGraphics
import CreatureArt
import FieldGuideKit
import Foundation
import ImageIO
import Observation
import SharedLibraries
import TablesideShared
import UniformTypeIdentifiers

/// Creature and item art from the user's own Paizo PDFs, and the creatures the battle cards show: the art library
/// the Tableside apps share (Tabletop Kit), the import's `Creatures` folder, the custom creatures and art the user
/// made in Turnkeeper and Pawn Shop, and the art chosen or matched by name for each creature or item.
@MainActor
@Observable
public final class ArtModel {
    /// The creatures written by the import, for the battle cards; empty when there are none.
    public let bestiary: BestiaryStore
    /// The cards' UI art, copied from the user's Rexard packs by the import.
    public let cardArt: CardArtPieces
    public internal(set) var catalog = ArtCatalog()
    /// What reading PDFs is doing, while it runs.
    public private(set) var progress: String?
    /// The result of the last import, shown until dismissed.
    public var message: String?
    /// The custom creatures with stat blocks, as list entries (shared libraries R4.3).
    public private(set) var customCreatures: [EntrySummary] = []
    /// What the shared creature library holds; empty outside the App Group.
    private(set) var creatureLibrary = CreatureLibraryContents()
    @ObservationIgnored private let store: CreatureArtStore?
    @ObservationIgnored private let sharedLibrary: SharedLibrary?
    @ObservationIgnored private var matcher = LibraryArtMatcher()
    @ObservationIgnored private var changeObserver: LibraryChangeObserver?
    @ObservationIgnored private var changeCounter: Int64 = 0
    /// True while the app is in the background, when the shared database stays closed (R5.4).
    @ObservationIgnored private var isInBackground = false
    @ObservationIgnored private var artRefresh: Task<Void, Never>?
    @ObservationIgnored private var artNeedsRefresh = false

    public init(data: DataLocation, store: CreatureArtStore?, sharedLibrary: SharedLibrary? = nil) {
        bestiary = (try? BestiaryStore(generatedDirectory: data.creatures)) ?? BestiaryStore()
        cardArt = CardArtPieces(folder: data.cardArt)
        self.store = store
        self.sharedLibrary = sharedLibrary
        // Counted before the first read, so a change made meanwhile is read again rather than missed.
        changeCounter = (try? sharedLibrary?.changeCounter()) ?? 0
        readCreatureLibrary()
    }

    /// The model over the shared libraries in the App Group, moving the app's own art library in first; outside
    /// the group, or until the move succeeds, over the app's own in `Application Support/Field Guide/Creature Art`.
    public static func standard(data: DataLocation) -> ArtModel {
        let opening = SharedLibraryOpening.open()
        let model = ArtModel(data: data, store: opening.art, sharedLibrary: opening.creatures)
        if let failure = opening.failure { model.message = failure }
        return model
    }

    /// Reads what the art library holds and matches it again; with `addingNew`, first adds the PDFs that have
    /// appeared in the watched folders, as at launch.
    public func refresh(addingNew: Bool = false) async {
        guard let store else { return }
        if addingNew {
            progress = "Looking for new PDFs…"
            let summary = await store.addNewFiles(progress: reporter())
            if summary.pdfs > 0 { message = summary.message }
        }
        catalog = await store.catalog()
        matcher = LibraryArtMatcher(art: catalog.art, overrides: bestiary.artOverrides)
        progress = nil
    }

    /// Watches Scrollkeeper's download folder and uses the PDFs of creature art in it, where they are.
    public func importFolder(_ folder: URL) async {
        guard let store else { return }
        progress = "Processing Scrollkeeper's PDFs…"
        message = await store.importFolder(folder, progress: reporter()).message
        await refresh()
    }

    /// Keeps copies of PDFs the user chose and uses their creature art.
    public func addFiles(_ files: [URL]) async {
        guard let store else { return }
        progress = "Processing PDFs…"
        message = await store.addFiles(files, progress: reporter()).message
        await refresh()
    }

    public func removeSource(id: String) async {
        do {
            try await store?.removeSource(id: id)
        } catch {
            message = error.localizedDescription
        }
        await refresh()
    }

    public func stopWatching(_ folder: String) async {
        do {
            try await store?.unwatch(folder)
        } catch {
            message = error.localizedDescription
        }
        await refresh()
    }

    /// The creature with this key (`<system>.<pack>.<id>`, or `custom.<id>` for a custom creature), for its
    /// battle card.
    public func creature(_ key: String) -> Creature? {
        CreatureLibraryContents.isCustomKey(key) ? creatureLibrary.creatures[key] : bestiary.creature(key)
    }

    /// The creature's art, at most `maxPixels` on its long side: the art chosen for it in Turnkeeper or Pawn Shop
    /// (R3.4), else, or when that can't be drawn, the art matched by its name; nil when it has none that can be
    /// drawn.
    public func picture(forCreature key: String, maxPixels: Int) async -> CGImage? {
        if let chosen = await chosenPicture(forCreature: key, maxPixels: maxPixels) { return chosen }
        guard let id = matched(key).portrait else { return nil }
        return await store?.picture(id: id, maxPixels: maxPixels)
    }

    /// Names the art the creature shows now, so a view showing it draws it again when another app chooses
    /// different art (R6.6).
    public func artChoiceTag(forCreature key: String) -> String {
        creatureLibrary.choices[key].map { String(describing: $0) } ?? "matched"
    }

    private func chosenPicture(forCreature key: String, maxPixels: Int) async -> CGImage? {
        switch creatureLibrary.choices[key] {
        case .custom(let id):
            guard let file = creatureLibrary.customFiles[id] else { return nil }
            return await Self.picture(in: file, maxPixels: maxPixels)
        case .library(let id):
            return await store?.picture(id: id, maxPixels: maxPixels)
        case nil:
            return nil
        }
    }

    /// The creature's art as PNG, for entry pages.
    public func png(forCreature key: String, maxPixels: Int) async -> Data? {
        await picture(forCreature: key, maxPixels: maxPixels).flatMap(Self.png(of:))
    }

    /// The item's art from the user's item decks, at most `maxPixels` on its long side; nil when it has none that
    /// can be drawn.
    public func picture(forItem item: ItemArtPath, maxPixels: Int) async -> CGImage? {
        let game: Game = item.system == .starfinder ? .starfinder : .pathfinder
        guard let id = matcher.art(forItemNamed: item.name, game: game).portrait else { return nil }
        return await store?.picture(id: id, maxPixels: maxPixels)
    }

    /// The item's art as PNG, for entry pages.
    public func png(forItem item: ItemArtPath, maxPixels: Int) async -> Data? {
        await picture(forItem: item, maxPixels: maxPixels).flatMap(Self.png(of:))
    }

    private static func png(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The missing PDFs a creature's art needs: the chosen art's, else the art matched by name's; empty when it has
    /// art or never had any.
    public func missingSources(forCreature key: String) -> [String] {
        chosenArtMissingSources(key) ?? matched(key).missingSources
    }

    /// The missing PDFs the art chosen for the creature needs, empty when it can be drawn; nil when there is no
    /// choice or the chosen art is gone, so the art matched by name stands in.
    private func chosenArtMissingSources(_ key: String) -> [String]? {
        switch creatureLibrary.choices[key] {
        case .custom(let id):
            guard let file = creatureLibrary.customFiles[id], FileManager.default.fileExists(atPath: file.path)
            else { return nil }
            return []
        case .library(let id):
            guard let art = catalog.art.first(where: { $0.id == id }) else { return nil }
            return art.isAvailable ? [] : art.sourceTitles
        case nil:
            return nil
        }
    }

    private func matched(_ key: String) -> MatchedArt {
        if let custom = creatureLibrary.creatures[key] {
            return matcher.art(forCreatureNamed: custom.name, game: custom.game, isRemastered: true)
        }
        guard let entry = bestiary.entry(key) else { return .none }
        return matcher.art(forCreatureNamed: entry.name, game: entry.game, isRemastered: entry.source.isRemastered)
    }

    private func reporter() -> @Sendable (String) -> Void {
        { name in Task { @MainActor in self.progress = "Processing \(name)…" } }
    }

    // MARK: The shared creature library

    /// Reads the shared library again whenever any app changes it (R5.2), and its art too when that changed.
    public func startFollowingSharedLibrary() {
        guard sharedLibrary != nil, changeObserver == nil else { return }
        changeObserver = SharedLibraryChange.observe { [weak self] in self?.followSharedLibrary() }
    }

    /// Lets go of the shared database, which iOS would otherwise end the app for holding while suspended (R5.4),
    /// and leaves it closed, ignoring other apps' changes, until `resumeSharedLibrary()`.
    public func closeSharedLibrary() async {
        isInBackground = true
        sharedLibrary?.close()
        await store?.close()
    }

    /// Back in the foreground: reads what other apps changed meanwhile.
    public func resumeSharedLibrary() {
        guard isInBackground else { return }
        isInBackground = false
        followSharedLibrary()
    }

    func followSharedLibrary() {
        guard let sharedLibrary, !isInBackground else { return }
        let changes: LibraryChanges
        do {
            changes = try sharedLibrary.changes(since: changeCounter)
        } catch {
            message = "Reading the shared library's changes failed: \(error.localizedDescription)"
            return
        }
        changeCounter = changes.counter
        let tables = changes.changedTables.union(changes.deletions.keys)
        if !tables.isDisjoint(with: Self.creatureTables) { readCreatureLibrary() }
        if !tables.isDisjoint(with: Self.artTables) { scheduleArtRefresh() }
    }

    /// Reads the art catalog again after another app's change: once for a burst of changes, and not during this
    /// app's own import, which reads it when it ends. A change during a refresh brings another.
    private func scheduleArtRefresh() {
        artNeedsRefresh = true
        guard progress == nil, artRefresh == nil else { return }
        artRefresh = Task {
            while artNeedsRefresh && !isInBackground {
                artNeedsRefresh = false
                await refresh()
            }
            artRefresh = nil
        }
    }

    private static let creatureTables: Set<LibraryTable> = [.customCreatures, .customArt, .creatureArt]
    private static let artTables: Set<LibraryTable> = [.sources, .sourceAccess, .watchedFolders, .art, .prints,
                                                       .aliases, .notes]

    private func readCreatureLibrary() {
        guard let sharedLibrary else { return }
        do {
            let contents = try CreatureLibraryContents(reading: sharedLibrary)
            guard contents != creatureLibrary else { return }
            creatureLibrary = contents
            customCreatures = contents.summaries
        } catch {
            message = "Reading the shared library failed: \(error.localizedDescription)"
        }
    }

    /// Custom art's image, at most `maxPixels` on its long side, read off the main thread.
    private static func picture(in file: URL, maxPixels: Int) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: maxPixels]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
    }
}

extension DataLocation {
    /// The creatures the import wrote for the battle cards.
    public var creatures: URL { folder.appendingPathComponent("Creatures") }
    /// The cards' UI art.
    public var cardArt: URL { folder.appendingPathComponent("CardArt") }
}
