import Foundation

/// An ancestry's or class's Details page, split where the setting's lore is. The lore ("Elf" through "Popular
/// Anathema", or "Roleplaying the Fighter" through "Others Probably...") is Paizo's Reserved Material, read from the
/// user's book; the rest (the class's key attribute and Hit Points, "Elf Mechanics", "Initial Proficiencies" and the
/// class features) is rules text the import keeps. The import leaves `loreMarker` where the lore was.
public enum DetailsPage {
    public static let loreMarker = "<!--details-lore-->"

    /// Where the page's lore is: from its "Roleplaying" section (a class's) or its start, to its "Mechanics" or
    /// "Initial Proficiencies" heading or its end.
    public static func loreRange(in html: String) -> Range<String.Index> {
        let start = heading(#"Roleplaying|During Combat Encounters"#, in: html)?.lowerBound ?? html.startIndex
        let end = heading(#"Mechanics|Initial Proficiencies"#, in: html[start...])?.lowerBound ?? html.endIndex
        return start..<end
    }

    /// The page without its lore, `loreMarker` in its place.
    public static func removingLore(from html: String) -> String {
        html.replacingCharacters(in: loreRange(in: html), with: loreMarker)
    }

    /// The Details as shown: `lore` where the import left the marker.
    public static func inserting(_ lore: String, into details: String) -> String {
        details.replacingOccurrences(of: loreMarker, with: lore)
    }

    private static func heading(_ words: String, in html: some StringProtocol) -> Range<String.Index>? {
        html.range(of: "<h[1-6][^>]*>[^<]*(\(words))", options: [.regularExpression, .caseInsensitive])
    }
}
