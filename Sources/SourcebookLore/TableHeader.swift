import CoreGraphics
import Foundation
import PDFKit

/// A deity table's header row: labels in capitals, some of them set over two lines ("DIVINE" above "FONT"). PDFKit
/// may read labels on one baseline as one line, so the header is read a word at a time.
struct TableHeader {
    /// A column's label: its words, and where they are.
    struct Label {
        var words: [TextWord]

        var bounds: CGRect { words.map(\.bounds).reduce(CGRect.null) { $0.union($1) } }
        var middle: CGFloat { bounds.midX }

        var text: String {
            words.sorted { ($0.bounds.midY.rounded(), -$0.bounds.minX) > ($1.bounds.midY.rounded(), -$1.bounds.minX) }
                .map(\.text).joined(separator: " ")
        }

        /// True when `word` belongs to the label: next to it on its line, or above or below it.
        func takes(_ word: TextWord) -> Bool {
            words.contains { other in
                let sameLine = abs(other.bounds.midY - word.bounds.midY) < 3
                let gap = word.bounds.minX - other.bounds.maxX
                return sameLine ? (-2...6).contains(gap) : other.bounds.minX < word.bounds.maxX
                    && word.bounds.minX < other.bounds.maxX
            }
        }
    }

    let labels: [Label]
    /// The lowest point of the header; the rows are below it.
    let bottom: CGFloat

    /// The page's header, found by its first column's label, "DEITY"; nil on a page without one.
    init?(page: PDFPage) {
        // Finding each word's bounds is slow, so pages without the label are passed over by their text first.
        guard page.string?.contains("DEITY") == true else { return nil }
        let capitals = PageText.words(of: page, matching: "\\b[A-Z][A-Z&]+\\b")
        guard let deity = capitals.first(where: { $0.text == "DEITY" }) else { return nil }
        let words = capitals.filter { abs($0.bounds.midY - deity.bounds.midY) <= 12 }
        var labels: [Label] = []
        for word in words.sorted(by: { $0.bounds.minX < $1.bounds.minX }) {
            if let index = labels.lastIndex(where: { $0.takes(word) }) {
                labels[index].words.append(word)
            } else {
                labels.append(Label(words: [word]))
            }
        }
        self.labels = labels
        bottom = words.map(\.bounds.minY).min() ?? deity.bounds.minY
    }

    /// The columns, with their left edges placed from where the rows' text starts: a column's text may begin left
    /// of its label, which is centered over it, but never left of the gap between the two labels.
    func columns(placing lines: [TextLine]) -> [TableColumn] {
        labels.indices.map { index in
            let label = labels[index]
            guard index > 0 else { return TableColumn(label: "Deity", left: 0, right: right(of: index, lines)) }
            return TableColumn(label: Self.title(label.text), left: left(of: index, lines),
                               right: right(of: index, lines))
        }
    }

    private func left(of index: Int, _ lines: [TextLine]) -> CGFloat {
        let between = (labels[index - 1].middle + labels[index].middle) / 2
        let starts = lines.filter { nearestLabel(to: $0) == index && $0.bounds.width > 20 }
            .map { ($0.bounds.minX).rounded() }
        let common = Dictionary(grouping: starts, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        return min(common ?? between, between) - 2
    }

    private func right(of index: Int, _ lines: [TextLine]) -> CGFloat {
        index + 1 < labels.count ? left(of: index + 1, lines) : .greatestFiniteMagnitude
    }

    private func nearestLabel(to line: TextLine) -> Int? {
        labels.indices.min { abs(labels[$0].middle - line.bounds.midX) < abs(labels[$1].middle - line.bounds.midX) }
    }

    /// A label as the stat lines spell it: "AREAS OF CONCERN" becomes "Areas of Concern"; the table's "HOLY SYMBOL"
    /// is the catalog's "Religious Symbol".
    static func title(_ label: String) -> String {
        label == "HOLY SYMBOL" ? "Religious Symbol" : TextRepair.titleCase(label)
    }
}

/// A column of a deity table.
struct TableColumn {
    let label: String
    let left: CGFloat
    let right: CGFloat

    /// The column's rectangle below the header, above the page's footer.
    func area(below top: CGFloat) -> CGRect {
        let footer: CGFloat = 20
        let width = right == .greatestFiniteMagnitude ? 10_000 : right - left
        return CGRect(x: left, y: footer, width: width, height: max(top - 1 - footer, 0))
    }
}
