import Foundation

/// The Rexard pictures for the Organized Play guides' entries (`lorespire-icons.json`), by their paths in the packs.
/// Lorespire's pages have no Foundry icon to match, so the choice is made by hand: a picture for some pages, by the
/// wiki page's own name (the part after its book, so `popguide._.Boons` and `pfs2guide._.Boons` share one), and one
/// for each part of the guides.
public struct LorespireIcons: Codable, Sendable, Equatable {
    public var parts: [String: String]
    public var pages: [String: String]

    public init(parts: [String: String] = [:], pages: [String: String] = [:]) {
        self.parts = parts
        self.pages = pages
    }

    /// Reads the file, or none when it is missing.
    public static func load(from url: URL) throws -> LorespireIcons {
        guard FileManager.default.fileExists(atPath: url.path) else { return LorespireIcons() }
        return try JSONDecoder().decode(LorespireIcons.self, from: Data(contentsOf: url))
    }

    /// The picture for a wiki page in a part, or nil for none.
    func file(forPage page: String, part: String) -> String? {
        let name = page.components(separatedBy: "._.").last ?? page
        return pages[name] ?? parts[part]
    }
}
