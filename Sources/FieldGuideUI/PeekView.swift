import FieldGuideKit
import SwiftUI

/// An in-app link tapped on a page, and where, in the web view's coordinates.
struct Peek: Equatable {
    let link: PageLink
    let rect: CGRect
}

/// A linked page in a popover, sized to its content up to a limit, with Open to show it in full. Its own in-app
/// links open their page the same way; its web links open in the browser.
struct PeekView: View {
    static let width: CGFloat = 460
    static let maximumHeight: CGFloat = 560
    @Environment(CatalogStore.self) private var store
    @Environment(ArtModel.self) private var pdfArt
    @Environment(SourcebookModel.self) private var sourcebooks
    @Environment(\.openURL) private var openURL
    let link: PageLink
    let open: (PageLink) -> Void
    @State private var laidOutHeight: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            // The page's own header names it, so the bar holds only the button.
            HStack {
                Spacer()
                Button("Open") { open(link) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(8)
            Divider()
            if let page {
                EntryWebView(html: html(of: page), data: store.data, pdfArt: pdfArt, anchor: anchor,
                             onHeight: { laidOutHeight = $0 }, onLink: { url in
                    switch PageView.destination(for: url, system: page.system) {
                    case let .page(next): open(next)
                    case let .browser(web): openURL(web)
                    case .ignored: break
                    }
                })
                // The iPad fits the popover into the room beside the link; the page then scrolls in what is left.
                .frame(width: Self.width)
                .frame(minHeight: 60, idealHeight: fittedHeight, maxHeight: fittedHeight)
                // A web view's first page can take a few seconds; until it has drawn, the popover would look empty.
                .overlay { if laidOutHeight == nil { ProgressView() } }
            } else {
                ContentUnavailableView("Not in the Field Guide", systemImage: "questionmark.square.dashed")
                    .frame(width: Self.width, height: 160)
            }
        }
        .frame(width: Self.width)
    }

    /// A page's height as the popover shows it: whole up to the limit, then scrolling.
    static func fitted(_ height: CGFloat) -> CGFloat {
        min(max(height, 60), maximumHeight)
    }

    private var fittedHeight: CGFloat {
        Self.fitted(laidOutHeight ?? 160)
    }

    /// The page as Open shows it: an ancestry's or class's Details for a link to them, else its overview.
    private func html(of page: EntryPage) -> String {
        guard case .entry(_, .details, _) = link else { return page.html }
        let tabs = PageTabs(page: page, bookLore: nil, detailsLore: sourcebooks.detailsHTML(of: page.id))
        return tabs.html(for: .details)
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
