import FieldGuideKit
import Foundation

/// Details of ancestries, heritages, backgrounds, classes and deities.
enum CharacterOptionLines {
    static func html(_ document: SourceDocument, context: PageContext) -> String {
        let system = document.systemData
        switch document.category {
        case .ancestries: return ancestry(system, context: context)
        case .heritages:
            let ancestry = system["ancestry"]
            let link = ancestry.isNull ? "Versatile" : context.link(uuid: ancestry["uuid"].string,
                                                                    name: ancestry["name"].string)
            return HTML.line("Ancestry", link)
        case .backgrounds: return background(system, context: context)
        case .classes: return characterClass(system, context: context)
        case .deities: return deity(system, context: context)
        default: return ""
        }
    }

    private static func ancestry(_ system: JSONValue, context: PageContext) -> String {
        let languages = system[path: "languages.value"].strings.map(Words.title).joined(separator: ", ")
        let additional = system[path: "additionalLanguages.value"].strings.map(Words.title).joined(separator: ", ")
        return [
            HTML.line("Hit Points", String(system["hp"].int)),
            HTML.line("Size", Formatting.sizes[system["size"].string] ?? ""),
            HTML.line("Speed", "\(system["speed"].int) feet"),
            HTML.line("Attribute Boosts", boosts(system["boosts"])),
            HTML.line("Attribute Flaw", boosts(system["flaws"])),
            HTML.line("Languages", HTML.escape(languages)),
            HTML.line("Additional Languages", HTML.escape(additional)),
            HTML.line("Vision",
                      HTML.escape(Words.label(system["vision"].string == "normal" ? "" : system["vision"].string))),
            features(system["items"], context: context)
        ].joined()
    }

    private static func background(_ system: JSONValue, context: PageContext) -> String {
        let skills = system[path: "trainedSkills.value"].strings.map(Words.title)
            + system[path: "trainedSkills.lore"].strings
        return [
            HTML.line("Attribute Boosts", boosts(system["boosts"])),
            HTML.line("Trained Skills", HTML.escape(skills.joined(separator: ", "))),
            features(system["items"], context: context, label: "Feat")
        ].joined()
    }

    private static func characterClass(_ system: JSONValue, context: PageContext) -> String {
        let keys = system[path: "keyAbility.value"].strings.compactMap { Formatting.attributes[$0] }
        return [
            HTML.line("Key Attribute", HTML.escape(keys.joined(separator: " or "))),
            HTML.line("Hit Points", "\(system["hp"].int) plus your Constitution modifier"),
            features(system["items"], context: context, label: "Class Features", showsLevel: true)
        ].joined()
    }

    private static func deity(_ system: JSONValue, context: PageContext) -> String {
        let sanctification = system["sanctification"]
        let what = sanctification["what"].strings.map(Words.label).joined(separator: " or ")
        let sanctificationText = what.isEmpty ? "" : "\(sanctification["modal"].string) be \(what)"
        let spells = system["spells"].object.sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }.map { rank, uuid in
            "<strong>\(rank)</strong> " + context.link(uuid: uuid.string, name: Enricher.linkedName(uuid.string))
        }
        return [
            HTML.line("Sanctification", HTML.escape(sanctificationText)),
            HTML.line("Divine Attribute",
                      HTML.escape(system["attribute"].strings.compactMap { Formatting.attributes[$0] }
                .joined(separator: " or "))),
            HTML.line("Divine Font", HTML.escape(system["font"].strings.joined(separator: " or "))),
            HTML.line("Divine Skill", HTML.escape(system["skill"].strings.map(Words.title).joined(separator: ", "))),
            HTML.line("Favored Weapon",
                      HTML.escape(system["weapons"].strings.map(Words.label).joined(separator: ", "))),
            HTML.line("Domains",
                      HTML.escape(system[path: "domains.primary"].strings.map(Words.label).joined(separator: ", "))),
            HTML.line("Alternate Domains", HTML.escape(system[path: "domains.alternate"].strings.map(Words.label)
                .joined(separator: ", "))),
            HTML.line("Cleric Spells", spells.joined(separator: ", "))
        ].joined()
    }

    /// "Dexterity, Wisdom, Free": each boost slot is one attribute, a choice of two, or free.
    private static func boosts(_ boosts: JSONValue) -> String {
        boosts.object.keys.sorted().map { key in
            let options = boosts[key]["value"].strings
            if options.count >= 6 { return "Free" }
            return options.compactMap { Formatting.attributes[$0] }.joined(separator: " or ")
        }.joined(separator: ", ")
    }

    /// The features an option grants, as links, by level when `showsLevel`.
    private static func features(_ items: JSONValue, context: PageContext, label: String = "Features",
                                 showsLevel: Bool = false) -> String {
        let entries = items.object.values.sorted { ($0["level"].int, $0["name"].string) < ($1["level"].int,
            $1["name"].string) }
        let links = entries.map { item in
            (showsLevel ? "<strong>\(item["level"].int)</strong> " : "")
                + context.link(uuid: item["uuid"].string, name: item["name"].string)
        }
        return HTML.line(label, links.joined(separator: ", "))
    }
}
