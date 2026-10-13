import BattleCards
import Bestiary
import SwiftUI

/// How a creature's page is shown: its battle card, or its lore.
enum CreatureView: String, CaseIterable, Identifiable {
    case card
    case lore

    var id: Self { self }

    var title: String {
        switch self {
        case .card: "Battle Card"
        case .lore: "Lore"
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

/// A creature's battle card (Tabletop Kit's interactive card): a tap on empty card area shows the icons that turn
/// it over to the art from the user's PDFs and show it full screen; linked words open glossary popovers.
struct CreatureCardView: View {
    /// Card backs draw the art this large on its long side; the art store scales to the size asked for.
    static let artPixels = 1600
    let creature: Creature
    let key: String
    @Environment(ArtModel.self) private var pdfArt

    var body: some View {
        VStack(spacing: 12) {
            FittedCard {
                InteractiveBattleCard {
                    BattleCard(creature: creature)
                } back: {
                    CardBack(name: creature.name, game: creature.game, traits: creature.traits.traits) {
                        ArtPicture(path: key)
                    }
                }
                .id(key)
            }
            MissingArtNote(sources: pdfArt.missingSources(forCreature: key))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.cardArt, pdfArt.cardArt)
        .environment(\.glossary, GlossaryContext(bestiary: pdfArt.bestiary))
        .environment(\.artPictureLoader, ArtPictureLoader { [pdfArt] key in
            await pdfArt.picture(forCreature: key, maxPixels: Self.artPixels)
        })
    }
}

/// A card laid out at its own width and scaled as a whole to fill the space's width, so its text wraps the same in
/// any column, whether the sidebar shows or not.
struct FittedCard<Card: View>: View {
    static var layoutWidth: CGFloat { 440 }
    @ViewBuilder let card: Card

    var body: some View {
        GeometryReader { proxy in
            let scale = Self.scale(toFit: proxy.size.width)
            card
                .frame(width: Self.layoutWidth, height: proxy.size.height / scale)
                .scaleEffect(scale, anchor: .top)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    /// How much the card is scaled to fill `width`; not at all before there is a width.
    static func scale(toFit width: CGFloat) -> CGFloat {
        width > 0 ? width / layoutWidth : 1
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
