import CoreGraphics
import Foundation

/// Puts a page's lines in reading order when its two columns differ in width, as a bestiary's do: a wide column of
/// creatures beside a narrow one of sidebars, which changes sides from page to page. The columns are split where
/// the fewest lines cross; a line across the split is a band of its own, and between bands the left column is read
/// top to bottom, then the right.
enum ColumnOrder {
    static func lines(_ lines: [TextLine], pageWidth: CGFloat) -> [TextLine] {
        let split = self.split(of: lines, pageWidth: pageWidth)
        var ordered: [TextLine] = []
        var band: [TextLine] = []
        func closeBand() {
            ordered += band.sorted { first, second in
                let (left, right) = (first.bounds.minX < split, second.bounds.minX < split)
                return left != right ? left : first.bounds.maxY > second.bounds.maxY
            }
            band = []
        }
        for line in lines.sorted(by: { $0.bounds.maxY > $1.bounds.maxY }) {
            if line.bounds.minX < split - 4, line.bounds.maxX > split + 4 {
                closeBand()
                ordered.append(line)
            } else {
                band.append(line)
            }
        }
        closeBand()
        return ordered
    }

    /// The x where the columns meet: of the places a line starts in the page's middle, the one the fewest lines
    /// cross; the page's middle when no line starts there.
    static func split(of lines: [TextLine], pageWidth: CGFloat) -> CGFloat {
        let middle = (pageWidth * 0.3)...(pageWidth * 0.7)
        let candidates = Set(lines.map { ($0.bounds.minX - 3).rounded() }.filter(middle.contains))
        let crossings = { (edge: CGFloat) in
            lines.filter { $0.bounds.minX < edge - 4 && $0.bounds.maxX > edge + 4 }.count
        }
        return candidates.min { (crossings($0), $0) < (crossings($1), $1) } ?? pageWidth / 2
    }
}
