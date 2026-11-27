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
    /// The downloaded files' names, by Lorespire file ID.
    let files: [Int: String]

    static let imagesPath = "fieldguide:///images/lorespire/"

    /// The Lorespire file IDs that some HTML links to or shows.
    static func fileIDs(in html: String) -> Set<Int> {
        Set(html.matches(of: /tiki-download_file\.php\?fileId=(\d+)/).compactMap { Int($0.1) })
    }

    /// An `entry:` link to an entry, its id percent-encoded.
    static func entryLink(_ id: String) -> String {
        "entry:" + (id.addingPercentEncoding(withAllowedCharacters: entryCharacters) ?? id)
    }

    private static let entryCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-~"))

    func rewrite(_ html: String, in document: String) -> String {
        html.replacing(/(href|src)="([^"]*)"/) { match in
            let value = String(match.2).replacingOccurrences(of: "&amp;", with: "&")
            let target = match.1 == "src" ? source(for: value) : target(for: value, in: document)
            return "\(match.1)=\"\(target.replacingOccurrences(of: "&", with: "&amp;"))\""
        }
    }

    private func source(for value: String) -> String {
        guard let path = sitePath(value) else { return value }
        if let file = fileID(in: path).flatMap({ files[$0] }) { return Self.imagesPath + file }
        return Lorespire.host + path
    }

    private func target(for value: String, in document: String) -> String {
        if value.hasPrefix("#") {
            return headings[document]?[String(value.dropFirst())].map(Self.entryLink) ?? value
        }
        guard let path = sitePath(value) else { return value }
        if path.hasPrefix("tiki-index.php?"), let page = parameter("page", in: path) {
            return pageTarget(page, fragment: fragment(of: path))
        }
        return Lorespire.host + path
    }

    private func pageTarget(_ page: String, fragment: String?) -> String {
        let document = documents.first { $0.opens(page) }?.id ?? pages[page].flatMap(document(holding:))
        if let fragment, let document, let entry = headings[document]?[fragment] { return Self.entryLink(entry) }
        if let entry = pages[page] ?? document.flatMap({ firstEntries[$0] }) { return Self.entryLink(entry) }
        return Lorespire.pageURL(page).absoluteString + (fragment.map { "#" + $0 } ?? "")
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
