import SwiftUI
import WebKit

/// A tapped in-app link and where it is in the web view, from the page's click script, which a page's web view
/// runs so its links open in a popover (`PeekView`); and the script that reports a page's height, for sizing one.
struct LinkPeek {
    static let peekHandler = "peek"
    static let heightHandler = "height"
    let url: URL
    let rect: CGRect

    init?(message body: Any) {
        guard let body = body as? [String: Any], let href = body["href"] as? String, let url = URL(string: href),
              let left = body["x"] as? Double, let top = body["y"] as? Double,
              let width = body["w"] as? Double, let height = body["h"] as? Double else { return nil }
        self.url = url
        rect = CGRect(x: left, y: top, width: width, height: height)
    }

    private static let clickScript = """
        document.addEventListener("click", event => {
          const link = event.target.closest('a[href^="entry:"], a[href^="trait:"]');
          if (!link) return;
          event.preventDefault();
          const r = link.getBoundingClientRect();
          webkit.messageHandlers.peek.postMessage(
            {href: link.getAttribute("href"), x: r.x, y: r.y, w: r.width, h: r.height});
        }, true);
        """

    private static let heightScript = """
        const report = () => webkit.messageHandlers.height.postMessage(Math.ceil(document.body.getBoundingClientRect().height));
        addEventListener("load", report);
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
