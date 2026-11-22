import CoreGraphics
import Foundation
import ImageIO

/// The art a card shows in the App Store's screenshots, named by `FIELD_GUIDE_STORE_ART`, since real art comes from
/// the user's own PDFs. Debug builds only.
enum StoreScreenshotArt {
    static var picture: CGImage? {
        #if DEBUG
        guard let path = ProcessInfo.processInfo.environment["FIELD_GUIDE_STORE_ART"],
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
        #else
        return nil
        #endif
    }
}
