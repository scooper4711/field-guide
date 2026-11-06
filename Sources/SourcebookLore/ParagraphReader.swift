import CoreGraphics
import Foundation

/// Joins a write-up's prose lines into the paragraphs of its introduction, up to its first subheading (a larger
/// or wholly bold line): the sections after it ("The Church", "Aphorisms", "Divine Allies"…) mix in sidebars and
/// stat blocks. Paizo justifies its text, so a paragraph ends with a line that stops short of the column's right
/// edge on a sentence's end; where the left edge is steady, an indented line also starts one.
struct ParagraphReader {
    let lines: [TextLine]
    let bodySize: CGFloat

    func paragraphs() -> [String] {
        let introduction = Array(lines.prefix { !isSubheading($0) && IntercessionReader.label(of: $0) == nil })
        var paragraphs: [[String]] = []
        for (index, line) in introduction.enumerated() {
            let text = Self.text(of: line, bodySize: bodySize)
            guard !text.isEmpty else { continue }
            if paragraphs.isEmpty || startsParagraph(at: index, in: introduction) {
                paragraphs.append([text])
            } else {
                paragraphs[paragraphs.count - 1].append(text)
            }
        }
        return paragraphs.map(TextRepair.join)
    }

    func isSubheading(_ line: TextLine) -> Bool {
        line.size > bodySize * 1.15
            || line.runs.allSatisfy { $0.isBold || $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The line's text without superscripts: runs much smaller than the body text, such as 1e source tags.
    static func text(of line: TextLine, bodySize: CGFloat) -> String {
        line.runs.filter { $0.size >= bodySize * 0.7 }.map(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startsParagraph(at index: Int, in lines: [TextLine]) -> Bool {
        guard index > 0 else { return false }
        return endsParagraph(lines[index - 1], in: lines) || isIndented(at: index, in: lines)
    }

    /// True when `line` ends a sentence short of its column's right edge, which its neighbors in the column reach.
    private func endsParagraph(_ line: TextLine, in lines: [TextLine]) -> Bool {
        guard let last = line.text.last, ".!?:”’\")".contains(last) else { return false }
        let column = lines.filter { abs($0.bounds.midY - line.bounds.midY) < 60 && Self.sameColumn($0, line) }
        let rightEdge = column.map(\.bounds.maxX).max() ?? line.bounds.maxX
        return line.bounds.maxX < rightEdge - 10
    }

    /// True when the line is indented from the steady left edge the lines before and after it share.
    private func isIndented(at index: Int, in lines: [TextLine]) -> Bool {
        guard index + 1 < lines.count else { return false }
        let (previous, line, next) = (lines[index - 1], lines[index], lines[index + 1])
        guard Self.sameColumn(previous, line), Self.sameColumn(line, next),
              abs(previous.bounds.minX - next.bounds.minX) < 1 else { return false }
        return line.bounds.minX > previous.bounds.minX + 4
    }

    private static func sameColumn(_ first: TextLine, _ second: TextLine) -> Bool {
        first.bounds.minX < second.bounds.maxX && second.bounds.minX < first.bounds.maxX
    }
}
