import FieldGuideKit
import Foundation

/// A creature's Strikes, abilities and spellcasting, from its embedded items.
struct CreatureAbilities {
    let items: [JSONValue]
    let context: PageContext

    /// The `action` items of one stat-block section: interaction, defensive or offensive.
    func html(category: String) -> String {
        items.filter { $0["type"].string == "action" && $0[path: "system.category"].string == category }
            .map(ability)
            .joined()
    }

    func ability(_ item: JSONValue) -> String {
        let system = item["system"]
        let glyph = Formatting.actionGlyph(type: system[path: "actionType.value"].string,
                                           count: system[path: "actions.value"].optionalInt)
        let traits = system[path: "traits.value"].strings.map { HTML.escape(Words.label($0)) }
        let traitText = traits.isEmpty ? "" : " (\(traits.joined(separator: ", ")))"
        let description = context.enrich(system[path: "description.value"].string)
        return "<div class=\"ability\"><p class=\"ability-name\"><strong>\(HTML.escape(item["name"].string))</strong>"
            + " \(glyph)\(traitText)</p>\(description)</div>"
    }

    /// "Melee ◆ jaws +12 (reach 10 feet), Damage 2d8+6 piercing plus Grab".
    func strikes() -> String {
        let abilityNames = Dictionary(
            items.filter { $0["type"].string == "action" }.map { ($0[path: "system.slug"].string, $0["name"].string) },
            uniquingKeysWith: { first, _ in first }
        )
        return items.filter { $0["type"].string == "melee" }.map { strike($0, abilityNames: abilityNames) }.joined()
    }

    private func strike(_ item: JSONValue, abilityNames: [String: String]) -> String {
        let system = item["system"]
        let range = system["range"]
        var traits = system[path: "traits.value"].strings.map(Words.label)
        if let increment = range["increment"].optionalInt {
            traits.append("range increment \(increment) feet")
        } else if let maximum = range["max"].optionalInt {
            traits.append("range \(maximum) feet")
        }
        let kind = range.isNull ? "Melee" : "Ranged"
        let traitText = traits.isEmpty ? "" : " (\(traits.joined(separator: ", ")))"
        let effects = system[path: "attackEffects.value"].strings.map { abilityNames[$0] ?? Words.label($0) }
        let damage = ([Self.damage(system["damageRolls"])] + effects).filter { !$0.isEmpty }.joined(separator: " plus ")
        return "<p class=\"strike\"><strong>\(kind)</strong> \(HTML.actionGlyph("1")) "
            + HTML.escape("\(item["name"].string.lowercased()) " +
                "\(Words.modifier(system[path: "bonus.value"].int))\(traitText)")
            + (damage.isEmpty ? "" : ", <strong>Damage</strong> \(HTML.escape(damage))") + "</p>"
    }

    /// The damage parts, the one with a modifier first, persistent last.
    static func damage(_ rolls: JSONValue) -> String {
        let parts = rolls.object.keys.sorted().map { key -> (text: String, rank: Int) in
            let roll = rolls[key]
            let formula = roll["damage"].string.replacingOccurrences(of: " ", with: "")
            let category = roll["category"].string
            let text = [formula, category, Words.label(roll["damageType"].string)].filter { !$0.isEmpty }
                .joined(separator: " ")
            let rank = category == "persistent" ? 3 : category.isEmpty ? (formula.contains("+") ? 0 : 1) : 2
            return (text, rank)
        }
        return parts.sorted { $0.rank < $1.rank }.map(\.text).joined(separator: " plus ")
    }

    func spellcasting(creatureLevel: Int) -> String {
        Spellcasting(items: items, context: context).html(creatureLevel: creatureLevel)
    }
}

/// Spells grouped under their spellcasting entry by rank, as the stat block lists them.
struct Spellcasting {
    let items: [JSONValue]
    let context: PageContext

    func html(creatureLevel: Int) -> String {
        let spells = items.filter { $0["type"].string == "spell" }
        return items.filter { $0["type"].string == "spellcastingEntry" }.map { entry in
            let entrySpells = spells.filter { $0[path: "system.location.value"].string == entry["_id"].string }
            return entryHTML(entry, spells: entrySpells, creatureLevel: creatureLevel)
        }.joined()
    }

    private func entryHTML(_ entry: JSONValue, spells: [JSONValue], creatureLevel: Int) -> String {
        let system = entry["system"]
        let cantripRank = system[path: "autoHeightenLevel.value"].optionalInt ?? max(1, (creatureLevel + 1) / 2)
        let groups = system[path: "prepared.value"].string == "prepared"
            ? preparedGroups(system["slots"], spells: spells, cantripRank: cantripRank)
            : listedGroups(spells, cantripRank: cantripRank)
        var header = "<strong>\(HTML.escape(entry["name"].string))</strong>"
        let dc = system[path: "spelldc.dc"].int
        if dc > 0 { header += " DC \(dc)" }
        let attack = system[path: "spelldc.value"].int
        if attack != 0 { header += ", attack \(Words.modifier(attack))" }
        let ranks = groups.map { "<strong>\($0.label)</strong> \($0.spells.joined(separator: ", "))" }
        return "<p class=\"spellcasting\">\(([header] + ranks).joined(separator: "; "))</p>"
    }

    private struct Group {
        var order: Int
        var label: String
        var spells: [String]
    }

    /// Innate, spontaneous and focus spells: each spell under its own (heightened) rank.
    private func listedGroups(_ spells: [JSONValue], cantripRank: Int) -> [Group] {
        var groups: [String: Group] = [:]
        for spell in spells {
            let (name, isConstant) = listedName(spell)
            let isCantrip = spell[path: "system.traits.value"].strings.contains("cantrip")
            let rank = isCantrip ? cantripRank : spell[path: "system.location.heightenedLevel"].optionalInt
                ?? spell[path: "system.level.value"].int
            let label = isConstant ? "Constant (\(ordinal(rank)))" : isCantrip ? "Cantrips " +
                "(\(ordinal(rank)))" : ordinal(rank)
            let order = isConstant ? 200 + rank : isCantrip ? 100 : 10 - rank
            groups[label, default: Group(order: order, label: label, spells: [])].spells.append(link(spell, name: name))
        }
        return groups.values.sorted { $0.order < $1.order }
    }

    /// Prepared spells: the slots list which spells are prepared at each rank, with repeats.
    private func preparedGroups(_ slots: JSONValue, spells: [JSONValue], cantripRank: Int) -> [Group] {
        let byID = Dictionary(spells.map { ($0["_id"].string, $0) }, uniquingKeysWith: { first, _ in first })
        return (0...10).reversed().compactMap { slotRank in
            let prepared = slots["slot\(slotRank)"]["prepared"].array.compactMap { byID[$0["id"].string] }
            guard !prepared.isEmpty else { return nil }
            let label = slotRank == 0 ? "Cantrips (\(ordinal(cantripRank)))" : ordinal(slotRank)
            return Group(order: slotRank == 0 ? 100 : 10 - slotRank, label: label, spells: counted(prepared))
        }
    }

    private func counted(_ spells: [JSONValue]) -> [String] {
        var order: [String] = []
        var counts: [String: (spell: JSONValue, count: Int)] = [:]
        for spell in spells {
            let name = listedName(spell).name
            if counts[name] == nil { order.append(name) }
            counts[name, default: (spell, 0)].count += 1
        }
        return order.compactMap { name in
            counts[name].map { link($0.spell, name: name) + ($0.count > 1 ? " (×\($0.count))" : "") }
        }
    }

    /// The spell's name without "(Constant)" or "(At Will)", and whether it is constant.
    private func listedName(_ spell: JSONValue) -> (name: String, isConstant: Bool) {
        var name = spell["name"].string
        let isConstant = name.hasSuffix("(Constant)")
        for suffix in ["(Constant)",
                       "(At Will)"] where name.hasSuffix(suffix) { name = String(name.dropLast(suffix.count)) }
        name = name.trimmingCharacters(in: .whitespaces).lowercased()
        let atWill = spell["name"].string.hasSuffix("(At Will)") ? " (at will)" : ""
        let uses = spell[path: "system.location.uses.max"].int
        return (name + atWill + (uses > 1 ? " (×\(uses))" : ""), isConstant)
    }

    /// A link to the compendium spell the creature's copy came from, when it is imported.
    private func link(_ spell: JSONValue, name: String) -> String {
        let source = spell[path: "_stats.compendiumSource"].string
        let sourceID = source.isEmpty ? spell[path: "flags.core.sourceId"].string : source
        return sourceID.isEmpty ? HTML.escape(name) : context.link(uuid: sourceID, name: name)
    }

    private func ordinal(_ rank: Int) -> String {
        let suffix = rank == 1 ? "st" : rank == 2 ? "nd" : rank == 3 ? "rd" : "th"
        return "\(rank)\(suffix)"
    }
}
