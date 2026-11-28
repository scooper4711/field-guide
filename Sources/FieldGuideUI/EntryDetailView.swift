import Bestiary
import FieldGuideKit
import SourcebookLore
import SwiftUI

/// What an entry page can lead to: another entry, on its overview or its Details and scrolled to a heading's id
/// ("" for the top), or a trait's description.
enum PageLink: Hashable {
    case entry(String, EntryTab = .overview, anchor: String = "")
    case trait(String, GameSystem)

    /// The entry the link opens; nil for a trait.
    var entryID: String? {
        if case let .entry(id, _, _) = self { return id }
        return nil
    }
}

/// Where a link tapped on an entry page goes: another page in the app, a web page in the browser, or nowhere.
enum LinkDestination: Equatable {
    case page(PageLink)
    case browser(URL)
    case ignored

    /// The schemes that open in the browser (or the mail app) rather than in the entry's web view.
    static let browserSchemes: Set<String> = ["http", "https", "mailto"]
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
/// or, for a deity the Paizo Blog published, Foundry's, moved off the overview.
struct PageTabs {
    let page: EntryPage
    /// The deity's lore from the user's sourcebooks, as HTML; nil when it has none.
    let bookLore: String?
    /// The ancestry's or class's lore from the user's book, as HTML, for its Details; nil for other entries.
    var detailsLore: String?

    var tabs: [EntryTab] {
        if !page.details.isEmpty { return [.overview, .details] }
        return lore == nil ? [] : [.overview, .lore]
    }

    func html(for tab: EntryTab) -> String {
        switch tab {
        case .details where !page.details.isEmpty: DetailsPage.inserting(detailsLore ?? "", into: page.details)
        case .lore: lore ?? page.html
        default: lore == nil ? page.html : PageDescription.removingSection(from: page.html)
        }
    }

    private var lore: String? {
        guard page.id.contains(".deities.") else { return nil }
        return bookLore ?? (page.lore.isEmpty ? nil : page.lore)
    }
}

/// Opens an entry as if chosen in the sidebar: its category, its row and its page. False when it can't, as for a
/// trait, so the caller follows the link on its own stack instead.
struct OpenEntryAction {
    let open: @MainActor (PageLink) -> Bool

    @MainActor func callAsFunction(_ link: PageLink) -> Bool { open(link) }
}

extension EnvironmentValues {
    @Entry var openEntry = OpenEntryAction { _ in false }
}

/// The chosen entry, with links followed on a navigation stack so Back returns. `root` opens it at a tab or a
/// heading; nil opens its overview at the top.
struct EntryDetailView: View {
    let rootID: String
    var root: PageLink?
    @Binding var path: [PageLink]
    /// Back to the entry left last, for the entry's own page; nil when none was.
    var back: (() -> Void)?

    var body: some View {
        NavigationStack(path: $path) {
            PageView(link: root ?? .entry(rootID)) { path.append($0) }
                .toolbar { backButton }
                .navigationDestination(for: PageLink.self) { link in
                    PageView(link: link) { path.append($0) }
                }
        }
    }
}

extension EntryDetailView {
    /// The system shows Back on the pages followed from the entry, in place of Search Everything; the entry's own
    /// page gets this one, back to the entry left.
    @ToolbarContentBuilder
    var backButton: some ToolbarContent {
        if let back {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.backward", action: back)
            }
        }
    }
}

/// One page in the stack.
struct PageView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(ArtModel.self) private var pdfArt
    @Environment(SourcebookModel.self) private var sourcebooks
    @Environment(\.openURL) private var openURL
    @Environment(\.openEntry) private var openEntry
    let link: PageLink
    let follow: (PageLink) -> Void
    /// A stored value from before the Lore tab ("statBlock") reads as the default, the card.
    @AppStorage("creatureView") private var creatureView = CreatureView.card
    @State private var entryTab: EntryTab
    /// Whether in-app links open in a popover: on the Mac. In iPadOS 26 a web view in a popover stays blank, so the
    /// iPad follows them as before (issue #118).
    #if os(macOS)
    static let peeksLinks = true
    #else
    static let peeksLinks = false
    #endif

    /// The in-app link shown in a popover, and where it was tapped.
    @State private var peek: Peek?

    init(link: PageLink, follow: @escaping (PageLink) -> Void) {
        self.link = link
        self.follow = follow
        if case let .entry(_, tab, _) = link {
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
        if creature(on: page) != nil, creatureLore(of: page) != nil {
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
            if creatureView == .lore, let lore = creatureLore(of: page) {
                webView(lore, system: page.system)
            } else {
                CreatureCardView(creature: creature, key: key)
            }
        } else {
            webView(pageTabs(of: page).html(for: entryTab), system: page.system)
        }
    }

    /// A creature's lore from the user's books, else the lore the import kept (the Paizo Blog's); nil for none.
    private func creatureLore(of page: EntryPage) -> String? {
        sourcebooks.creatureLore(of: page.id)?.html ?? (page.lore.isEmpty ? nil : page.lore)
    }

    private func pageTabs(of page: EntryPage) -> PageTabs {
        PageTabs(page: page, bookLore: sourcebooks.lore(of: page.id)?.html,
                 detailsLore: sourcebooks.detailsHTML(of: page.id))
    }

    private func webView(_ html: String, system: GameSystem) -> some View {
        EntryWebView(html: html, data: store.data, pdfArt: pdfArt, anchor: anchor, onPeek: Self.peeksLinks ? { url, rect in
            if case let .page(next) = Self.destination(for: url, system: system) { peek = Peek(link: next, rect: rect) }
        } : nil, onLink: { url in
            switch Self.destination(for: url, system: system) {
            case let .page(next): follow(next)
            case let .browser(web): openURL(web)
            case .ignored: break
            }
        })
        .popover(isPresented: Binding(get: { peek != nil }, set: { if !$0 { peek = nil } }),
                 attachmentAnchor: .rect(.rect(peek?.rect ?? .zero)), arrowEdge: .bottom) {
            if let peek {
                PeekView(link: peek.link) { next in
                    self.peek = nil
                    if !openEntry(next) { follow(next) }
                }
            }
        }
    }

    /// The creature a page shows, when the import wrote it for the battle cards.
    private func creature(on page: EntryPage) -> (key: String, creature: Creature)? {
        guard let key = CreatureView.creatureKey(ofEntry: page.id), let creature = pdfArt.creature(key)
        else { return nil }
        return (key, creature)
    }

    /// The heading the page opens at, for a link to one.
    private var anchor: String {
        if case let .entry(_, _, anchor) = link { return anchor }
        return ""
    }

    private var page: EntryPage? {
        switch link {
        case let .entry(id, _, _): store.page(id)
        case let .trait(slug, system): store.trait(slug, in: system)
        }
    }

    /// `entry:<id>`, `entry:<id>#details`, `entry:<id>#<heading>` and `trait:<slug>` links follow to a page; web and
    /// mail links open in the browser; anything else is ignored.
    static func destination(for url: URL, system: GameSystem) -> LinkDestination {
        let target = String(url.absoluteString.drop { $0 != ":" }.dropFirst())
        let decoded = target.removingPercentEncoding ?? target
        let scheme = url.scheme?.lowercased() ?? ""
        switch scheme {
        case "entry":
            let entry = EntryLink.entry(of: decoded)
            return .page(.entry(entry.id, entry.isDetails ? .details : .overview, anchor: entry.anchor))
        case "trait": return .page(.trait(decoded, system))
        default: return LinkDestination.browserSchemes.contains(scheme) ? .browser(url) : .ignored
        }
    }
}
