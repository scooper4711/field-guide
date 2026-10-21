import Foundation

/// The fake repository's pack documents, by path under `packs/`.
enum Documents {
    nonisolated(unsafe) static let all: [String: [String: Any]] = SpellsAndItems.all
        .merging(Actors.all) { first, _ in first }

    static func item(_ id: String, _ name: String, _ type: String, img: String = "",
                     system: [String: Any]) -> [String: Any] {
        ["_id": id, "name": name, "type": type, "img": img, "system": system]
    }

    static func traits(_ values: [String], rarity: String = "common") -> [String: Any] {
        ["rarity": rarity, "value": values]
    }

    static func publication(_ title: String) -> [String: Any] { ["title": title] }
}

enum SpellsAndItems {
    nonisolated(unsafe) static let fireballText = "<p>@Template[burst|distance:20] of fire deals " +
        "@Damage[(6d6)[fire]] damage "
        + "(@Check[reflex|dc:20|basic]). Targets become @UUID[Compendium.pf2e.conditionitems.Item.Frightened]{Scared} "
        + "for [[/r 1d4 #rounds]]{1d4 rounds}; see @UUID[Compendium.pf2e.journals.JournalEntry.x] and @Wrong[x]{odd}. "
        + "@Localize[PF2E.Greeting]</p>"

    nonisolated(unsafe) static let all: [String: [String: Any]] = [
        "pf2e/spells/rank-3/fireball": Documents.item("fb1", "Fireball", "spell",
                                                      img: "systems/pf2e/icons/spells/fireball.webp",
            system: ["level": ["value": 3], "traits": ["rarity": "common", "value": ["fire", "manipulate"],
                                                       "traditions": ["arcane", "primal"]],
                     "time": ["value": "2"], "range": ["value": "500 feet"], "area": ["type": "burst", "value": 20],
                     "defense": ["save": ["basic": true, "statistic": "reflex"]], "duration": ["value": ""],
                     "cost": ["value": "a pinch of sulfur"], "target": ["value": ""],
                     "description": ["value": fireballText], "publication": Documents.publication("Player Core")]),
        "pf2e/spells/light": Documents.item("li1", "Light", "spell", img: "icons/missing.webp",
            system: ["level": ["value": 1], "traits": ["rarity": "uncommon", "value": ["cantrip", "focus", "light"],
                                                       "traditions": []],
                     "time": ["value": "1 minute"], "duration": ["value": "1 hour", "sustained": true],
                     "defense": ["passive": ["statistic": "will"]], "ritual": ["primary": ["check": "x"]],
                     "description": ["value": ""], "publication": Documents.publication("Player Core")]),
        "pf2e/feats/power-attack": Documents.item("pa1", "Power Attack", "feat",
            system: ["level": ["value": 1], "category": "classfeature", "traits": Documents.traits(["fighter",
                "flourish"]),
                     "actionType": ["value": "action"], "actions": ["value": 2],
                     "prerequisites": ["value": [["value": "trained in Athletics"]]],
                     "frequency": ["max": 1, "per": "PT10M"], "trigger": ["value": "<p>You see a foe</p>"],
                     "requirements": ["value": "You wield a weapon"], "description": ["value": "<p>Hit hard.</p>"]]),
        "pf2e/equipment/longsword": Documents.item("ls1", "Longsword", "weapon", img: "icons/weapons/sword.webp",
            system: ["level": ["value": 0], "traits": Documents.traits(["versatile-p", "deadly-d10"]),
                     "price": ["value": ["gp": 1,
                                         "sp": 5]], "bulk": ["value": 1], "usage": ["value": "held-in-one-hand"],
                     "damage": ["dice": 1, "die": "d8", "damageType": "slashing"], "category": "martial",
                     "group": "sword", "range": 30, "reload": ["value": "1"],
                     "description": ["value": "<p>Sword.</p>"]]),
        "pf2e/equipment/leather-armor": Documents.item("la1", "Leather Armor", "armor",
            system: ["level": ["value": 0], "traits": Documents.traits([]), "price": ["value": ["gp": 2]],
                     "bulk": ["value": 0.1], "acBonus": 1, "dexCap": 4, "strength": 10, "checkPenalty": -1,
                     "speedPenalty": -5, "category": "light", "group": "leather"]),
        "pf2e/equipment/steel-shield": Documents.item("ss1", "Steel Shield", "shield",
            system: ["level": ["value": 0], "traits": Documents.traits([]), "price": ["value": ["sp": 2]],
                     "bulk": ["value": 0], "acBonus": 2, "hardness": 5, "hp": ["max": 20]]),
        "pf2e/equipment/potion": Documents.item("po1", "Potion", "consumable",
            system: ["level": ["value": 1], "traits": Documents.traits(["consumable"]),
                     "price": ["value": ["cp": 4], "per": 10], "bulk": ["value": "x"]]),
        "pf2e/equipment/bag": Documents.item("bg1", "Bag", "backpack",
            system: ["level": ["value": 0], "traits": Documents.traits([]), "price": ["value": [:]]]),
        "pf2e/conditions/frightened": Documents.item("fr1", "Frightened", "condition",
            img: "systems/pf2e/icons/missing.svg",
            system: ["traits": ["value": []], "description": ["value": "<p>You're scared.</p>"]]),
        "pf2e/actions/grab": Documents.item("gr1", "Grab", "action",
            system: ["traits": Documents.traits([]), "actionType": ["value": "reaction"],
                     "actions": ["value": NSNull()],
                     "description": ["value": "<p>Hold on.</p>"]]),
        "pf2e/spell-effects/effect": Documents.item("ef1", "Spell Effect: Fireball", "effect", system: [:]),
        "pf2e/classes/fighter": Documents.item("fi1", "Fighter", "class",
            system: ["traits": Documents.traits([]), "hp": 10, "keyAbility": ["value": ["str", "dex"]],
                     "items": ["a": ["level": 1, "name": "Power Attack", "uuid": "Compendium.pf2e.feats-srd.Item.pa1"],
                               "b": ["level": 3, "name": "Bravery",
                                     "uuid": "Compendium.pf2e.classfeatures.Item.Bravery"]],
                     "description": ["value": "<p>Fights.</p>"]]),
        "pf2e/ancestries/elf": Documents.item("el1", "Elf", "ancestry",
            system: ["traits": Documents.traits(["elf", "humanoid"]), "hp": 6, "size": "med", "speed": 30,
                     "boosts": ["0": ["value": ["dex"]], "1": ["value": ["int"]],
                                "2": ["value": ["str", "dex", "con", "int", "wis", "cha"]]],
                     "flaws": ["0": ["value": ["con"]]], "languages": ["value": ["common", "elven"]],
                     "additionalLanguages": ["value": ["draconic"]], "vision": "low-light-vision", "items": [:]]),
        "pf2e/heritages/ancient-elf": Documents.item("ae1", "Ancient Elf", "heritage",
            system: ["traits": Documents.traits([]),
                     "ancestry": ["name": "Elf", "uuid": "Compendium.pf2e.ancestries.Item.el1"]]),
        "pf2e/heritages/versatile": Documents.item("ve1", "Versatile", "heritage",
            system: ["traits": Documents.traits([]), "ancestry": NSNull()]),
        "pf2e/backgrounds/acolyte": Documents.item("ac1", "Acolyte", "background",
            system: ["traits": Documents.traits([]), "boosts": ["0": ["value": ["int", "wis"]]],
                     "trainedSkills": ["value": ["religion"], "lore": ["Scribing Lore"]], "items": [:]]),
        "pf2e/deities/abadar": Documents.item("ab1", "Abadar", "deity",
            system: ["description": ["value": "<p>Abadar keeps the First Vault.</p>"],
                     "category": "deity", "sanctification": ["modal": "can", "what": ["holy"]], "attribute": ["con"],
                     "font": ["heal"], "skill": ["society"], "weapons": ["crossbow"],
                     "domains": ["primary": ["cities"], "alternate": ["wealth"]],
                     "spells": ["1": "Compendium.pf2e.spells-srd.Item.Light",
                                "3": "Compendium.pf2e.spells-srd.Item.Fireball"]]),
        "sf2e/conditions/glitching": Documents.item("gl1", "Glitching", "effect",
            system: ["traits": ["value": []], "description": ["value": "<p>Sparks.</p>"]])
    ]
}
