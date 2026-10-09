// Draws the app icon, a field guide on Pathfinder red, as a 1024 px PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024.0
// A bitmap of exactly 1024 pixels, whatever the screen's scale.
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Drawing the icon failed") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let gradient = NSGradient(starting: NSColor(red: 0.55, green: 0.08, blue: 0.05, alpha: 1),
                          ending: NSColor(red: 0.27, green: 0.02, blue: 0.02, alpha: 1))
gradient?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
let configuration = NSImage.SymbolConfiguration(pointSize: 560, weight: .regular)
    .applying(.init(paletteColors: [NSColor(red: 0.98, green: 0.93, blue: 0.80, alpha: 1)]))
if let symbol = NSImage(systemSymbolName: "book.pages.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration) {
    let symbolSize = symbol.size
    symbol.draw(in: NSRect(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2,
                           width: symbolSize.width, height: symbolSize.height))
}
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Drawing the icon failed") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
