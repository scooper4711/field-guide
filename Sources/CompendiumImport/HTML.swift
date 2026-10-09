import Foundation

/// Small helpers for writing entry pages.
enum HTML {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// The app's URL for a stored image, percent-encoded.
    static func imageURL(_ path: String) -> String {
        "fieldguide:///images/" + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)
    }

    static func span(_ className: String, _ text: String) -> String {
        "<span class=\"\(className)\">\(escape(text))</span>"
    }

    static func link(_ text: String, to href: String) -> String {
        "<a href=\"\(escape(href))\">\(escape(text))</a>"
    }

    /// "<p><strong>Label</strong> value</p>", or nothing when the value is empty. `value` is HTML.
    static func line(_ label: String, _ value: String) -> String {
        value.isEmpty ? "" : "<p><strong>\(escape(label))</strong> \(value)</p>"
    }

    /// The text of some HTML, for searching: tags removed, entities decoded and space collapsed.
    static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, character) in entities { text = text.replacingOccurrences(of: entity, with: character) }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let entities = [
        ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")
    ]

    /// An action glyph in the Pathfinder actions font: 1–3 actions, free action or reaction.
    static func actionGlyph(_ actions: String) -> String {
        let letters = ["1": "1", "2": "2", "3": "3", "free": "F", "reaction": "R", "1 to 3": "1 - 3",
                       "1 or 2": "1 / 2", "2 or 3": "2 / 3"]
        guard let letter = letters[actions] else { return escape(actions) }
        return "<span class=\"action-glyph\">\(letter)</span>"
    }
}

/// Turns Foundry slugs into readable words.
enum Words {
    private static let special = [
        "low-light-vision": "low-light vision", "all-damage": "all", "cold-iron": "cold iron",
        "fear-effects": "fear effects", "critical-hits": "critical hits", "object-immunities": "object immunities"
    ]

    static func label(_ slug: String) -> String {
        special[slug] ?? slug.replacingOccurrences(of: "-", with: " ")
    }

    /// The label with each word capitalized: "low-light-vision" → "Low-Light Vision".
    static func title(_ slug: String) -> String {
        label(slug).split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    /// "+5" or "–2", with a true minus sign as Paizo prints it.
    static func modifier(_ value: Int) -> String {
        value < 0 ? "–\(-value)" : "+\(value)"
    }
}
