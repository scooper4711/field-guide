import Bestiary
import FieldGuideKit
import SourcebookLore
import SwiftUI

/// What an entry page can lead to: another entry, on its overview or its Details, or a trait's description.
enum PageLink: Hashable {
    case entry(String, EntryTab = .overview)
    case trait(String, GameSystem)
}

/// An entry's pages beside its overview: an ancestry's or class's Details from the rules journals, or a deity's
/// Lore from the user's sourcebooks.
enum EntryTab: CaseIterable, Identifiable {
    case overview
    case details
    case lore

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .details: "Details"
        case .lore: "Lore"
        }
    }
}

/// The tabs an entry's page has, and what each shows. A deity's Lore is its write-up from the user's sourcebooks,
/// or, in a build that kept the setting's lore, Foundry's, moved off the overview.
struct PageTabs {
    let page: EntryPage
    /// The deity's lore from the user's sourcebooks, as HTML; nil when it has none.
    let bookLore: String?

    var tabs: [EntryTab] {
        if !page.details.isEmpty { return [.overview, .details] }
        return lore == nil ? [] : [.overview, .lore]
    }

    func html(for tab: EntryTab) -> String {
        switch tab {
        case .details where !page.details.isEmpty: page.details
        case .lore: lore ?? page.html
        default: lore == nil ? page.html : PageDescription.removingSection(from: page.html)
        }
    }

    private var lore: String? {
        guard page.id.contains(".deities.") else { return nil }
        return bookLore ?? (page.lore.isEmpty ? nil : page.lore)
    }
}

/// The chosen entry, with links followed on a navigation stack so Back returns.
struct EntryDetailView: View {
    let rootID: String
    @Binding var path: [PageLink]

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
    @Environment(SourcebookModel.self) private var sourcebooks
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

    /// A creature's [Battle Card | Lore], an ancestry's or class's [Overview | Details], or a deity's [Overview |
    /// Lore]; nothing for pages with only one.
    @ToolbarContentBuilder
    private func tabs(of page: EntryPage) -> some ToolbarContent {
        if creature(on: page) != nil, !page.lore.isEmpty {
            ToolbarItem {
                Picker("Show", selection: $creatureView) {
                    ForEach(CreatureView.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        } else if !pageTabs(of: page).tabs.isEmpty {
            ToolbarItem {
                Picker("Show", selection: $entryTab) {
                    ForEach(pageTabs(of: page).tabs) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// A creature's battle card, or its lore when it has some and the Lore tab is chosen; an ancestry's or class's
    /// Details or a deity's Lore when chosen; other pages, and creatures without a card, as written.
    @ViewBuilder
    private func content(of page: EntryPage) -> some View {
        if let (key, creature) = creature(on: page) {
            if creatureView == .lore, !page.lore.isEmpty {
                webView(page.lore, system: page.system)
            } else {
                CreatureCardView(creature: creature, key: key)
            }
        } else {
            webView(pageTabs(of: page).html(for: entryTab), system: page.system)
        }
    }

    private func pageTabs(of page: EntryPage) -> PageTabs {
        PageTabs(page: page, bookLore: sourcebooks.lore(of: page.id)?.html)
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
