import Foundation

/// Creature and hazard fixtures.
enum Actors {
    static func action(_ id: String, _ name: String, category: String, type: String, count: Int? = nil,
                       slug: String = "", traits: [String] = []) -> [String: Any] {
        ["_id": id, "name": name, "type": "action",
         "system": ["category": category, "actionType": ["value": type],
                    "actions": ["value": count.map { $0 as Any } ?? NSNull()],
                    "slug": slug, "traits": ["value": traits], "description": ["value": "<p>\(name) text.</p>"]]]
    }

    nonisolated(unsafe) static let goblinItems: [[String: Any]] = [
        ["_id": "w1", "name": "Dogslicer", "type": "weapon", "system": ["quantity": 1]],
        ["_id": "w2", "name": "Javelin", "type": "weapon", "system": ["quantity": 4]],
        ["_id": "l1", "name": "Goblin Lore", "type": "lore", "system": ["mod": ["value": 4]]],
        ["_id": "m1", "name": "Dogslicer", "type": "melee",
         "system": ["bonus": ["value": 7], "traits": ["value": ["agile"]], "range": NSNull(),
                    "attackEffects": ["value": ["grab", "knockdown"]],
                    "damageRolls": ["a": ["damage": "1d6", "damageType": "bleed", "category": "persistent"],
                                    "b": ["damage": "1d6 + 2", "damageType": "slashing"],
                                    "c": ["damage": "1d4", "damageType": "fire"]]]],
        ["_id": "m2", "name": "Javelin", "type": "melee",
         "system": ["bonus": ["value": -1], "traits": ["value": []], "range": ["increment": 30],
                    "damageRolls": ["a": ["damage": "1d6", "damageType": "piercing"]]]],
        ["_id": "m3", "name": "Spit", "type": "melee",
         "system": ["bonus": ["value": 3], "traits": ["value": []], "range": ["max": 10], "damageRolls": [:]]],
        action("a1", "Grab", category: "offensive", type: "action", count: 1, slug: "grab"),
        action("a2", "Goblin Scuttle", category: "defensive", type: "reaction", traits: ["move"]),
        action("a3", "Smell", category: "interaction", type: "passive"),
        ["_id": "e1", "name": "Arcane Innate Spells", "type": "spellcastingEntry",
         "system": ["spelldc": ["dc": 18, "value": 10], "prepared": ["value": "innate"], "slots": [:]]],
        ["_id": "e2", "name": "Arcane Prepared Spells", "type": "spellcastingEntry",
         "system": ["spelldc": ["dc": 20, "value": 0], "prepared": ["value": "prepared"],
                    "autoHeightenLevel": ["value": 2],
                    "slots": ["slot0": ["prepared": [["id": "s4"]]],
                              "slot3": ["prepared": [["id": "s5"], ["id": "s5"], ["id": "zz"]]]]]],
        spell("s1", "Light (At Will)", entry: "e1", level: 1, traits: ["cantrip"], uses: 0),
        spell("s2", "Fireball", entry: "e1", level: 3, uses: 3, source: "Compendium.pf2e.spells-srd.Item.fb1"),
        spell("s3", "See Invisibility (Constant)", entry: "e1", level: 2),
        spell("s4", "Light", entry: "e2", level: 1, traits: ["cantrip"]),
        spell("s5", "Fireball", entry: "e2", level: 3, source: "Compendium.pf2e.spells-srd.Item.fb1")
    ]

    static func spell(_ id: String, _ name: String, entry: String, level: Int, traits: [String] = [],
                      uses: Int = 0, source: String = "") -> [String: Any] {
        ["_id": id, "name": name, "type": "spell", "_stats": ["compendiumSource": source],
         "system": ["level": ["value": level], "traits": ["value": traits],
                    "location": ["value": entry, "uses": ["max": uses]]]]
    }

    nonisolated(unsafe) static let goblin: [String: Any] = [
        "_id": "goblin1", "name": "Goblin Warrior", "type": "npc", "img": "systems/pf2e/icons/default-icons/npc.svg",
        "items": goblinItems,
        "system": [
            "abilities": ["str": ["mod": 0], "dex": ["mod": 3], "con": ["mod": 1], "int": ["mod": 0],
                          "wis": ["mod": -1], "cha": ["mod": 1]],
            "attributes": ["ac": ["value": 16, "details": "18 with shield"], "allSaves": ["value": "+1 vs. magic"],
                           "hp": ["max": 6, "details": "regeneration 2"], "hardness": 0,
                           "immunities": [["type": "fire"]],
                           "resistances": [["type": "physical", "value": 5, "exceptions": ["adamantine"],
                                            "doubleVs": ["critical-hits"]]],
                           "weaknesses": [["type": "cold-iron", "value": 3, "exceptions": [["label": "magic"]]]],
                           "speed": ["value": 25, "otherSpeeds": [["type": "climb", "value": 15]],
                                     "details": "ignores difficult terrain"]],
            "perception": ["mod": 2, "details": "smell 30 feet",
                           "senses": [["type": "darkvision"], ["type": "scent", "acuity": "imprecise", "range": 30]]],
            "saves": ["fortitude": ["value": 5], "reflex": ["value": 7], "will": ["value": 3]],
            "skills": ["stealth": ["base": 5], "acrobatics": ["base": 5]],
            "traits": ["rarity": "common", "size": ["value": "sm"], "value": ["goblin", "humanoid"]],
            "details": ["level": ["value": -1], "languages": ["value": ["goblin", "common"], "details": "telepathy"],
                        "publicNotes": "<p>Goblins fight in groups.</p>", "publication": ["title": "Monster Core"]]
        ]
    ]

    nonisolated(unsafe) static let trap: [String: Any] = [
        "_id": "trap1", "name": "Poison Dart Trap", "type": "hazard",
        "items": [action("t1", "Dart", category: "offensive", type: "reaction")],
        "system": [
            "attributes": ["ac": ["value": 18], "hardness": 5, "hp": ["max": 20, "brokenThreshold": 10],
                           "stealth": ["value": 10, "details": "(trained)"]],
            "saves": ["fortitude": ["value": 8], "reflex": ["value": 0]],
            "traits": ["rarity": "uncommon", "value": ["mechanical", "trap"]],
            "details": ["level": ["value": 2], "isComplex": true, "description": "<p>Darts fly.</p>",
                        "disable": "<p>@Check[thievery|dc:20] to jam it</p>", "routine": "<p>Shoots.</p>",
                        "reset": "", "publication": ["title": "GM Core"]]
        ]
    ]

    nonisolated(unsafe) static let robot: [String: Any] = [
        "_id": "robot1", "name": "Security Robot", "type": "npc", "img": "",
        "items": [],
        "system": [
            "abilities": [:], "attributes": ["ac": ["value": 20], "hp": ["max": 30], "speed": ["value": 0]],
            "perception": ["mod": 5, "senses": []], "saves": [:], "skills": [:],
            "traits": ["rarity": "common", "size": ["value": "med"], "value": ["tech"]],
            "details": ["level": ["value": 2], "languages": ["value": []], "publicNotes": ""]
        ]
    ]

    nonisolated(unsafe) static let all: [String: [String: Any]] = [
        "pf2e/pathfinder-monster-core/goblin-warrior": goblin,
        "pf2e/hazards/poison-dart-trap": trap,
        "sf2e/starfinder-society-bestiary/security-robot": robot
    ]
}
