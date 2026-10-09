import FieldGuideKit
import SwiftUI
import WebKit

/// Shows an entry page's HTML with the app's stylesheet. Images, fonts and the stylesheet come through the
/// `fieldguide:` scheme; `entry:` and `trait:` links are handed to `onLink` instead of loading.
@MainActor
struct EntryWebView {
    let html: String
    let data: DataLocation
    let onLink: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLink: onLink) }

    func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(ResourceSchemeHandler(data: data), forURLScheme: "fieldguide")
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
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(PageTemplate.document(body: html), baseURL: URL(string: "fieldguide:///"))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLink: (URL) -> Void
        var loadedHTML: String?

        init(onLink: @escaping (URL) -> Void) {
            self.onLink = onLink
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated else {
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
    static func document(body: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="fieldguide:///style/entry.css"></head>
        <body>\(body)</body></html>
        """
    }
}

/// Serves `fieldguide:///images/…`, `fieldguide:///fonts/…` and `fieldguide:///style/entry.css`.
@MainActor
final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    let data: DataLocation

    init(data: DataLocation) {
        self.data = data
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, let file = file(for: url), let body = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(url: url, mimeType: Self.mimeType(of: file), expectedContentLength: body.count,
                                   textEncodingName: nil)
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}

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
        default: "application/octet-stream"
        }
    }
}
