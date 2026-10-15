import Foundation

/// Formats Foundry values the way Paizo prints them.
enum Formatting {
    static let sizes = [
        "tiny": "Tiny", "sm": "Small", "med": "Medium", "lg": "Large", "huge": "Huge", "grg": "Gargantuan"
    ]

    static let attributes = [
        "str": "Strength", "dex": "Dexterity", "con": "Constitution", "int": "Intelligence", "wis": "Wisdom",
        "cha": "Charisma"
    ]

    /// "900 gp", "1 gp, 5 sp", or "" for no price; "(for 10)" when the price covers several.
    static func price(_ price: JSONValue) -> String {
        let coins = ["pp", "gp", "sp", "cp"].compactMap { coin -> String? in
            let amount = price["value"][coin].int
            // Written the same on every Mac, whatever its region, so imports match (and Paizo writes "1,500").
            return amount > 0 ? "\(amount.formatted(.number.locale(Locale(identifier: "en_US")))) \(coin)" : nil
        }
        guard !coins.isEmpty else { return "" }
        let per = price["per"].int
        return coins.joined(separator: ", ") + (per > 1 ? " (for \(per))" : "")
    }

    /// "—" for no Bulk, "L" for light, else the number.
    static func bulk(_ value: JSONValue) -> String {
        guard case let .number(bulk) = value else { return "" }
        if bulk == 0 { return "—" }
        if bulk < 1 { return "L" }
        return value.string
    }

    private static let periods = [
        "turn": "turn", "round": "round", "PT1M": "minute", "PT10M": "10 minutes", "PT1H": "hour",
        "PT24H": "day", "day": "day", "P1W": "week", "P1M": "month", "P1Y": "year"
    ]

    /// "once per day", "3 times per hour".
    static func frequency(_ frequency: JSONValue) -> String {
        let max = frequency["max"].int
        guard max > 0 else { return "" }
        let period = periods[frequency["per"].string] ?? frequency["per"].string
        return "\(times(max)) per \(period)"
    }

    /// The action glyph for an `actionType` and `actions` pair, or "" for passive.
    static func actionGlyph(type: String, count: Int?) -> String {
        switch type {
        case "action": HTML.actionGlyph(String(count ?? 1))
        case "reaction", "free": HTML.actionGlyph(type)
        default: ""
        }
    }

    /// The action facet value: "One Action", "Reaction", "Passive".
    static func actionTypeName(type: String, count: Int?) -> String {
        switch type {
        case "action": ["One Action", "Two Actions", "Three Actions"][min(max((count ?? 1) - 1, 0), 2)]
        case "reaction": "Reaction"
        case "free": "Free Action"
        default: "Passive"
        }
    }

    /// A spell or ability's casting time: a glyph for 1–3 actions, reactions and free actions, else words.
    static func time(_ value: String) -> String {
        ["1", "2", "3", "free", "reaction", "1 to 3", "1 or 2", "2 or 3"].contains(value)
            ? HTML.actionGlyph(value) : HTML.escape(value)
    }

    static func castingTimeName(_ value: String) -> String {
        switch value {
        case "1": "One Action"
        case "2": "Two Actions"
        case "3": "Three Actions"
        case "reaction": "Reaction"
        case "free": "Free Action"
        default: value.isEmpty ? "" : value.prefix(1).uppercased() + value.dropFirst()
        }
    }

    /// "once", "twice", "3 times".
    private static func times(_ count: Int) -> String {
        switch count {
        case 1: "once"
        case 2: "twice"
        default: "\(count) times"
        }
    }
}
