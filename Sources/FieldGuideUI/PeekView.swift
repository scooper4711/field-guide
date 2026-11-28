import FieldGuideKit
import SwiftUI

/// An in-app link tapped on a page, where, in the web view's coordinates, and how tall its page is once measured.
struct Peek: Equatable {
    let link: PageLink
    let rect: CGRect
    var height: CGFloat?
}

/// A linked page in a popover, sized to its content up to a limit, with Open to show it in full. Its own in-app
/// links open their page the same way; its web links open in the browser.
///
/// The iPad's popover keeps the size it opens at, so the page is first laid out unseen (`onMeasured`) and the
/// popover then opens at the page's `height`.
struct PeekView: View {
    static let width: CGFloat = 460
    static let maximumHeight: CGFloat = 560
    @Environment(CatalogStore.self) private var store
    @Environment(ArtModel.self) private var pdfArt
    @Environment(SourcebookModel.self) private var sourcebooks
    @Environment(\.openURL) private var openURL
    let link: PageLink
    /// The page's height, measured beforehand; nil while measuring.
    var height: CGFloat?
    /// Called with the page's height once laid out, when measuring.
    var onMeasured: ((CGFloat) -> Void)?
    let open: (PageLink) -> Void
    @State private var laidOutHeight: CGFloat?

    var body: some View {
        VStack(spacing: 0) {
            // The page's own header names it, so the bar holds only the button.
            HStack {
                Spacer()
                Button("Open") {
                    NSLog("PEEKDEBUG open tapped %@", "\(link)")
                    open(link)
                }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(8)
            Divider()
            if let page {
                EntryWebView(html: html(of: page), data: store.data, pdfArt: pdfArt, anchor: anchor,
                             onHeight: { measured in
                    laidOutHeight = measured
                    onMeasured?(measured)
                }, onLink: { url in
                    switch PageView.destination(for: url, system: page.system) {
                    case let .page(next): open(next)
                    case let .browser(web): openURL(web)
                    case .ignored: break
                    }
                })
                // The iPad fits the popover into the room beside the link; the page then scrolls in what is left.
                .frame(width: Self.width)
                .frame(minHeight: 60, idealHeight: Self.fitted(laidOutHeight ?? height ?? 160),
                       maxHeight: Self.fitted(laidOutHeight ?? height ?? 160))
            } else {
                ContentUnavailableView("Not in the Field Guide", systemImage: "questionmark.square.dashed")
                    .frame(width: Self.width, height: 160)
                    .onAppear { onMeasured?(160) }
            }
        }
        .frame(width: Self.width)
        .presentationBackground(.background)
    }

    /// A page's height as the popover shows it: whole up to the limit, then scrolling.
    static func fitted(_ height: CGFloat) -> CGFloat {
        min(max(height, 60), maximumHeight)
    }

    /// The page as Open shows it: an ancestry's or class's Details for a link to them, else its overview.
    private func html(of page: EntryPage) -> String {
        guard case .entry(_, .details, _) = link else { return page.html }
        return PageTabs(page: page, bookLore: nil, detailsLore: sourcebooks.detailsHTML(of: page.id)).html(for: .details)
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
