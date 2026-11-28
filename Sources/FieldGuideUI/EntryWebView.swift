import FieldGuideKit
import SwiftUI
import WebKit

/// Shows an entry page's HTML with the app's stylesheet. Images, fonts and the stylesheet come through the
/// `fieldguide:` scheme; every link the user taps is handed to `onLink` instead of loading, except a link to a
/// heading on the page, which scrolls to it. The page opens scrolled to the heading `anchor` names, if any.
@MainActor
struct EntryWebView {
    let html: String
    let data: DataLocation
    let pdfArt: ArtModel
    var anchor = ""
    /// Spike: when set, in-app links report where they were tapped instead of following.
    var onPeek: ((URL, CGRect) -> Void)?
    /// Spike: the page's content height once laid out, for sizing a popover.
    var onHeight: ((CGFloat) -> Void)?
    let onLink: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLink: onLink) }

    func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        LinkPeek.install(in: configuration.userContentController, coordinator: context.coordinator,
                         peeks: onPeek != nil, measures: onHeight != nil)
        configuration.setURLSchemeHandler(ResourceSchemeHandler(data: data, pdfArt: pdfArt),
                                          forURLScheme: "fieldguide")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        #else
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        return webView
    }

    func update(_ webView: WKWebView, context: Context) {
        context.coordinator.onLink = onLink
        context.coordinator.onPeek = onPeek
        context.coordinator.onHeight = onHeight
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(PageTemplate.document(body: html, anchor: anchor),
                               baseURL: URL(string: "fieldguide:///"))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLink: (URL) -> Void
        var onPeek: ((URL, CGRect) -> Void)?
        var onHeight: ((CGFloat) -> Void)?
        var loadedHTML: String?

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == LinkPeek.peekHandler, let peek = LinkPeek(message: message.body) {
                onPeek?(peek.url, peek.rect)
            } else if message.name == LinkPeek.heightHandler, let height = message.body as? Double {
                onHeight?(CGFloat(height))
            }
        }

        init(onLink: @escaping (URL) -> Void) {
            self.onLink = onLink
        }

        func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated,
                  !PageTemplate.isAnchor(url) else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            onLink(url)
        }
    }
}

#if os(iOS)
extension EntryWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateUIView(_ webView: WKWebView, context: Context) { update(webView, context: context) }
}
#else
extension EntryWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateNSView(_ webView: WKWebView, context: Context) { update(webView, context: context) }
}
#endif

/// Wraps a page body in a document that loads the stylesheet.
enum PageTemplate {
    /// Whether a link goes to a heading of the page itself (`#id`), which the web view scrolls to.
    static func isAnchor(_ url: URL) -> Bool {
        url.scheme == "fieldguide" && url.fragment != nil && (url.path.isEmpty || url.path == "/")
    }

    /// `body` as a page, which scrolls to the element with the id `anchor` once loaded; "" stays at the top.
    static func document(body: String, anchor: String = "") -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="fieldguide:///style/entry.css">\(scrolling(to: anchor))</head>
        <body>\(body)</body></html>
        """
    }

    /// A script that scrolls to `anchor` once the page and its images are laid out. The id goes in percent-encoded,
    /// so no id can break out of the script's string.
    static func scrolling(to anchor: String) -> String {
        guard !anchor.isEmpty,
              let encoded = anchor.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return "" }
        return "<script>addEventListener(\"load\", () => document.getElementById(decodeURIComponent(\"\(encoded)\"))"
            + "?.scrollIntoView())</script>"
    }
}

/// Serves `fieldguide:///images/…`, `fieldguide:///fonts/…` and `fieldguide:///style/entry.css`; a creature's art
/// from the user's PDFs for `fieldguide:///images/creature/<key>`, and an item's for
/// `fieldguide:///images/item/…` (`ItemArtPath`), else its icon.
@MainActor
final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    /// Creature and item art on a page is drawn this large on its long side.
    static let artPixels = 1024
    static let creaturePrefix = "/images/creature/"
    static let imagesPrefix = "/images/"

    let data: DataLocation
    let pdfArt: ArtModel
    /// Requests the web view has stopped waiting for, which must not be answered.
    private var stopped: Set<ObjectIdentifier> = []

    init(data: DataLocation, pdfArt: ArtModel) {
        self.data = data
        self.pdfArt = pdfArt
    }

    func webView(_: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let path = url.path.removingPercentEncoding ?? url.path
        if path.hasPrefix(Self.creaturePrefix) {
            let key = String(path.dropFirst(Self.creaturePrefix.count))
            Task {
                let body = await pdfArt.png(forCreature: key, maxPixels: Self.artPixels)
                answer(task, url: url, body: body, mimeType: "image/png")
            }
            return
        }
        if let item = ItemArtPath(path: String(path.dropFirst(Self.imagesPrefix.count))) {
            Task { await answerItem(item, task: task, url: url) }
            return
        }
        let file = file(for: url)
        answer(task, url: url, body: file.flatMap { try? Data(contentsOf: $0) },
               mimeType: file.map(Self.mimeType(of:)) ?? "")
    }

    /// The item's art from the user's decks, else its stored icon.
    private func answerItem(_ item: ItemArtPath, task: any WKURLSchemeTask, url: URL) async {
        if let body = await pdfArt.png(forItem: item, maxPixels: Self.artPixels) {
            answer(task, url: url, body: body, mimeType: "image/png")
            return
        }
        let icon = item.fallback.isEmpty || item.fallback.contains("..") ? nil
            : data.images.appendingPathComponent(item.fallback)
        answer(task, url: url, body: icon.flatMap { try? Data(contentsOf: $0) },
               mimeType: icon.map(Self.mimeType(of:)) ?? "")
    }

    func webView(_: WKWebView, stop task: any WKURLSchemeTask) {
        stopped.insert(ObjectIdentifier(task))
    }

    private func answer(_ task: any WKURLSchemeTask, url: URL, body: Data?, mimeType: String) {
        guard stopped.remove(ObjectIdentifier(task)) == nil else { return }
        guard let body else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: body.count,
                                    textEncodingName: nil))
        task.didReceive(body)
        task.didFinish()
    }

    func file(for url: URL) -> URL? {
        let path = url.path.removingPercentEncoding ?? url.path
        if path == "/style/entry.css" { return Bundle.module.url(forResource: "entry", withExtension: "css") }
        for (prefix, folder) in [("/images/", data.images), ("/fonts/", data.fonts)] where path.hasPrefix(prefix) {
            let relative = String(path.dropFirst(prefix.count))
            guard !relative.contains("..") else { return nil }
            return folder.appendingPathComponent(relative)
        }
        return nil
    }

    static func mimeType(of file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "css": "text/css"
        case "webp": "image/webp"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "svg": "image/svg+xml"
        case "woff2": "font/woff2"
        case "ttf": "font/ttf"
        default: "application/octet-stream"
        }
    }
}

/// Spike: a tapped in-app link and where it is in the web view, from the page's click script.
struct LinkPeek {
    static let peekHandler = "peek"
    static let heightHandler = "height"
    let url: URL
    let rect: CGRect

    init?(message body: Any) {
        guard let body = body as? [String: Any], let href = body["href"] as? String, let url = URL(string: href),
              let x = body["x"] as? Double, let y = body["y"] as? Double,
              let width = body["w"] as? Double, let height = body["h"] as? Double else { return nil }
        self.url = url
        rect = CGRect(x: x, y: y, width: width, height: height)
    }

    private static let clickScript = """
        document.addEventListener("click", event => {
          const link = event.target.closest('a[href^="entry:"], a[href^="trait:"]');
          if (!link) return;
          event.preventDefault();
          const r = link.getBoundingClientRect();
          webkit.messageHandlers.peek.postMessage({href: link.getAttribute("href"), x: r.x, y: r.y, w: r.width, h: r.height});
        }, true);
        """

    private static let heightScript = """
        const report = () => webkit.messageHandlers.height.postMessage(document.documentElement.scrollHeight);
        addEventListener("load", report); report();
        """

    @MainActor
    static func install(in controller: WKUserContentController, coordinator: EntryWebView.Coordinator,
                        peeks: Bool, measures: Bool) {
        let handler = WeakHandler(coordinator)
        if peeks {
            controller.add(handler, name: peekHandler)
            controller.addUserScript(WKUserScript(source: clickScript, injectionTime: .atDocumentEnd,
                                                  forMainFrameOnly: true))
        }
        if measures {
            controller.add(handler, name: heightHandler)
            controller.addUserScript(WKUserScript(source: heightScript, injectionTime: .atDocumentEnd,
                                                  forMainFrameOnly: true))
        }
    }
}

/// Keeps the web view's message handlers from holding the coordinator.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
