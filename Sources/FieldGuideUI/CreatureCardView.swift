import BattleCards
import Bestiary
import SwiftUI

/// How a creature's page is shown: its stat block, or its battle card.
enum CreatureView: String, CaseIterable, Identifiable {
    case statBlock
    case card

    var id: Self { self }

    var title: String {
        switch self {
        case .statBlock: "Stat Block"
        case .card: "Card"
        }
    }

    /// The bestiary key of the creature on an entry page (`Compendium.<system>.<pack>.Actor.<id>` becomes
    /// `<system>.<pack>.<id>`); nil for other pages.
    static func creatureKey(ofEntry id: String) -> String? {
        let parts = id.split(separator: ".")
        guard parts.count == 5, parts[0] == "Compendium", parts[3] == "Actor" else { return nil }
        return "\(parts[1]).\(parts[2]).\(parts[4])"
    }
}

/// A creature's battle card (Tabletop Kit), turned over to its back with the art from the user's PDFs.
struct CreatureCardView: View {
    let creature: Creature
    let key: String
    @Environment(CreatureArtModel.self) private var creatureArt
    @State private var showsBack = false

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if showsBack {
                    CardBack(name: creature.name, game: creature.game, traits: creature.traits.traits) {
                        CreaturePicture(key: key)
                    }
                } else {
                    BattleCard(creature: creature)
                }
            }
            .frame(maxWidth: 520)
            .rotation3DEffect(.degrees(showsBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(x: showsBack ? -1 : 1)
            MissingArtNote(sources: creatureArt.missingSources(forCreature: key))
            Button(showsBack ? "Show Front" : "Turn Over", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                withAnimation(.easeInOut(duration: 0.4)) { showsBack.toggle() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.cardArt, creatureArt.cardArt)
        .environment(\.glossary, GlossaryContext(bestiary: creatureArt.bestiary))
    }
}

/// A creature's art at full size; nothing when it has none.
struct CreaturePicture: View {
    let key: String
    @Environment(CreatureArtModel.self) private var creatureArt
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().interpolation(.high).scaledToFit()
            }
        }
        .task(id: "\(key)#\(creatureArt.catalog.art.count)") {
            image = await creatureArt.picture(forCreature: key, maxPixels: 0)
        }
    }
}

/// Which PDFs a creature's art came from that have since been deleted.
struct MissingArtNote: View {
    let sources: [String]

    var body: some View {
        if !sources.isEmpty {
            Label("Art needs \(sources.formatted()), which was deleted or moved.",
                  systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
