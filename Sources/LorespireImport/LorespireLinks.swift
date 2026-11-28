import Foundation

/// Points a guide entry's links and images at the app: other guide entries of the same system as `entry:` links,
/// the downloaded images as `fieldguide:///images/lorespire/…`, and everything else at Lorespire on the web.
struct LorespireLinkRewriter {
    let documents: [LorespireDocument]
    /// The entries' ids by their wiki page.
    let pages: [String: String]
    /// The entries' ids by document id, then by the ids of the headings they hold.
    let headings: [String: [String: String]]
    /// The first entry of each document, by document id.
    let firstEntries: [String: String]
    /// `<entry id>#<heading id>` for each entry's own heading and those of the empty pages folded into it, which
    /// a link opens at the top: the entry's page leaves them out.
    let starts: Set<String>
    /// The downloaded files' names, by Lorespire file ID.
    let files: [Int: String]

    static let imagesPath = "fieldguide:///images/lorespire/"
    /// The fragment the app reads as an entry's Details tab (FieldGuideKit's `EntryLink`), never a heading.
    static let detailsFragment = "details"

    /// The Lorespire file IDs that some HTML links to or shows.
    static func fileIDs(in html: String) -> Set<Int> {
        Set(html.matches(of: /tiki-download_file\.php\?fileId=(\d+)/).compactMap { Int($0.1) })
    }

    /// An `entry:` link to an entry, or to a heading on its page, percent-encoded.
    static func entryLink(_ id: String, heading: String = "") -> String {
        let link = "entry:" + encoded(id)
        return heading.isEmpty || heading == detailsFragment ? link : link + "#" + encoded(heading)
    }

    private static func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: entryCharacters) ?? text
    }

    private static let entryCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-~"))

    /// Where a link is: the document and the entry it is in.
    struct Place {
        let document: String
        let entry: String
    }

    func rewrite(_ html: String, at place: Place) -> String {
        html.replacing(/(href|src)="([^"]*)"/) { match in
            let value = String(match.2).replacingOccurrences(of: "&amp;", with: "&")
            let target = match.1 == "src" ? source(for: value) : target(for: value, at: place)
            return "\(match.1)=\"\(target.replacingOccurrences(of: "&", with: "&amp;"))\""
        }
    }

    private func source(for value: String) -> String {
        guard let path = sitePath(value) else { return value }
        if let file = fileID(in: path).flatMap({ files[$0] }) { return Self.imagesPath + file }
        return Lorespire.host + path
    }

    private func target(for value: String, at place: Place) -> String {
        if value.hasPrefix("#") {
            let fragment = String(value.dropFirst())
            return headings[place.document]?[fragment].map { link(to: $0, fragment: fragment, from: place) } ?? value
        }
        guard let path = sitePath(value) else { return value }
        if path.hasPrefix("tiki-index.php?"), let page = parameter("page", in: path) {
            return pageTarget(page, fragment: fragment(of: path), from: place)
        }
        return Lorespire.host + path
    }

    private func pageTarget(_ page: String, fragment: String?, from place: Place) -> String {
        let document = documents.first { $0.opens(page) }?.id ?? pages[page].flatMap(document(holding:))
        if let fragment, let document, let entry = headings[document]?[fragment] {
            return link(to: entry, fragment: fragment, from: place)
        }
        if let entry = pages[page] ?? document.flatMap({ firstEntries[$0] }) { return Self.entryLink(entry) }
        return Lorespire.pageURL(page).absoluteString + (fragment.map { "#" + $0 } ?? "")
    }

    /// A link to a heading: within the page when the heading is in the entry the link is in, else to the heading on
    /// its entry's page, or to the page's top for the entry's own heading.
    private func link(to entry: String, fragment: String, from place: Place) -> String {
        if entry == place.entry { return "#" + fragment }
        return Self.entryLink(entry, heading: starts.contains(entry + "#" + fragment) ? "" : fragment)
    }

    private func document(holding entry: String) -> String? {
        headings.first { $0.value.values.contains(entry) }?.key
    }

    private func fileID(in path: String) -> Int? {
        guard path.hasPrefix("tiki-download_file.php?") else { return nil }
        return parameter("fileId", in: path).flatMap(Int.init)
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
