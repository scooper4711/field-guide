import Foundation
import SourcebookLore

/// An action icon in a stat block: the plain symbols the sample's stat blocks write it with, and how Paizo's
/// Pathfinder-Icons font draws it.
enum ActionIcon: String, CaseIterable {
    // Longest first, so three diamonds aren't read as three single actions.
    case three = "◆◆◆"
    case two = "◆◆"
    case one = "◆"
    case free = "◇"
    case reaction = "⤾"

    /// The font's PostScript name.
    static let fontName = "Pathfinder-Icons"

    /// The font's code point for the icon.
    var character: Unicode.Scalar {
        switch self {
        case .three: "\u{E900}"
        case .two: "\u{E901}"
        case .one: "\u{E902}"
        case .free: "\u{E903}"
        case .reaction: "\u{E904}"
        }
    }

    /// The icon's text in Paizo's PDFs, which is what Pluck knows it by.
    var token: String {
        switch self {
        case .three: "[three-actions]"
        case .two: "[two-actions]"
        case .one: "[one-action]"
        case .free: "[free-action]"
        case .reaction: "[reaction]"
        }
    }

    /// The run split at its action symbols, each of them a run of its own in the icons' font.
    static func runs(of run: TextRun) -> [TextRun] {
        var runs: [TextRun] = []
        var plain = ""
        var rest = Substring(run.text)
        while !rest.isEmpty {
            guard let icon = allCases.first(where: { rest.hasPrefix($0.rawValue) }) else {
                plain.append(rest.removeFirst())
                continue
            }
            if !plain.isEmpty { runs.append(TextRun(text: plain, font: run.font, size: run.size)) }
            plain = ""
            runs.append(TextRun(text: String(icon.character), font: fontName, size: run.size))
            rest = rest.dropFirst(icon.rawValue.count)
        }
        if !plain.isEmpty { runs.append(TextRun(text: plain, font: run.font, size: run.size)) }
        return runs
    }
}
