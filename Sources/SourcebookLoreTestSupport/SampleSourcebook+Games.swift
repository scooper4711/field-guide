import SourcebookLore

/// What each game's sample prints: deities, an ancestry and a class at the top of Field Guide's lists, and creatures
/// with their bestiary's stat blocks (Monster Core's, Alien Core's) and Paizo blog art.
extension SampleSourcebook {
    public static let all = [pathfinder, starfinder]

    public static let pathfinder = SampleSourcebook(
        book: SourcebookList.pathfinderSample,
        subtitle: "Placeholder lore for trying Field Guide's Sourcebooks; the stat blocks are Monster Core's.",
        families: [
            Family(name: "Goblin", creatures: [
                Creature("Goblin Warrior", level: -1, art: "s2_0254_PZO160709_Bilia.png"),
                Creature("Goblin Pyro", level: 1, art: "rcv_PZO2109_FireworkTechnician.jpg")
            ]),
            Family(name: "Hobgoblin", creatures: [
                Creature("Hobgoblin Soldier", level: 1, art: "20287_031521_Kaoling-Hobgoblin.jpg")
            ]),
            Family(name: "Kholo", creatures: [
                Creature("Kholo Hunter", level: 2, art: "20007_022820_GnollWarriorjpg.jpg")
            ])
        ],
        deities: ["Aakriti", "Abadar", "Iomedae"],
        details: [
            Details(name: "Elf", sections: ["Physical Description", "Society", "You Might...", "Others Probably..."],
                    rules: "Elf Heritages"),
            Details(name: "Fighter", sections: ["During Combat Encounters...", "While Exploring...", "You Might..."],
                    rules: "Class Features")
        ],
        statBlocks: monsterCoreStatBlocks,
        credit: monsterCoreCredit)

    /// Starfinder's Abadar is the same god centuries later, with a write-up of his own.
    public static let starfinder = SampleSourcebook(
        book: SourcebookList.starfinderSample,
        subtitle: "Placeholder lore for trying Field Guide's Sourcebooks; the stat blocks are Alien Core's.",
        families: [
            Family(name: "Cybernetic Zombie", creatures: [
                Creature("Cybernetic Zombie", level: -1, art: "20755_PZO9500_25_CyberneticZombie_770x1000.png")
            ]),
            Family(name: "Alloid", creatures: [
                Creature("Alloid (Ship Stealer)", level: 2, art: "s2_0121_Alloid_1200x1500.png")
            ]),
            Family(name: "Ferrofluid Ooze", creatures: [
                Creature("Ferrofluid Ooze", level: 2, art: "s2_0328_Ferrofluid_1500x1200.png")
            ]),
            Family(name: "Mutant Troll", creatures: [
                Creature("Mutant Troll", level: 9, art: "s2_0185_Troll_Mutant_1500x1200.png")
            ])
        ],
        deities: ["Abadar", "Angradd"],
        details: [
            Details(name: "Android", sections: ["Physical Description", "Society", "You Might...",
                                                "Others Probably..."],
                    rules: "Android Heritages"),
            Details(name: "Envoy", sections: ["During Combat Encounters...", "During Social Encounters...",
                                              "You Might..."],
                    rules: "Class Features")
        ],
        statBlocks: alienCoreStatBlocks,
        credit: alienCoreCredit,
        seed: "Starfinder")
}
