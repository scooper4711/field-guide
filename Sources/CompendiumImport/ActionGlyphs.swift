import Bestiary
import Foundation

/// Action icons in Paizo's Pathfinder-Icons font. Foundry's descriptions mark them as
/// `<span class="action-glyph">` around the pf2e action font's letters (1–3, A, D, T, F and R in either case) or
/// ranges such as "1 - 3". Pathfinder-Icons draws only its private-use code points (Tabletop Kit's `ActionIcons`)
/// and leaves letters and hyphens blank, so each icon gets a span of its own and anything else stays text.
enum ActionGlyphs {
    private static let costs: [Character: ActionCost] = {
        var costs: [Character: ActionCost] = [
            "1": .one, "a": .one, "A": .one, "2": .two, "d": .two, "D": .two, "3": .three, "t": .three, "T": .three,
            "4": .free, "f": .free, "F": .free, "5": .reaction, "r": .reaction, "R": .reaction
        ]
        for cost in [ActionCost.one, .two, .three, .free, .reaction] {
            costs[Character(ActionIcons.character(for: cost))] = cost
        }
        return costs
    }()

    /// HTML for glyph text such as "2", "R" or "1 - 3": a span per icon, with other characters escaped between.
    static func html(_ letters: String) -> String {
        letters.map { character in
            costs[character].map { "<span class=\"action-glyph\">\(ActionIcons.character(for: $0))</span>" }
                ?? HTML.escape(String(character))
        }.joined()
    }

    /// Rewrites every `<span class="action-glyph">…</span>` in `html` with `html(_:)`.
    static func convertSpans(in html: String) -> String {
        guard html.contains("action-glyph") else { return html }
        return html.replacing(/<span class="action-glyph">([^<]*)<\/span>/) { match in
            Self.html(String(match.output.1))
        }
    }
}
