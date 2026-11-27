import FieldGuideKit
import Foundation
import LorespireImport

/// The Organized Play guides of a Lorespire download (`LorespireLibrary`) as entries: one per page of the original
/// wiki, in guide order, under the part of the guide it belongs to. Each system gets its own guide and the
/// Venture-Officer Handbook. The pages' images go to `Images/lorespire/`, and the licenses page to `Licenses/`.
struct OrganizedPlay {
    static let licensesFile = "Lorespire Licenses and Trademarks.md"
    static let imagesFolder = "lorespire"

    let library: LorespireLibrary
    /// The entries' icons, by the Rexard picture `LorespireIcons` picks; "" for none.
    var icon: (LorespireEntry) -> String = { _ in "" }

    /// Writes the images and the licenses into `output`, and returns the entries.
    func importing(into output: URL) throws -> [EntryRow] {
        let rows = try GameSystem.allCases.flatMap { system in
            try library.entries(for: Self.lorespireSystem(system)).map {
                Self.row($0, system: system, icon: icon($0))
            }
        }
        try copyFiles(to: output.appendingPathComponent("Images").appendingPathComponent(Self.imagesFolder))
        let licenses = output.appendingPathComponent("Licenses")
        try FileManager.default.createDirectory(at: licenses, withIntermediateDirectories: true)
        try library.licenses().write(to: licenses.appendingPathComponent(Self.licensesFile), atomically: true,
                                     encoding: .utf8)
        return rows
    }

    static func row(_ entry: LorespireEntry, system: GameSystem, icon: String = "") -> EntryRow {
        let header = "<header class=\"entry-header\">\(HTML.picture(icon, className: "art"))"
            + "<div><h1>\(HTML.escape(entry.name))</h1>"
            + "<p class=\"subtitle\">\(HTML.escape(entry.part))</p></div></header>"
        let body = "<section class=\"description journal\">\(entry.html)</section>"
        let source = "<footer class=\"source\">\(HTML.link("Lorespire", to: entry.source.absoluteString))</footer>"
        return EntryRow(
            id: entry.id, system: system, category: .organizedPlay, name: entry.name, level: nil,
            subtitle: entry.part, image: icon, facets: [.section: [entry.part]], html: header + body + source,
            text: HTML.plainText(header + body), traitSlugs: [], sortKey: String(format: "%04d", entry.order)
        )
    }

    private static func lorespireSystem(_ system: GameSystem) -> LorespireDocument.System {
        switch system {
        case .pathfinder: .pathfinder
        case .starfinder: .starfinder
        }
    }

    private func copyFiles(to folder: URL) throws {
        let manager = FileManager.default
        try? manager.removeItem(at: folder)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in (try? manager.contentsOfDirectory(atPath: library.filesFolder.path)) ?? [] {
            try manager.copyItem(at: library.filesFolder.appendingPathComponent(name),
                                 to: folder.appendingPathComponent(name))
        }
    }
}
