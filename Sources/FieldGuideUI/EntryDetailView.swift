import FieldGuideKit
import SwiftUI

/// What an entry page can lead to: another entry, or a trait's description.
enum PageLink: Hashable {
    case entry(String)
    case trait(String, GameSystem)
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
    let link: PageLink
    let follow: (PageLink) -> Void

    var body: some View {
        if let page {
            EntryWebView(html: page.html, data: store.data) { url in
                if let next = Self.link(for: url, system: page.system) { follow(next) }
            }
            .navigationTitle(page.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView("Not in the Field Guide", systemImage: "questionmark.square.dashed")
        }
    }

    private var page: EntryPage? {
        switch link {
        case let .entry(id): store.page(id)
        case let .trait(slug, system): store.trait(slug, in: system)
        }
    }

    /// `entry:<id>` and `trait:<slug>` links from a page.
    static func link(for url: URL, system: GameSystem) -> PageLink? {
        let target = String(url.absoluteString.drop { $0 != ":" }.dropFirst())
        let decoded = target.removingPercentEncoding ?? target
        switch url.scheme {
        case "entry": return .entry(decoded)
        case "trait": return .trait(decoded, system)
        default: return nil
        }
    }
}
