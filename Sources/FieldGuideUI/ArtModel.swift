import BattleCards
import Bestiary
import CoreGraphics
import CreatureArt
import FieldGuideKit
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

/// Creature and item art from the user's own Paizo PDFs, and the creatures the battle cards show: the shared art
/// store (Tabletop Kit), the import's `Creatures` folder, and the art matched to each creature or item by name.
@MainActor
@Observable
public final class ArtModel {
    /// The creatures written by the import, for the battle cards; empty when there are none.
    public let bestiary: BestiaryStore
    /// The cards' UI art, copied from the user's Rexard packs by the import.
    public let cardArt: CardArtPieces
    public private(set) var catalog = ArtCatalog()
    /// What reading PDFs is doing, while it runs.
    public private(set) var progress: String?
    /// The result of the last import, shown until dismissed.
    public var message: String?
    @ObservationIgnored private let store: CreatureArtStore?
    @ObservationIgnored private var matcher = LibraryArtMatcher()

    public init(data: DataLocation, store: CreatureArtStore?) {
        bestiary = (try? BestiaryStore(generatedDirectory: data.creatures)) ?? BestiaryStore()
        cardArt = CardArtPieces(folder: data.cardArt)
        self.store = store
    }

    /// The model over the store in `Application Support/Field Guide/Creature Art`.
    public static func standard(data: DataLocation) -> ArtModel {
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Field Guide/Creature Art")
        return ArtModel(data: data, store: try? CreatureArtStore(folder: folder))
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
        progress = "Reading Scrollkeeper's PDFs…"
        message = await store.importFolder(folder, progress: reporter()).message
        await refresh()
    }

    /// Keeps copies of PDFs the user chose and uses their creature art.
    public func addFiles(_ files: [URL]) async {
        guard let store else { return }
        progress = "Reading PDFs…"
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

    /// The creature with this key (`<system>.<pack>.<id>`), for its battle card.
    public func creature(_ key: String) -> Creature? {
        bestiary.creature(key)
    }

    /// The creature's art, at most `maxPixels` on its long side; nil when it has none that can be drawn.
    public func picture(forCreature key: String, maxPixels: Int) async -> CGImage? {
        guard let id = matched(key).portrait else { return nil }
        return await store?.picture(id: id, maxPixels: maxPixels)
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

    /// The missing PDFs a creature's art needs; empty when it has art or never had any.
    public func missingSources(forCreature key: String) -> [String] {
        matched(key).missingSources
    }

    private func matched(_ key: String) -> MatchedArt {
        guard let entry = bestiary.entry(key) else { return .none }
        return matcher.art(forCreatureNamed: entry.name, game: entry.game, isRemastered: entry.source.isRemastered)
    }

    private func reporter() -> @Sendable (String) -> Void {
        { name in Task { @MainActor in self.progress = "Reading \(name)…" } }
    }
}

extension DataLocation {
    /// The creatures the import wrote for the battle cards.
    public var creatures: URL { folder.appendingPathComponent("Creatures") }
    /// The cards' UI art.
    public var cardArt: URL { folder.appendingPathComponent("CardArt") }
}
