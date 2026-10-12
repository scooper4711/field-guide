import CoreGraphics
import Foundation
import ImageIO

/// A 256-bit difference hash: the picture in gray at 17×16 pixels, one bit per pair of neighbors in a row, set
/// where the right one is brighter. The same picture at another size or in another format differs in few bits.
struct DifferenceHash: Hashable, Sendable {
    static let wordCount = 4
    var words: [UInt64]

    func distance(to other: DifferenceHash) -> Int {
        zip(words, other.words).reduce(0) { $0 + ($1.0 ^ $1.1).nonzeroBitCount }
    }

    var hex: String {
        words.map { String(format: "%016llx", $0) }.joined()
    }

    init(words: [UInt64]) {
        self.words = words
    }

    init?(hex: String) {
        guard hex.count == Self.wordCount * 16 else { return nil }
        let characters = Array(hex)
        let words = (0..<Self.wordCount).compactMap { UInt64(String(characters[$0 * 16..<($0 + 1) * 16]), radix: 16) }
        guard words.count == Self.wordCount else { return nil }
        self.words = words
    }
}

/// Draws pictures small and gray and hashes them, whole and in parts.
enum ImageHashing {
    /// A part of a picture: its size relative to the whole, and where it sits (0 left or top, 1 right or bottom).
    struct Crop: Sendable {
        var scale: Double
        var horizontal: Double
        var vertical: Double
    }

    /// The parts of a source picture that are hashed, since Foundry crops some of its icons: the whole, centered
    /// crops, and the corners.
    static let crops: [Crop] = [1, 0.9, 0.8, 0.7, 0.6].map { Crop(scale: $0, horizontal: 0.5, vertical: 0.5) }
        + [0.8, 0.65].flatMap { scale in
            [0.0, 1].flatMap { left in [0.0, 1].map { Crop(scale: scale, horizontal: left, vertical: $0) } }
        }

    private static let hashWidth = 16

    /// The picture at `url` in gray, at most 256 pixels on its long side, over a black (0) or white (1)
    /// background, since icons may or may not be transparent; nil when it can't be read.
    static func gray(of url: URL, background: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(gray: background, alpha: 1)
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }

    /// The hash of a part of a gray picture.
    static func hash(of image: CGImage, crop: Crop = crops[0]) -> DifferenceHash {
        let width = Double(image.width) * crop.scale
        let height = Double(image.height) * crop.scale
        let rect = CGRect(x: (Double(image.width) - width) * crop.horizontal,
                          y: (Double(image.height) - height) * crop.vertical,
                          width: width, height: height).integral
        let part = image.cropping(to: rect) ?? image
        let pixels = samples(of: part, width: hashWidth + 1, height: hashWidth)
        var words = [UInt64](repeating: 0, count: DifferenceHash.wordCount)
        for row in 0..<hashWidth {
            for column in 0..<hashWidth where pixels[row * (hashWidth + 1) + column + 1]
                > pixels[row * (hashWidth + 1) + column] {
                let bit = row * hashWidth + column
                words[bit / 64] |= 1 << UInt64(bit % 64)
            }
        }
        return DifferenceHash(words: words)
    }

    /// The picture's gray levels at a small size, row by row from the top.
    private static func samples(of image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}
