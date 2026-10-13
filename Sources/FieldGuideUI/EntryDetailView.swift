import Bestiary
import FieldGuideKit
import SwiftUI

/// What an entry page can lead to: another entry, on its overview or its Details, or a trait's description.
enum PageLink: Hashable {
    case entry(String, EntryTab = .overview)
    case trait(String, GameSystem)
}

/// An ancestry's or class's two pages: its overview from the compendium, and its Details from the rules journals.
enum EntryTab: CaseIterable, Identifiable {
    case overview
    case details

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .details: "Details"
        }
    }
}

/// The chosen entry, with links followed on a navigation stack so Back returns.
struct EntryDetailView: View {
    let rootID: String
    @State private var path: [PageLink] = []

    var body: some View {
        NavigationStack(path: $path) {
            PageView(link: .entry(rootID)) { path.append($0) }
                .navigationDestination(for: PageLink.self) { link in
                    PageView(link: link) { path.append($0) }
                }
        }
    }
}

/// One page in the stack.
struct PageView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(ArtModel.self) private var pdfArt
    let link: PageLink
    let follow: (PageLink) -> Void
    /// A stored value from before the Lore tab ("statBlock") reads as the default, the card.
    @AppStorage("creatureView") private var creatureView = CreatureView.card
    @State private var entryTab: EntryTab

    init(link: PageLink, follow: @escaping (PageLink) -> Void) {
        self.link = link
        self.follow = follow
        if case let .entry(_, tab) = link {
            _entryTab = State(initialValue: tab)
        } else {
            _entryTab = State(initialValue: .overview)
        }
    }

    var body: some View {
        if let page {
            content(of: page)
            .navigationTitle(page.name)
            .toolbar { tabs(of: page) }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView("Not in the Field Guide", systemImage: "questionmark.square.dashed")
        }
    }

    /// A creature's [Battle Card | Lore], or an ancestry's or class's [Overview | Details]; nothing for pages with
    /// only one.
    @ToolbarContentBuilder
    private func tabs(of page: EntryPage) -> some ToolbarContent {
        if creature(on: page) != nil, !page.lore.isEmpty {
            ToolbarItem {
                Picker("Show", selection: $creatureView) {
                    ForEach(CreatureView.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        } else if !page.details.isEmpty {
            ToolbarItem {
                Picker("Show", selection: $entryTab) {
                    ForEach(EntryTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// A creature's battle card, or its lore when it has some and the Lore tab is chosen; an ancestry's or class's
    /// Details when chosen; other pages, and creatures without a card, as written.
    @ViewBuilder
    private func content(of page: EntryPage) -> some View {
        if let (key, creature) = creature(on: page) {
            if creatureView == .lore, !page.lore.isEmpty {
                webView(page.lore, system: page.system)
            } else {
                CreatureCardView(creature: creature, key: key)
            }
        } else if entryTab == .details, !page.details.isEmpty {
            webView(page.details, system: page.system)
        } else {
            webView(page.html, system: page.system)
        }
    }

    private func webView(_ html: String, system: GameSystem) -> some View {
        EntryWebView(html: html, data: store.data, pdfArt: pdfArt) { url in
            if let next = Self.link(for: url, system: system) { follow(next) }
        }
    }

    /// The creature a page shows, when the import wrote it for the battle cards.
    private func creature(on page: EntryPage) -> (key: String, creature: Creature)? {
        guard let key = CreatureView.creatureKey(ofEntry: page.id), let creature = pdfArt.creature(key)
        else { return nil }
        return (key, creature)
    }

    private var page: EntryPage? {
        switch link {
        case let .entry(id, _): store.page(id)
        case let .trait(slug, system): store.trait(slug, in: system)
        }
    }

    /// `entry:<id>`, `entry:<id>#details` and `trait:<slug>` links from a page.
    static func link(for url: URL, system: GameSystem) -> PageLink? {
        let target = String(url.absoluteString.drop { $0 != ":" }.dropFirst())
        let decoded = target.removingPercentEncoding ?? target
        switch url.scheme {
        case "entry":
            let entry = EntryLink.entry(of: decoded)
            return .entry(entry.id, entry.isDetails ? .details : .overview)
        case "trait": return .trait(decoded, system)
        default: return nil
        }
    }
}
