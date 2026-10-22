import Foundation

/// A labeled line of a deity's entry, such as "Edicts" and its text.
public struct StatLine: Codable, Equatable, Sendable {
    public var label: String
    public var text: String

    public init(label: String, text: String) {
        self.label = label
        self.text = text
    }
}

/// What a deity's Lore tab shows, read from the user's books: its stat lines and its write-up.
public struct DeityLore: Codable, Equatable, Sendable {
    /// The labels of the setting's stat lines, in the order they are shown. The rules lines (domains, divine font,
    /// favored weapon and the like) are on the entry's own page and are left out.
    public static let shownLabels = [
        "Title", "Areas of Concern", "Edicts", "Anathema", "Religious Symbol", "Sacred Animal", "Sacred Colors"
    ]

    public var statLines: [StatLine]
    /// The paragraphs of the write-up's introduction.
    public var paragraphs: [String]

    public init(statLines: [StatLine] = [], paragraphs: [String] = []) {
        self.statLines = statLines
        self.paragraphs = paragraphs
    }

    public var isEmpty: Bool { statLines.isEmpty && paragraphs.isEmpty }

    /// The lore as the Lore tab's HTML: the stat lines, then the write-up.
    public var html: String {
        let lines = Self.shownLabels.compactMap { label in statLines.first { $0.label == label } }
            .map { "<p><strong>\(escape($0.label))</strong> \(escape($0.text))</p>" }
        let prose = paragraphs.map { "<p>\(escape($0))</p>" }
        return "<section class=\"description\">" + (lines + prose).joined() + "</section>"
    }

    /// The stat lines of `self`, with those `other` adds or replaces: a write-up's lines and a table's are merged so
    /// each label appears once.
    public func merging(statLinesOf other: DeityLore) -> DeityLore {
        var merged = self
        for line in other.statLines {
            if let index = merged.statLines.firstIndex(where: { $0.label == line.label }) {
                merged.statLines[index] = line
            } else {
                merged.statLines.append(line)
            }
        }
        return merged
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
