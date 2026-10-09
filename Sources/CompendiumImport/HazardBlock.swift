import FieldGuideKit
import Foundation

/// A hazard's stat block: Stealth, description, Disable, defenses, abilities, Routine and Reset.
enum HazardBlock {
    static func html(_ document: SourceDocument, context: PageContext) -> String {
        let system = document.systemData
        let attributes = system["attributes"]
        let details = system["details"]
        let abilities = CreatureAbilities(items: document.json["items"].array, context: context)
        let stealth = attributes[path: "stealth.value"].optionalInt.map { "DC \($0 + 10)" } ?? ""
        let stealthDetails = context.inline(attributes[path: "stealth.details"].string)
        return [
            "<section class=\"stat-block\">",
            HTML.line("Stealth", ([HTML.escape(stealth)]
                + [stealthDetails]).filter { !$0.isEmpty }.joined(separator: " ")),
            HTML.line("Description", context.inline(details["description"].string)),
            "<hr>",
            HTML.line("Disable", context.inline(details["disable"].string)),
            defenses(system),
            abilities.html(category: "defensive") + abilities.html(category: "interaction"),
            abilities.strikes(),
            abilities.html(category: "offensive"),
            HTML.line("Routine", context.inline(details["routine"].string)),
            HTML.line("Reset", context.inline(details["reset"].string)),
            "</section>"
        ].joined()
    }

    private static func defenses(_ system: JSONValue) -> String {
        let attributes = system["attributes"]
        var parts: [String] = []
        if let armorClass = attributes[path: "ac.value"].optionalInt, armorClass > 0 {
            parts.append("<strong>AC</strong> \(armorClass)")
        }
        for (key, label) in [("fortitude", "Fort"), ("reflex", "Ref"), ("will", "Will")] {
            if let value = system[path: "saves.\(key).value"].optionalInt, value != 0 {
                parts.append("<strong>\(label)</strong> \(Words.modifier(value))")
            }
        }
        let hitPoints = DefenseLines.hitPoints(attributes)
        return (parts.isEmpty ? "" : "<p>\(parts.joined(separator: "; "))</p>")
            + (hitPoints.isEmpty ? "" : "<p>\(hitPoints)</p>")
    }
}
