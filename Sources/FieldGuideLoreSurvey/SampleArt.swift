import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import SourcebookLoreTestSupport

/// Writing the sample sourcebook failed: a creature's picture is missing, or the PDF couldn't be written.
struct SampleError: Error, CustomStringConvertible {
    let description: String
}

/// Writes the sample sourcebook to `file`, each creature beside its picture from the `paizo-blog` folder in the
/// Community Use Package artwork folder `art`. Every picture must be there, so the published sample has them all.
func writeSample(to file: URL, art: URL) throws {
    let folder = art.appending(path: "paizo-blog")
    var pictures: [String: CGImage] = [:]
    for creature in SampleSourcebook.creatures {
        guard let image = sampleImage(at: folder.appending(path: creature.art)) else {
            throw SampleError(description: "Writing the sample failed: \(creature.name)'s picture, "
                              + "\(creature.art), is missing from \(folder.path).")
        }
        pictures[creature.name] = image
    }
    guard SampleSourcebook.document(art: pictures)?.write(to: file) == true else {
        throw SampleError(description: "Writing the sample failed: couldn't write \(file.path).")
    }
}

/// The picture at `file`, at most 800 pixels on its long side, which prints sharply at the size the sample uses.
private func sampleImage(at file: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
    let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 800,
                   kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
}
