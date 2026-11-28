import Bestiary
import FieldGuideKit
import SourcebookLore
import SwiftUI

/// What an entry page can lead to: another entry, on its overview or its Details and scrolled to a heading's id
/// ("" for the top), or a trait's description.
enum PageLink: Hashable {
    case entry(String, EntryTab = .overview, anchor: String = "")
    case trait(String, GameSystem)
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
    @Environment(\.openURL) private var openURL
    let link: PageLink
    let follow: (PageLink) -> Void
    /// A stored value from before the Lore tab ("statBlock") reads as the default, the card.
    @AppStorage("creatureView") private var creatureView = CreatureView.card
    @State private var entryTab: EntryTab
    /// Spike: the in-app link shown in a popover, and where it was tapped.
    @State private var peek: Peek?
    /// Spike: whether this page's links pop up (a popover's own links follow, as before).
    var peeksLinks = true

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
        EntryWebView(html: html, data: store.data, pdfArt: pdfArt, anchor: anchor,
                     onPeek: peeksLinks ? { url, rect in
                         if case let .page(next) = Self.destination(for: url, system: system) {
                             peek = Peek(link: next, rect: rect)
                         }
                     } : nil) { url in
            switch Self.destination(for: url, system: system) {
            case let .page(next): follow(next)
            case let .browser(web): openURL(web)
            case .ignored: break
            }
        }
        .popover(isPresented: Binding(get: { peek != nil }, set: { if !$0 { peek = nil } }),
                 attachmentAnchor: .rect(.rect(peek?.rect ?? .zero)), arrowEdge: .bottom) {
            if let peek {
                PeekView(link: peek.link) { next in
                    self.peek = nil
                    follow(next)
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

/// Spike: an in-app link tapped on a page, and where.
struct Peek: Equatable {
    let link: PageLink
    let rect: CGRect
}

/// Spike: a linked page in a popover, sized to its content up to a limit, with Open to replace the page with it.
/// Its own links replace the page too.
struct PeekView: View {
    static let width: CGFloat = 460
    static let maximumHeight: CGFloat = 560
    @Environment(CatalogStore.self) private var store
    @Environment(ArtModel.self) private var pdfArt
    let link: PageLink
    let open: (PageLink) -> Void
    @State private var height: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(page?.name ?? "Not in the Field Guide").font(.headline)
                Spacer()
                Button("Open") { open(link) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
            Divider()
            if let page {
                EntryWebView(html: page.html, data: store.data, pdfArt: pdfArt, anchor: anchor,
                             onHeight: { height = $0 }) { url in
                    if case let .page(next) = PageView.destination(for: url, system: page.system) { open(next) }
                }
                .frame(width: Self.width, height: min(max(height, 60), Self.maximumHeight))
            }
        }
        .frame(width: Self.width)
    }

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
}
