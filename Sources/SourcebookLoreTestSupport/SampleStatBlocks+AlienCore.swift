// Generated from the sf2e system's Starfinder Alien Core data, as `SampleStatBlocks.swift` is from Monster Core's.

extension SampleSourcebook {
    /// How Starfinder Alien Core asks to be credited.
    static let alienCoreCredit = """
        Starfinder Alien Core © 2025 Paizo Inc. Authors: Kate Baker, Lau Bannenberg, Rigby Bendele, Vishesh \
        Bhartiya, Joseph Blomquist, Jeremy Blum, Tineke Bolleman, Brent Bowser, Michael Bramnik, Patrick \
        Brennan, Charlie Brooks, Jessica Catalan, Brite Cheney, Jeremy Corff, Caryn DiMarco, Anthony Dollinger, \
        Steve Fidler, Kim Frandsen, Andrew D. Geels, Basheer Ghouse, Sen H.H.S., Katrina Hennessy, Thurston \
        Hillman, Joan Hong, Jenny Jarzabski, Sara Jeffers, Mikko Kallio, Lysle Kapp, Mike Kimmel, Dustin Knight, \
        Cole Kronewitter, Mahpiya, Letterio Mammoliti, Randal Meyer, Jacob W. Michaels, Matt Morris, Dennis \
        Muldoon, Quinn Murphy, Elizabeth V Nold, Chesley Oxendine, Emily Parks, Glen Parnell, Randy Price, Kyle \
        T. Raes, Jessica Redekop, Erin Roberts, James Rodehaver, David N. Ross, Pidj Sorensen, Joel Southall, \
        Kendra Leigh Speedling, Drew Taylor, Sam W Tennyson, Jalen Todd, Ruvaid Virk, Viditya Voleti, \
        Christopher Wasko, Nicholas Wasko, Jackson Wery, Shan Wolf, and Basil Wright.
        """

    /// Each Starfinder sample creature's stat block as Starfinder Alien Core prints it (ORC license): its traits,
    /// then a bold label and its value per line.
    static let alienCoreStatBlocks: [String: StatBlock] = [
        "Cybernetic Zombie": [
            ("", "MEDIUM MINDLESS TECH UNDEAD ZOMBIE"),
            ("Perception", "+3; darkvision"),
            ("Skills", "Athletics +5"),
            ("Str", "+2, Dex +4, Con +3, Int –5, Wis +0, Cha –2"),
            ("Items", "Integrated Commercial Laser Pistol"),
            ("AC", "15; Fort +5, Ref +6, Will +2"),
            ("HP",
             "40; Immunities death effects, disease, mental, paralyzed, poison, unconscious; "
             + "Weaknesses electricity 10, slashing 10"),
            ("Speed", "20 feet"),
            ("Ranged",
             "◆ laser pistol +6 (expend 2, reload 1, tech, range increment 40 feet), Damage 1d6 "
             + "fire"),
            ("Melee", "◆ fist +4, Damage 1d6+2 bludgeoning"),
            ("Cybernetics",
             "A cybernetic zombie's cybernetics can be disabled for 1 hour by a creature that "
             + "succeeds at a DC 15 check to disable device or Disable a System. Attempting to do so "
             + "can typically be done only while within reach of the zombie and is a 2-action "
             + "activity that has the manipulate trait. The cybernetics are also disabled for 1 hour "
             + "if the zombie takes any electricity damage. A cybernetic zombie with disabled "
             + "cybernetics is Slowed 1 and can't use any reactions."),
            ("Self-Destruct",
             "⤾ A cybernetic zombie must use this reaction unless its cybernetics are disabled "
             + "Trigger The cybernetic zombie is reduced to 0 Hit Points Effect The zombie's damaged "
             + "cybernetics explode, dealing 1d8 electricity damage in a 10-foot emanation (DC 15 "
             + "Reflex save). This ability destroys the zombie's integrated items and any tech items "
             + "on the zombie of 1st level or lower."),
            ("Void Healing", "")
        ],
        "Alloid (Ship Stealer)": [
            ("", "MEDIUM ABERRATION COSMIC"),
            ("Perception", "+9; darkvision"),
            ("Languages", "Aklo, Chthonian, Common, telepathy 30 feet"),
            ("Skills", "Acrobatics +8, Athletics +6, Computers +7, Deception +5, Piloting +10, Stealth +12"),
            ("Str", "+2, Dex +4, Con +2, Int +3, Wis +0, Cha –1"),
            ("Items", "Knife"),
            ("AC", "17; Fort +7, Ref +11, Will +5"),
            ("HP", "25; Resistances bludgeoning 2"),
            ("Speed", "25 feet"),
            ("Melee", "◆ knife +10 (agile, analog, finesse, versatile s), Damage 1d4+2 piercing"),
            ("Melee", "◆ knife +10 (agile, analog, thrown 10 feet, versatile s), Damage 1d4+2 piercing"),
            ("Ranged", "◆ toxic barb +10 (nonlethal, range increment 20 feet), Damage 1d4+2 piercing"),
            ("Malleable Flesh",
             "⤾ Trigger The alloid is hit or critically hit by a Strike or spell attack, and they "
             + "aren't Off-Guard Effect The alloid gains a +2 circumstance bonus to AC against the "
             + "triggering attack."),
            ("Flesh Putty",
             "(poison) Saving Throw DC 18 Fortitude Maximum Duration 12 hours Stage 1 Slowed 1 (1 "
             + "round) Stage 2 Slowed 2 (1 round) Stage 3 Paralyzed (1 round) Stage 4 Unconscious "
             + "with no Perception check to wake up (2d6 hours), and the target's body becomes "
             + "permanently malleable as per Putty Form until they've completely recovered from "
             + "flesh putty"),
            ("Putty Form",
             "◆ The alloid's body melts and molds to fit into tight spaces or stretches paper-thin "
             + "against a flat surface. They gain a +2 circumstance bonus to Stealth checks to hide "
             + "and to their Stealth DC when using this ability while adjacent to walls or within "
             + "tight spaces (at the GM's discretion). Alloids using this ability can squeeze into "
             + "spaces, including into closed containers or through doors, as though they were Tiny. "
             + "The alloid can use Putty Form again to return to their standard, more solid form."),
            ("Sneak Attack", "The alloid deals an additional 1d6 precision damage to Off-Guard creatures.")
        ],
        "Ferrofluid Ooze": [
            ("", "MEDIUM COSMIC METAL MINDLESS OOZE"),
            ("Perception", "+8; magnetic sense (precise) 100 feet"),
            ("Skills", "Athletics +9, Stealth +7"),
            ("Str", "+4, Dex +2, Con +1, Int –5, Wis +0, Cha +0"),
            ("AC", "13; Fort +11, Ref +2, Will +4"),
            ("HP",
             "60; Immunities bleed, critical hits, precision, unconscious, visual; Resistances "
             + "electricity 3, physical 3 (except adamantine)"),
            ("Speed", "20 feet, climb 20 feet; climb on metal surfaces only"),
            ("Melee", "◆ pseudopod +10 (versatile p), Damage 1d8+4 bludgeoning"),
            ("Magnetic Sense",
             "A ferrofluid ooze can feel magnetic fields, allowing it to detect large sources of "
             + "magnetic metal (Bulk 1 or greater) and items with the tech trait within the listed "
             + "range."),
            ("Magnetic Field",
             "(aura, metal, primal) 30 feet. A ferrofluid ooze is surrounded by a constant field "
             + "that interferes with nearby equipment. Items with the tech trait inside the aura "
             + "take a –1 circumstance penalty to all checks using them. Unattended metal objects in "
             + "the aura of 1 Bulk or less are pulled adjacent to the ooze."),
            ("Attach",
             "A ferrofluid ooze can attach itself to any creature its size or larger that has the "
             + "tech trait or is wearing or wielding items with the tech trait. This is similar to "
             + "Grab, but the ooze moves with that creature rather than holding it in place. As long "
             + "as the ooze is attached, it's Off-Guard, and the creature it's attached to must "
             + "succeed at a DC 11 Flat to Interact with items with the tech trait. On a failure, "
             + "the item becomes attached to the ooze (treat as if being held by the ooze)."),
            ("Demagnetization",
             "A ferrofluid ooze that takes fire damage has its magnetic field deactivated until "
             + "the end of the ooze's next turn. It releases itself from any creature it was "
             + "attached to, drops any held items, and can't use Magnetic Leap or Attach until its "
             + "magnetic field returns."),
            ("Magnetic Leap",
             "◆ The ferrofluid ooze instantly Attaches to a creature within its magnetic field "
             + "that meets the requirements of that ability. A ferrofluid ooze can't use this "
             + "ability again for 1d4 rounds.")
        ],
        "Mutant Troll": [
            ("", "LARGE COSMIC GIANT HUMANOID MUTANT TROLL"),
            ("Perception", "+18; darkvision"),
            ("Languages", "Common, Jotun"),
            ("Skills", "Athletics +21, Crafting +16, Intimidation +19, Piloting +13"),
            ("Str", "+6, Dex +0, Con +4, Int +1, Wis +3, Cha –1"),
            ("AC", "26; Fort +21, Ref +16, Will +16"),
            ("HP", "178"),
            ("Speed", "25 feet"),
            ("Melee", "◆ jaw +21, Damage 2d10+10 piercing"),
            ("Melee", "◆ claw +21 (agile, reach 10 feet), Damage 2d6+10 slashing"),
            ("Regeneration 20 (deactivated by cold or electricity)", ""),
            ("Mauling Flurry",
             "◆◆ Frequency once per round Effect The mutant troll makes two claw Strikes against "
             + "one target without increasing their multiple attack penalty. If both Strikes deal "
             + "damage, the troll can attempt a jaw Strike against that target with the normal "
             + "multiple attack penalty."),
            ("Mutated Split",
             "◆◆◆ Frequency once per day Effect The mutant troll rips themself apart into two "
             + "separate Large-sized entities, sharing one fractured sentience between them. While "
             + "in this form, the mutant troll halves share a communal Hit Point pool and have 4 "
             + "actions to share between them on their turn. If both halves are included in an area "
             + "of effect, they must both attempt saving throws, taking the worse result, but only "
             + "taking damage once."),
            ("Reforming Merge",
             "◆ (manipulate) Requirements The mutant troll halves are adjacent to each other "
             + "Effect The mutant troll halves re-form into a single entity."),
            ("Splurting Slime",
             "◆◆ Requirements The mutant troll is in its Mutated Split form, and both halves are "
             + "within 30 feet of each other Effect The duplicated beings spray mutated flesh and "
             + "organs toward each other, absorbing most of the pieces but raining down acidic "
             + "viscera on any creatures caught in the 10-foot-wide line between them. These "
             + "creatures take 8d8 acid damage with a DC 27 Reflex save. The troll can't use "
             + "Splurting Slime again for 1d4 rounds. Critical Success The creature is unaffected. "
             + "Success The creature takes half damage. Failure The creature takes full damage and "
             + "is Sickened 1. Critical Failure The creature takes double damage and is Sickened 2.")
        ]
    ]
}
