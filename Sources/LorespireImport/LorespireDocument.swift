import Foundation

/// A Lorespire page that the download keeps: one whole guide, laid out on a single wiki page.
public struct LorespireDocument: Sendable, Equatable {
    public enum System: String, Sendable, Codable {
        case pathfinder = "pf2e"
        case starfinder = "sf2e"
        case both
    }

    /// The local name: the document is saved as `<id>.html`.
    public let id: String
    /// The wiki page's name, as in `tiki-index.php?page=<page>`.
    public let page: String
    public let system: System
    /// Other wiki pages whose whole content this document holds, so that links to them open it.
    public let aliases: [String]
    /// The part of the guide that all its pages belong to; nil when each top-level page is a part of its own.
    public let part: String?
    /// Whether its pages become entries; the licenses page doesn't.
    public let isGuide: Bool

    public init(id: String, page: String, system: System, aliases: [String] = [], part: String? = nil,
                isGuide: Bool = true) {
        self.id = id
        self.page = page
        self.system = system
        self.aliases = aliases
        self.part = part
        self.isGuide = isGuide
    }

    public var fileName: String { id + ".html" }
    public var url: URL { Lorespire.pageURL(page) }

    /// Whether a link to the wiki page `name` opens this document at its top.
    func opens(_ name: String) -> Bool { name == page || aliases.contains(name) }
}

public enum Lorespire {
    public static let host = "https://lorespire.paizo.com/"

    /// The guides that Field Guide keeps offline. The Starfinder Society (first edition) guide is left out.
    ///
    /// Each guide's Complete Compilation holds its introduction, core guide, player options, GM options and
    /// supplemental materials. The Licenses and Trademarks page carries the Open Game License and Paizo's
    /// trademark notice that come with them.
    public static let documents = [
        LorespireDocument(id: "pfs2-guide", page: "pfs2guide._.Complete-Compilation", system: .pathfinder,
                          aliases: guideAliases("pfs2guide")),
        LorespireDocument(id: "sfs2-guide", page: "sfs2guide._.Complete-Compilation", system: .starfinder,
                          aliases: guideAliases("sfs2guide")),
        LorespireDocument(id: "vo-handbook", page: "vohandbook._.Full-Handbook", system: .both,
                          part: "Venture-Officer Handbook"),
        LorespireDocument(id: "licenses", page: "site._.Licenses-And-Trademarks", system: .both, isGuide: false)
    ]

    public static func pageURL(_ page: String) -> URL {
        URL(string: host + "tiki-index.php?page=" + page)!
    }

    public static func fileURL(_ fileID: Int) -> URL {
        URL(string: host + "tiki-download_file.php?fileId=\(fileID)")!
    }

    /// The single-page layouts that the Complete Compilation contains.
    private static func guideAliases(_ guide: String) -> [String] {
        ["Full-Guide", "All-Supplemental-Materials", "Supplemental-Materials"].map { "\(guide)._.\($0)" }
    }
}
