// Generated from the pf2e system's Pathfinder Monster Core data; see `statBlocks`.

extension SampleSourcebook {
    /// Each sample creature's stat block as Pathfinder Monster Core prints it (ORC license): its traits, then
    /// a bold label and its value per line.
    public static let statBlocks: [String: [(label: String, value: String)]] = [
        "Goblin Warrior": [
            ("", "SMALL GOBLIN HUMANOID"),
            ("Perception", "+2; darkvision"),
            ("Languages", "Goblin, Common"),
            ("Skills", "Acrobatics +5, Athletics +2, Nature +1, Stealth +5"),
            ("Str", "+0, Dex +3, Con +1, Int +0, Wis –1, Cha +1"),
            ("Items", "Dogslicer, Shortbow, Leather Armor"),
            ("AC", "16; Fort +5, Ref +7, Will +3"),
            ("HP", "6"),
            ("Speed", "25 feet"),
            ("Melee", "◆ dogslicer +7 (agile, backstabber, finesse), Damage 1d6 slashing"),
            ("Ranged", "◆ shortbow +7 (deadly d10, reload 0, range increment 60 feet), Damage 1d6 piercing"),
            ("Goblin Scuttle",
             "⤾ Trigger A goblin ally ends a move action adjacent to the goblin. Effect "
             + "The goblin warrior Steps.")
        ],
        "Goblin Pyro": [
            ("", "SMALL GOBLIN HUMANOID"),
            ("Perception", "+4; darkvision"),
            ("Languages", "Common, Goblin"),
            ("Skills", "Acrobatics +7, Fire Lore +7, Stealth +7"),
            ("Str", "+0, Dex +4, Con +2, Int +0, Wis –1, Cha +3"),
            ("Items", "Torch"),
            ("AC", "17; Fort +5, Ref +9, Will +4"),
            ("HP", "15"),
            ("Speed", "25 feet"),
            ("Arcane Spontaneous Spells",
             "DC 16, attack +6; 1st (3 slots) breathe fire, grease; Cantrips (1st) ignition, "
             + "light, tangle vine, telekinetic hand"),
            ("Goblin Scuttle",
             "⤾ Trigger A goblin ally ends a move action adjacent to the goblin. Effect "
             + "The goblin pyro Steps.")
        ],
        "Hobgoblin Soldier": [
            ("", "MEDIUM HOBGOBLIN HUMANOID"),
            ("Perception", "+7; darkvision"),
            ("Languages", "Common, Goblin"),
            ("Skills", "Athletics +6, Stealth +6"),
            ("Str", "+3, Dex +3, Con +2, Int +0, Wis +2, Cha –1"),
            ("Items", "Longsword, Shortbow, Breastplate"),
            ("AC", "18; Fort +5, Ref +6, Will +5"),
            ("HP", "20"),
            ("Speed", "25 feet"),
            ("Melee", "◆ longsword +8 (versatile p), Damage 1d8+3 slashing"),
            ("Ranged", "◆ shortbow +8 (deadly d10, reload 0, range increment 60 feet), Damage 1d6 piercing"),
            ("Formation",
             "When it's adjacent to at least two other allies, the hobgoblin soldier gains a +1 "
             + "circumstance bonus to AC and saving throws. This bonus increases to +2 to Reflex "
             + "saves against area effects."),
            ("Reactive Strike", "⤾"),
            ("Shield Block", "⤾")
        ],
        "Kholo Hunter": [
            ("", "MEDIUM HUMANOID KHOLO"),
            ("Perception", "+7; darkvision"),
            ("Languages", "Kholo, Common"),
            ("Skills", "Acrobatics +7, Athletics +8, Intimidation +4, Stealth +7, Survival +5"),
            ("Str", "+4, Dex +3, Con +2, Int –1, Wis +1, Cha +0"),
            ("Items", "Battle Axe, Shortbow, Leather Armor"),
            ("AC", "18; Fort +8, Ref +7, Will +7"),
            ("HP", "29"),
            ("Speed", "25 feet"),
            ("Melee", "◆ battle axe +10 (sweep), Damage 1d8+4 slashing"),
            ("Melee", "◆ jaws +10 (agile, unarmed), Damage 1d8+2 piercing"),
            ("Ranged", "◆ shortbow +10 (deadly d10, range increment 60 feet), Damage 1d6 piercing"),
            ("Pack Attack",
             "A kholo hunter deals 1d4 extra damage to any creature that's within reach of at "
             + "least two of the kholo hunter's allies."),
            ("Rugged Travel",
             "A kholo ignores the first square of difficult terrain they move into each time they "
             + "Step or Stride.")
        ]
    ]
}
