import FieldGuideKit
import Foundation

/// Diagrams drawn from the rules they explain, each placed in its GM Screen page after a passage of the page's text.
enum RulesDiagrams {
    /// A diagram and where it goes: after the first `anchor` in the GM Screen page named `page`.
    struct Placement {
        var page: String
        var anchor: String
        var html: String
    }

    static let placements = [
        Placement(page: "Detecting Creatures", anchor: "</table>", html: figure(detection, notes: detectionNotes)),
        Placement(page: "Counteracting", anchor: "You fail to counteract the target.</p>",
                  html: figure(counteract, notes: []))
    ]

    /// What the detection diagram leaves out, listed under it.
    static let detectionNotes = [
        "<strong>You act:</strong> anything except Hide, Sneak or Step makes you observed just before you act. "
            + "If it's a Strike, the target stays off-guard to that attack, and you're observed after it.",
        "<strong>Invisible:</strong> you're undetected by everyone and can't become observed, except by special "
            + "abilities or magic. Seek, and Sneak's critical failure, leave you hidden at most.",
        "<strong>Imprecise senses</strong>, such as hearing or scent: Seek makes you hidden at most, never observed."
    ]

    /// The page's text with its diagram, when it's a GM Screen page with one and its passage is there.
    static func adding(to html: String, of page: JournalPage) -> String {
        guard page.category == .gmScreen, let placement = placements.first(where: { $0.page == page.name }),
              let anchor = html.range(of: placement.anchor) else { return html }
        return html.replacingCharacters(in: anchor.upperBound..<anchor.upperBound, with: placement.html)
    }

    static func figure(_ svg: String, notes: [String]) -> String {
        let list = notes.isEmpty ? "" : "<ul class=\"rules-notes\">" + notes.map { "<li>\($0)</li>" }.joined() + "</ul>"
        return "<figure class=\"rules-figure\">\(svg)\(list)</figure>"
    }
}
