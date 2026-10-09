import AppKit
import FieldGuideKit
import Foundation
import PDFKit

/// The Player Core page of area diagrams for a system: which book, which page and the region to keep.
struct AreaDiagramPage: Sendable {
    var system: GameSystem
    /// The folder in Scrollkeeper's `Files` holding the book.
    var folder: String
    var pageLabel: String
    /// The region to keep, as fractions of the page from its top left.
    var region: CGRect
    var source: String

    static let all = [
        AreaDiagramPage(system: .pathfinder, folder: "Pathfinder Player Core", pageLabel: "429",
                        region: CGRect(x: 0.09, y: 0.08, width: 0.775, height: 0.85),
                        source: "Pathfinder Player Core"),
        AreaDiagramPage(system: .starfinder, folder: "Starfinder Player Core", pageLabel: "421",
                        region: CGRect(x: 0.095, y: 0.055, width: 0.78, height: 0.855),
                        source: "Starfinder Player Core")
    ]
}

/// Renders the area diagrams from the Player Core PDFs into images and GM Screen entries.
struct AreaDiagrams {
    let scrollkeeperFiles: URL
    let images: URL
    var pages = AreaDiagramPage.all
    /// Rendering at three times the page's resolution keeps the labels sharp on a large iPad.
    static let scale: CGFloat = 3

    func rows() -> [EntryRow] {
        pages.compactMap { page in
            guard let pdf = book(in: scrollkeeperFiles.appendingPathComponent(page.folder)),
                  let stored = render(page, from: pdf) else { return nil }
            return row(page, image: stored)
        }
    }

    /// The largest PDF in the folder: the single-file book rather than any extract.
    func book(in folder: URL) -> URL? {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.filter { $0.pathExtension.lowercased() == "pdf" }.max { size(of: $0) < size(of: $1) }
    }

    private func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    /// The page region at `scale` times the page's resolution, stored as `gm-screen/areas-<system>.webp` (or PNG
    /// without `cwebp`); nil when the page isn't in the book.
    func render(_ diagram: AreaDiagramPage, from pdf: URL) -> String? {
        guard let document = PDFDocument(url: pdf),
              let page = (0..<document.pageCount).lazy.compactMap(document.page(at:))
                .first(where: { $0.label == diagram.pageLabel }),
              let png = Self.png(of: page, region: diagram.region, scale: Self.scale) else { return nil }
        let folder = images.appendingPathComponent("gm-screen")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "areas-\(diagram.system.rawValue)"
        let pngURL = folder.appendingPathComponent("\(name).png")
        guard (try? png.write(to: pngURL)) != nil else { return nil }
        let webp = folder.appendingPathComponent("\(name).webp")
        guard ArtScaler.scale(pngURL, to: webp, maximumSize: .max) else { return "gm-screen/\(name).png" }
        try? FileManager.default.removeItem(at: pngURL)
        return "gm-screen/\(name).webp"
    }

    static func png(of page: PDFPage, region: CGRect, scale: CGFloat) -> Data? {
        let bounds = page.bounds(for: .cropBox)
        let crop = CGRect(x: bounds.minX + region.minX * bounds.width,
                          y: bounds.maxY - region.maxY * bounds.height,
                          width: region.width * bounds.width, height: region.height * bounds.height)
        let width = Int(crop.width * scale), height = Int(crop.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -crop.minX, y: -crop.minY)
        page.draw(with: .cropBox, to: context)
        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private func row(_ page: AreaDiagramPage, image: String) -> EntryRow {
        let html = "<header class=\"entry-header\"><div><h1>Areas</h1><p class=\"subtitle\">Playing the Game</p></div>"
            + "</header><section class=\"description\"><img class=\"diagram\" src=\"\(HTML.imageURL(image))\" "
            + "alt=\"Emanation, burst, cone and line areas\"></section>"
            + "<footer class=\"source\">\(HTML.escape(page.source)) page \(page.pageLabel)</footer>"
        return EntryRow(
            id: "fieldguide.\(page.system.rawValue).areas", system: page.system, category: .gmScreen, name: "Areas",
            level: nil, subtitle: "Playing the Game", image: image, facets: [.section: ["Playing the Game"]],
            html: html, text: "Areas emanation burst cone line diagrams", traitSlugs: []
        )
    }
}
