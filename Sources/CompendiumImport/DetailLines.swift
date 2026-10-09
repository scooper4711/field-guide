import FieldGuideKit
import Foundation

/// The details block under an entry's traits, by kind: a spell's range and defense, an item's price and
/// Bulk, a feat's prerequisites.
enum DetailLines {
    static func html(_ document: SourceDocument, context: PageContext) -> String {
        let system = document.systemData
        switch document.category {
        case .spells: return spell(system, context: context)
        case .equipment: return ItemLines.html(document, context: context)
        case .feats, .actions, .campaignFeatures: return ability(system, context: context)
        case .ancestries, .heritages, .backgrounds, .classes, .deities:
            return CharacterOptionLines.html(document, context: context)
        default: return ""
        }
    }

    static func spell(_ system: JSONValue, context: PageContext) -> String {
        let traditions = system[path: "traits.traditions"].strings.map(Words.label).joined(separator: ", ")
        let time = system[path: "time.value"].string
        let cost = system[path: "cost.value"].string
        let area = system["area"]
        let areaText = area.isNull ? "" : "\(area["value"].string)-foot \(area["type"].string)"
        var duration = system[path: "duration.value"].string
        if system[path: "duration.sustained"].bool { duration = duration.isEmpty ? "sustained" : "sustained up to " +
            "\(duration)" }
        return [
            HTML.line("Traditions", HTML.escape(traditions)),
            HTML.line("Cast", Formatting.time(time)
                + (cost.isEmpty ? "" : "; <strong>Cost</strong> \(HTML.escape(cost))")),
            HTML.line("Requirements", context.inline(system[path: "requirements"].string)),
            HTML.line("Range", HTML.escape(system[path: "range.value"].string)),
            HTML.line("Area", HTML.escape(areaText)),
            HTML.line("Targets", HTML.escape(system[path: "target.value"].string)),
            HTML.line("Defense", HTML.escape(defense(system["defense"]))),
            HTML.line("Duration", HTML.escape(duration))
        ].joined()
    }

    /// "basic Reflex" or "Will".
    static func defense(_ defense: JSONValue) -> String {
        let save = defense["save"]
        if !save.isNull {
            return (save["basic"].bool ? "basic " : "") + Words.title(save["statistic"].string)
        }
        let passive = defense[path: "passive.statistic"].string
        return passive.isEmpty ? "" : Words.title(passive)
    }

    /// Feats, actions and campaign features: prerequisites, frequency, trigger and requirements.
    static func ability(_ system: JSONValue, context: PageContext) -> String {
        let prerequisites = system[path: "prerequisites.value"].array.map { $0["value"].string }
        return [
            HTML.line("Prerequisites", HTML.escape(prerequisites.joined(separator: "; "))),
            HTML.line("Frequency", HTML.escape(Formatting.frequency(system["frequency"]))),
            HTML.line("Trigger", context.inline(system[path: "trigger.value"].string)),
            HTML.line("Requirements", context.inline(system[path: "requirements.value"].string))
        ].joined()
    }
}

/// Price, usage, Bulk and the numbers of weapons, armor and shields.
enum ItemLines {
    static func html(_ document: SourceDocument, context: PageContext) -> String {
        let system = document.systemData
        let usage = Words.label(system[path: "usage.value"].string)
        var lines = [
            HTML.line("Price", HTML.escape(Formatting.price(system["price"]))),
            HTML.line("Usage", HTML.escape(usage)),
            HTML.line("Bulk", HTML.escape(Formatting.bulk(system[path: "bulk.value"])))
        ]
        switch document.type {
        case "weapon": lines += weapon(system)
        case "armor": lines += armor(system)
        case "shield": lines += shield(system)
        default: break
        }
        return lines.joined()
    }

    private static func weapon(_ system: JSONValue) -> [String] {
        let damage = system["damage"]
        let dice = damage["dice"].int
        let damageText = dice > 0 ? "\(dice)\(damage["die"].string) \(Words.label(damage["damageType"].string))" : ""
        let range = system["range"].optionalInt.map { "\($0) feet" } ?? ""
        let reload = system[path: "reload.value"].string
        return [
            HTML.line("Damage", HTML.escape(damageText)),
            HTML.line("EntryCategory", HTML.escape(Words.title(system["category"].string))),
            HTML.line("Group", HTML.escape(Words.title(system["group"].string))),
            HTML.line("Range", HTML.escape(range)),
            HTML.line("Reload", HTML.escape(reload))
        ]
    }

    private static func armor(_ system: JSONValue) -> [String] {
        let dexCap = system["dexCap"].optionalInt.map { Words.modifier($0) } ?? ""
        let strength = system["strength"].optionalInt.map { "+\($0)" } ?? ""
        return [
            HTML.line("AC Bonus", HTML.escape(Words.modifier(system["acBonus"].int))),
            HTML.line("Dex Cap", HTML.escape(dexCap)),
            HTML.line("Strength", HTML.escape(strength)),
            HTML.line("Check Penalty", HTML.escape(penalty(system["checkPenalty"].int))),
            HTML.line("Speed Penalty",
                      HTML.escape(system["speedPenalty"].int == 0 ? "" : "\(system["speedPenalty"].int) feet")),
            HTML.line("EntryCategory", HTML.escape(Words.title(system["category"].string))),
            HTML.line("Group", HTML.escape(Words.title(system["group"].string)))
        ]
    }

    private static func shield(_ system: JSONValue) -> [String] {
        let hitPoints = system[path: "hp.max"].int
        let brokenThreshold = hitPoints / 2
        return [
            HTML.line("AC Bonus", HTML.escape(Words.modifier(system["acBonus"].int))),
            HTML.line("Hardness", HTML.escape(String(system["hardness"].int))),
            HTML.line("HP", HTML.escape(hitPoints > 0 ? "\(hitPoints) (BT \(brokenThreshold))" : ""))
        ]
    }

    private static func penalty(_ value: Int) -> String { value == 0 ? "" : Words.modifier(value) }
}
