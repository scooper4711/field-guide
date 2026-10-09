import FieldGuideKit
import Foundation

/// A creature's stat block in Paizo's order: senses to items, defenses, then speed and offense.
enum CreatureBlock {
    static func html(_ document: SourceDocument, context: PageContext) -> String {
        let system = document.systemData
        let items = document.json["items"].array
        let abilities = CreatureAbilities(items: items, context: context)
        return [
            "<section class=\"stat-block\">",
            top(system, items: items),
            abilities.html(category: "interaction"),
            "<hr>",
            defenses(system),
            abilities.html(category: "defensive"),
            "<hr>",
            HTML.line("Speed", HTML.escape(speeds(system[path: "attributes.speed"]))),
            abilities.strikes(),
            abilities.spellcasting(creatureLevel: system[path: "details.level.value"].int),
            abilities.html(category: "offensive"),
            "</section>"
        ].joined()
    }

    private static func top(_ system: JSONValue, items: [JSONValue]) -> String {
        [
            HTML.line("Perception", HTML.escape(perception(system["perception"]))),
            HTML.line("Languages", HTML.escape(languages(system[path: "details.languages"]))),
            HTML.line("Skills", HTML.escape(skills(system["skills"], items: items))),
            "<p class=\"attributes\">\(attributes(system["abilities"]))</p>",
            HTML.line("Items", HTML.escape(inventory(items)))
        ].joined()
    }

    static func perception(_ perception: JSONValue) -> String {
        let senses = perception["senses"].array.map { sense in
            var text = Words.label(sense["type"].string)
            let acuity = sense["acuity"].string
            if !acuity.isEmpty, acuity != "precise" { text += " (\(acuity))" }
            if let range = sense["range"].optionalInt { text += " \(range) feet" }
            return text
        }
        let details = perception["details"].string
        return ([Words.modifier(perception["mod"].int)] + senses + (details.isEmpty ? [] : [details]))
            .joined(separator: "; ")
    }

    static func languages(_ languages: JSONValue) -> String {
        let names = languages["value"].strings.map(Words.title)
        let details = languages["details"].string
        return (names.joined(separator: ", ") + (details.isEmpty ? "" : "; \(details)"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "; "))
    }

    static func skills(_ skills: JSONValue, items: [JSONValue]) -> String {
        let standard = skills.object.keys.sorted().map { "\(Words.title($0)) " +
            "\(Words.modifier(skills[$0]["base"].int))" }
        let lore = items.filter { $0["type"].string == "lore" }.map {
            "\($0["name"].string) \(Words.modifier($0[path: "system.mod.value"].int))"
        }
        return (standard + lore).joined(separator: ", ")
    }

    static func attributes(_ abilities: JSONValue) -> String {
        ["str", "dex", "con", "int", "wis", "cha"].map { key in
            let label = key.prefix(1).uppercased() + key.dropFirst()
            return "<strong>\(label)</strong> \(Words.modifier(abilities[key]["mod"].int))"
        }.joined(separator: ", ")
    }

    private static let inventoryTypes: Set<String> = [
        "weapon", "armor", "shield", "equipment", "consumable", "treasure", "backpack", "ammo"
    ]

    static func inventory(_ items: [JSONValue]) -> String {
        items.filter { inventoryTypes.contains($0["type"].string) }.map { item in
            let quantity = item[path: "system.quantity"].int
            let name = item["name"].string.lowercased()
            return quantity > 1 ? "\(name) (\(quantity))" : name
        }.joined(separator: ", ")
    }

    static func defenses(_ system: JSONValue) -> String {
        let attributes = system["attributes"]
        var armorClass = "<strong>AC</strong> \(attributes[path: "ac.value"].int)"
        let acDetails = attributes[path: "ac.details"].string
        if !acDetails.isEmpty { armorClass += " (\(HTML.escape(acDetails)))" }
        let saveText = [("fortitude", "Fort"), ("reflex", "Ref"), ("will", "Will")].map { key, label in
            "<strong>\(label)</strong> \(Words.modifier(system[path: "saves.\(key).value"].int))"
        }.joined(separator: ", ")
        let allSaves = attributes[path: "allSaves.value"].string
        return "<p>\(armorClass); \(saveText)\(allSaves.isEmpty ? "" : "; \(HTML.escape(allSaves))")</p>"
            + "<p>\(DefenseLines.hitPoints(attributes))</p>"
    }

    static func speeds(_ speed: JSONValue) -> String {
        let land = speed["value"].int
        let others = speed["otherSpeeds"].array.map { "\(Words.label($0["type"].string)) \($0["value"].int) feet" }
        let details = speed["details"].string
        return ((land > 0 ? ["\(land) feet"] : []) + others
            + (details.isEmpty ? [] : [details])).joined(separator: ", ")
    }
}

/// HP with hardness, immunities, weaknesses and resistances, shared by creatures and hazards.
enum DefenseLines {
    static func hitPoints(_ attributes: JSONValue) -> String {
        var parts: [String] = []
        let hardness = attributes["hardness"].int
        if hardness > 0 { parts.append("<strong>Hardness</strong> \(hardness)") }
        let maximum = attributes[path: "hp.max"].int
        if maximum > 0 {
            let details = attributes[path: "hp.details"].string
            let brokenThreshold = attributes[path: "hp.brokenThreshold"].optionalInt
            var text = "<strong>HP</strong> \(maximum)"
            if let brokenThreshold, brokenThreshold > 0 { text += " (BT \(brokenThreshold))" }
            if !details.isEmpty { text += ", \(HTML.escape(details))" }
            parts.append(text)
        }
        let immunities = attributes["immunities"].array.map { Words.label($0["type"].string) }
        if !immunities.isEmpty { parts.append("<strong>Immunities</strong> " +
            "\(HTML.escape(immunities.joined(separator: ", ")))") }
        for (key, label) in [("weaknesses", "Weaknesses"), ("resistances", "Resistances")] {
            let values = attributes[key].array.map(adjustment)
            guard !values.isEmpty else { continue }
            parts.append("<strong>\(label)</strong> \(HTML.escape(values.joined(separator: ", ")))")
        }
        return parts.joined(separator: "; ")
    }

    /// "fire 10 (except magical)".
    private static func adjustment(_ entry: JSONValue) -> String {
        var text = "\(Words.label(entry["type"].string)) \(entry["value"].int)"
        let exceptions = entry["exceptions"].array.map { exception in
            Words.label(exception.string.isEmpty ? exception["label"].string : exception.string)
        }
        if !exceptions.isEmpty { text += " (except \(exceptions.joined(separator: ", ")))" }
        let double = entry["doubleVs"].array.map { Words.label($0.string) }
        if !double.isEmpty { text += " (double resistance vs. \(double.joined(separator: ", ")))" }
        return text
    }
}
