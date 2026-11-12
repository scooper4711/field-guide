import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import SourcebookLoreTestSupport

/// Writing a sample sourcebook failed: a creature's picture or the action icons' font is missing, or the PDF
/// couldn't be written.
struct SampleError: Error, CustomStringConvertible {
    let description: String
}

/// Writes each game's sample sourcebook into `folder` as "<title>.pdf", each creature beside its picture from the
/// `paizo-blog` folder in the Community Use Package artwork folder `art`. Every picture a sample names must be there,
/// so the published samples have them all. Their action icons are drawn in Paizo's Pathfinder-Icons font, the file
/// `icons`, which goes into each PDF whole.
func writeSamples(to folder: URL, art: URL, icons: URL) throws {
    guard let font = try? Data(contentsOf: icons) else {
        throw SampleError(description: "Writing the samples failed: the action icons' font, \(icons.path), is missing.")
    }
    for var sample in SampleSourcebook.all {
        sample.actionIcons = font
        try write(sample, to: folder.appending(path: "\(sample.title).pdf"), art: art.appending(path: "paizo-blog"))
    }
}

private func write(_ sample: SampleSourcebook, to file: URL, art folder: URL) throws {
    var pictures: [String: CGImage] = [:]
    for creature in sample.creatures {
        guard let name = creature.art else { continue }
        guard let image = sampleImage(at: folder.appending(path: name)) else {
            throw SampleError(description: "Writing \(sample.title) failed: \(creature.name)'s picture, "
                              + "\(name), is missing from \(folder.path).")
        }
        pictures[creature.name] = image
    }
    guard let data = sample.data(art: pictures) else {
        throw SampleError(description: "Writing \(sample.title) failed: couldn't draw it, or put the action icons' "
                          + "font into it.")
    }
    do {
        try data.write(to: file)
    } catch {
        throw SampleError(description: "Writing \(sample.title) failed: couldn't write \(file.path): \(error).")
    }
}

/// The picture at `file`, at most 800 pixels on its long side, which prints sharply at the size the sample uses.
private func sampleImage(at file: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
    let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 800,
                   kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
}
