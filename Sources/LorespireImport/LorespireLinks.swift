import Foundation

/// A heading of a downloaded document, for its table of contents.
public struct LorespireHeading: Codable, Sendable, Equatable {
    public let level: Int
    /// The heading's `id`, so `<document>.html#<id>` opens it.
    public let id: String
    public let title: String
}

/// Where a link to a wiki page lands in the download.
struct LorespireAnchor: Equatable {
    let document: String
    let id: String
}

enum LorespireHeadings {
    /// The `h1`–`h3` headings that have an `id`, in order.
    static func outline(of html: String) -> [LorespireHeading] {
        headings(in: html).filter { $0.level <= 3 }
            .map { LorespireHeading(level: $0.level, id: $0.id, title: LorespireText.plain($0.inner)) }
    }

    /// Where each wiki page starts in the compilations: a compilation's heading for a section links to that
    /// section's own page. The first heading that links to a page wins.
    static func anchors(in documents: [(id: String, content: String)]) -> [String: LorespireAnchor] {
        var anchors: [String: LorespireAnchor] = [:]
        for document in documents {
            for heading in headings(in: document.content) {
                for match in heading.inner.matches(of: /page=([^"#&]+)/) where anchors[String(match.1)] == nil {
                    anchors[String(match.1)] = LorespireAnchor(document: document.id, id: heading.id)
                }
            }
        }
        return anchors
    }

    /// A heading as written: its level, its `id` and the HTML inside it.
    private struct RawHeading {
        let level: Int
        let id: String
        let inner: String
    }

    private static func headings(in html: String) -> [RawHeading] {
        html.matches(of: /<h([1-6])\b[^>]*\bid="([^"]+)"[^>]*>(.*?)<\/h\1>/.dotMatchesNewlines()).map {
            RawHeading(level: Int($0.1) ?? 1, id: String($0.2), inner: String($0.3))
        }
    }
}

/// Points a document's links and images at the download: other downloaded documents, the saved files, and
/// Lorespire itself for the pages that weren't downloaded.
struct LorespireLinkRewriter {
    let documents: [LorespireDocument]
    let anchors: [String: LorespireAnchor]
    /// The saved files' paths, relative to the documents, by Lorespire file ID.
    let files: [Int: String]

    /// The Lorespire file IDs that some HTML links to or shows.
    static func fileIDs(in html: String) -> Set<Int> {
        Set(html.matches(of: /tiki-download_file\.php\?fileId=(\d+)/).compactMap { Int($0.1) })
    }

    func rewrite(_ html: String, in document: String) -> String {
        html.replacing(/(href|src)="([^"]*)"/) { match in
            let target = target(for: String(match.2).replacingOccurrences(of: "&amp;", with: "&"), in: document)
            return "\(match.1)=\"\(target.replacingOccurrences(of: "&", with: "&amp;"))\""
        }
    }

    private func target(for value: String, in document: String) -> String {
        if value.hasPrefix("#") { return value }
        guard let path = sitePath(value) else { return value }
        if path.hasPrefix("tiki-index.php?"), let page = parameter("page", in: path) {
            return pageTarget(page, fragment: fragment(of: path), from: document)
        }
        if path.hasPrefix("tiki-download_file.php?"), let fileID = parameter("fileId", in: path).flatMap(Int.init),
           let file = files[fileID] {
            return file
        }
        return Lorespire.host + path
    }

    private func pageTarget(_ page: String, fragment: String?, from current: String) -> String {
        if let document = documents.first(where: { $0.opens(page) }) {
            return reference(to: document.id, fragment: fragment, from: current)
        }
        if let anchor = anchors[page] {
            return reference(to: anchor.document, fragment: fragment ?? anchor.id, from: current)
        }
        return Lorespire.pageURL(page).absoluteString + (fragment.map { "#" + $0 } ?? "")
    }

    private func reference(to document: String, fragment: String?, from current: String) -> String {
        if document == current, let fragment { return "#" + fragment }
        return document + ".html" + (fragment.map { "#" + $0 } ?? "")
    }

    /// The path of a link into Lorespire, relative to the site's root, or nil for a link elsewhere.
    private func sitePath(_ value: String) -> String? {
        for prefix in [Lorespire.host, "http://lorespire.paizo.com/", "/"] where value.hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count))
        }
        return value.contains(":") ? nil : value
    }

    private func parameter(_ name: String, in path: String) -> String? {
        let query = path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? path
        return URLComponents(string: query)?.queryItems?.first { $0.name == name }?.value
    }

    private func fragment(of path: String) -> String? {
        path.split(separator: "#", maxSplits: 1).dropFirst().first.map(String.init)
    }
}
