import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#else
import AppKit
private typealias PlatformImage = NSImage
#endif

/// Decoded thumbnails, kept while memory allows.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, PlatformImage>()

    func image(at url: URL, isEmpty: Bool) -> Image? {
        guard !isEmpty else { return nil }
        if let cached = cache.object(forKey: url as NSURL) { return Self.image(cached) }
        guard let loaded = PlatformImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(loaded, forKey: url as NSURL)
        return Self.image(loaded)
    }

    private static func image(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }
}
