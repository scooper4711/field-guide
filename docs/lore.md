# Lore left out of Field Guide, and where it comes back from

The import leaves out the setting's lore: Paizo's Reserved Material, which neither the ORC License nor the
Community Use Policy lets Field Guide reproduce. No build ships it; there is no option to keep it. The app reads it
from the user's own PDFs instead (Sourcebooks in the sidebar), on their device. Lore the Paizo Blog published stays:
the Community Use Policy lets a free project use the blog's text.

Counts are for pf2e-8.6.1 and sf2e-1.6.1 (`pf2e.release`), from `FieldGuideLoreSurvey`.

## What is left out

| Lore | Entries | Comes back from |
|---|---|---|
| Creatures' descriptions (the Lore tab) | 4556 | The bestiary or adventure that prints the creature (`CreatureWriteups`) |
| Deities' write-ups | 511 | The books `sourcebooks.json` names for each deity (`DeityWriteups`, `DeityTable`) |
| Ancestries' and classes' Details: their setting prose | 142 pages | The book that introduces the ancestry or class (`DetailsWriteups`) |

The rest of a Details page is rules, which the import keeps: a class's key attribute and Hit Points, "<Ancestry>
Mechanics" and its heritages, "Initial Proficiencies" and the class features. `DetailsPage` splits a page where its
lore is ("Elf" through "Popular Anathema", or "Roleplaying the Fighter" through "Others Probably...") and leaves a
marker there; the app puts the lore from the user's book in its place, or a note naming the book to add.

## How creature lore comes back

- A bestiary's creature is read from its stat block ("GOBLIN WARRIOR CREATURE –1") back to the heading that names
  it, and its family's introduction from the taller heading above ("Goblin"). A creature without its own heading
  (an adult dragon after the young one) shares the nearest one above. Prose stops at a stat block or a line that
  opens with a bold label, so a stat block the page's order puts early can't run into it.
- Monster Core and Monster Core 2 remaster Bestiaries 1–3. A creature from any of the five books takes its lore from
  the first of them the user has read that prints it: Monster Core, Monster Core 2, the book Foundry credits, then
  the other Bestiaries. Each book's lore is stored separately and chosen when shown, so the order the books are read
  in doesn't matter.
- 936 adventure creatures have lore Foundry copied from a bestiary creature (Kingmaker's "Hooktongue Hydra" is the
  hydra). `sourcebooks.json` maps each to that creature by name, so its lore comes from the user's bestiaries
  without reading the adventure.

## How ancestry and class lore comes back

The ancestry's or class's name as a title ("ELF", "FIGHTER"), its introduction, then its sections up to where its
rules begin ("Elf Heritages", "Class Features", "ANDROID HERITAGES"). Sections are the ones Paizo's books use (You
Might..., Others Probably..., Physical Description, Society, Beliefs, Names, Roleplaying, During Combat
Encounters...), whether set in title case or in capitals; boxes of rules under other headings in capitals ("KEY
ATTRIBUTE", "LOW-LIGHT VISION") are left out. Bullets stay bulleted and "Popular Edicts" stays a labeled line.

## The sample sourcebook

`Field Guide Sample Monster Core.pdf` (`Resources/Review/`, written by `FieldGuideLoreSurvey sample`) has placeholder
text under real names: creatures (Goblin Warrior, Goblin Commando, Wolf, Dire Wolf, Athraxer), deities (Abadar,
Iomedae), an ancestry (Elf) and a class (Fighter), laid out as Paizo's books are. It is for App Review and anyone
without the books; its lore comes after any real book's.

## How well the books read

`FieldGuideLoreSurvey creatures` and `details` compare what the readers find with Foundry's copy of the text. A
match shares at least 60% of its words with Foundry's (most below that are the book's fuller text, or Foundry's own
mix-ups). **Faults** counts flaws in the text read, which the book may have more of than Foundry but must not
garble: words broken in two ("shor ter"), hyphens left from a line break, words run together, paragraphs split
mid-sentence, and stray characters (pictures, control characters). A word Foundry writes as two and the book as one
("willpower", "rainforest") is flagged but isn't a fault.

### Creatures

Creatures Foundry credits to the book with lore; how many the reader finds; how many match; the families found
among the creatures that have one; and faults.

| Book | Creatures | Found | Matching | Families | Faults |
|---|---|---|---|---|---|
| Pathfinder Monster Core | 497 | 475 | 466 | 341/383 | 0 |
| Starfinder Alien Core | 234 | 233 | 230 | 142/145 | 0 |
| Pathfinder Bestiary | 164 | 162 | 155 | 130/131 | 0 |
| Pathfinder Bestiary 2 | 160 | 155 | 155 | 10/10 | 0 |
| Pathfinder Bestiary 3 | 165 | 146 | 142 | 66/87 | 0 |
| Pathfinder Monster Core 2 | 440 | 435 | 401 | 179/214 | 4 |
| Pathfinder NPC Core | 270 | 267 | 261 | 252/265 | 0 |
| Pathfinder Howl of the Wild | 71 | 68 | 56 | 0/12 | 0 |
| Pathfinder Rage of Elements | 78 | 73 | 68 | 4/28 | 0 |
| Pathfinder #220: Crypt of Runes | 25 | 12 | 2 | 0/5 | 0 |
| Pathfinder Adventure: Rusthenge | 11 | 4 | 0 | 0/9 | 0 |
| Pathfinder #192: Worst of All Possible Worlds | 33 | 11 | 1 | 0/18 | 0 |
| Pathfinder Society Scenario #3-13: Guardian's Covenant | 25 | 0 | 0 | 0/20 | 0 |
| Starfinder Murder in Metal City Deluxe Adventure | 11 | 0 | 0 | 0/9 | 0 |

The faults left are two of Monster Core 2's flagged-but-real words and Bestiary 2's "nea r" (in Platecarpus and
Tylosaurus), which the PDF itself spaces apart.

### Ancestries and classes

Details pages Foundry has for the book's ancestries and classes; how many the reader finds; how many match. None
has a fault.

| Book | Pages | Found | Matching |
|---|---|---|---|
| Pathfinder Player Core | 16 | 16 | 16 |
| Pathfinder Player Core 2 | 16 | 16 | 16 |
| Pathfinder Howl of the Wild | 6 | 6 | 6 |
| Starfinder Player Core | 16 | 16 | 16 |
| Starfinder Galaxy Guide | 6 | 6 | 5 |
| Pathfinder Lost Omens Tian Xia Character Guide | 6 | 6 | 6 |
| Pathfinder Lost Omens Impossible Lands | 5 | 5 | 5 |
| Pathfinder Lost Omens The Mwangi Expanse | 4 | 4 | 4 |
| Pathfinder Lost Omens Ancestry Guide | 4 | 4 | 4 |
| Pathfinder Guns & Gears | 3 | 3 | 3 |
| Pathfinder Impossible Magic | 4 | 4 | 4 |
| Pathfinder War of Immortals | 2 | 2 | 2 |
| Pathfinder Dark Archive (Remastered) | 2 | 2 | 2 |
| Pathfinder Battlecry! | 3 | 3 | 2 |
| Pathfinder Rage of Elements | 1 | 1 | 1 |
| Pathfinder Book of the Dead | 1 | 1 | 1 |
| Pathfinder Lost Omens The Grand Bazaar | 1 | 1 | 1 |
| Pathfinder Lost Omens Absalom, City of Lost Omens | 1 | 1 | 1 |
| Pathfinder Lost Omens Draconic Codex | 1 | 1 | 1 |
| Starfinder Galactic Ancestries | 28 | 28 | 28 |

Vlaka (Galaxy Guide) has a fuller Society section than Foundry's. Battlecry! opens Jotunborn's pages before its
title, so only the introduction after the title is read.

## Known gaps

- **Adventures' own creatures.** Adventure paths, standalone adventures and Society scenarios set their creatures
  differently from the bestiaries; the reader finds few of them (see the adventures above). Those whose lore is a
  bestiary creature's come back through the mapping; the rest need an adventure reader.
- **Families in Howl of the Wild and Rage of Elements**, which set their families' introductions differently.
- **Jotunborn**, whose Details begin on the page before its title.
- Details of ancestries from adventures and player's guides Field Guide hasn't been checked against (Secrets of the
  Swarm, Absalom Station, Invasion's Edge, Beyond the Blood Door, Guilt of the Grave World, Murder in Metal City,
  Cheliax, Life's Long Shadows).
- 13 credited books aren't in Scrollkeeper's catalog under any name (`FieldGuideLoreSurvey lore-books` lists them):
  free player's guides and web supplements not claimed in the library, and books the library doesn't list. The
  app can't offer to download them; it still reads them when the user adds their PDFs, and says so rather than
  claiming the user lacks them. The survey matches Foundry's titles to Scrollkeeper's products by number (scenarios,
  quests, adventure paths) or by their words within the book's game (`ProductMatcher`); a book Foundry credits
  under two titles is one book, and a compilation's volumes (Season of Ghosts' #196–199) supply its lore too.

## Books

Every book Foundry credits with lore the import leaves out.

| System | Book | Creatures | Deities | SKU |
|---|---|---|---|---|
| pf2e | Pathfinder Monster Core | 497 | 0 | PZO12003E |
| pf2e | Pathfinder Monster Core 2 | 440 | 0 | PZO12009E |
| pf2e | Pathfinder Lost Omens Divine Mysteries | 0 | 340 | PZO13003E |
| pf2e | Pathfinder NPC Core | 270 | 0 | PZO12007E |
| pf2e | Pathfinder Lost Omens Draconic Codex | 213 | 9 | PZO13007E |
| pf2e | Pathfinder Bestiary 3 | 165 | 0 | PZO2107E |
| pf2e | Pathfinder Bestiary | 164 | 0 | PZO2102E |
| pf2e | Pathfinder Bestiary 2 | 160 | 0 | PZO2104E |
| pf2e | Pathfinder Kingmaker | 110 | 0 |  |
| pf2e | Pathfinder Book of the Dead | 80 | 1 | PZO2110E |
| pf2e | Pathfinder Rage of Elements | 78 | 0 | PZO2113E |
| pf2e | Pathfinder Lost Omens Divine Mysteries Web Supplement | 0 | 75 | PZO13003WS |
| pf2e | Pathfinder Howl of the Wild | 71 | 0 | PZO12005E |
| pf2e | Pathfinder Season of Ghosts Hardcover Compilation | 58 | 0 |  |
| pf2e | Pathfinder Battlecry! | 50 | 0 | PZO12008E |
| pf2e | Pathfinder Beginner Box: Secrets of the Unlit Star | 49 | 0 |  |
| pf2e | Pathfinder Adventure Path: Gatewalkers | 42 | 0 | PZO14005E |
| pf2e | Pathfinder Adventure Path: Hell's Destiny | 39 | 0 |  |
| pf2e | Pathfinder #192: Worst of All Possible Worlds | 33 | 0 | PZO90192E |
| pf2e | Pathfinder #200: Seven Dooms for Sandpoint | 32 | 0 | PZO90200E |
| pf2e | Pathfinder #164: Hands of the Devil | 31 | 0 | PZO90164E |
| pf2e | Pathfinder Adventure Path: Hellbreakers | 31 | 0 |  |
| pf2e | Pathfinder Lost Omens Monsters of Myth | 30 | 0 | PZO9311E |
| pf2e | Pathfinder #218: Titanbane | 19 | 10 | PZO15218E |
| pf2e | Pathfinder #193: Mantle of Gold | 28 | 0 | PZO90193E |
| pf2e | Pathfinder Beginner Box | 26 | 0 |  |
| pf2e | Pathfinder #191: The Destiny War | 25 | 0 | PZO90191E |
| pf2e | Pathfinder #220: Crypt of Runes | 25 | 0 | PZO15220E |
| pf2e | Pathfinder Lost Omens Tian Xia World Guide | 25 | 0 | PZO13001E |
| pf2e | Pathfinder Society Scenario #3-13: Guardian's Covenant | 25 | 0 | PZOPFS0313E |
| pf2e | Pathfinder Adventure Path: Bastion of Blasphemies | 23 | 0 |  |
| pf2e | Pathfinder #195: Heavy is the Crown | 22 | 0 | PZO90195E |
| pf2e | Pathfinder #216: The Acropolis Pyre | 14 | 8 | PZO15216E |
| pf2e | Pathfinder Lost Omens The Mwangi Expanse | 22 | 0 | PZO9309E |
| pf2e | Pathfinder #214: The Broken Palace | 21 | 0 | PZO15214E |
| pf2e | Pathfinder Society Scenario #4-99: Blessings of the Forest | 21 | 0 |  |
| pf2e | Pathfinder #201: Pactbreaker | 20 | 0 | PZO15201E |
| pf2e | Pathfinder #211: The Secret of Deathstalk Tower | 20 | 0 | PZO15211E |
| pf2e | Pathfinder #166: Despair on Danger Island | 19 | 0 | PZO90166E |
| pf2e | Pathfinder #173: Doorway to the Red Star | 19 | 0 | PZO90173E |
| pf2e | Pathfinder Adventure: Prey for Death | 19 | 0 | PZO14002E |
| pf2e | Pathfinder #180: The Smoking Gun | 18 | 0 | PZO90180E |
| pf2e | Pathfinder #215: To Blot Out the Sun | 18 | 0 | PZO15215E |
| pf2e | Pathfinder Society Scenario #6-00: Salt of the Ocean | 18 | 0 |  |
| pf2e | Pathfinder #165: Eyes of Empty Death | 17 | 0 | PZO90165E |
| pf2e | Pathfinder #169: Kindled Magic | 17 | 0 | PZO90169E |
| pf2e | Pathfinder #182: Graveclaw | 17 | 0 | PZO90182E |
| pf2e | Pathfinder #205: Singer, Stalker, Skinsaw Man | 17 | 0 | PZO15205E |
| pf2e | Pathfinder #206: Bring the House Down | 17 | 0 | PZO15206E |
| pf2e | Pathfinder Lost Omens Cheliax, Infernal Inheritance | 13 | 4 |  |
| pf2e | Pathfinder Society Scenario #4-15: In Glorious Battle | 17 | 0 | PZOPFS0415E |
| pf2e | Pathfinder #179: Cradle of Quartz | 16 | 0 | PZO90179E |
| pf2e | Pathfinder #194: Cult of the Cave Worm | 16 | 0 | PZO90194E |
| pf2e | Pathfinder #219: Lord of the Trinity Star | 16 | 0 | PZO15219E |
| pf2e | Pathfinder #202: Severed at the Root | 15 | 0 | PZO15202E |
| pf2e | Pathfinder #208: Hoof, Cinder, and Storm | 15 | 0 | PZO15208E |
| pf2e | Pathfinder #221: Into the Apocalypse Archive | 15 | 0 | PZO15221E |
| pf2e | Pathfinder Lost Omens Impossible Lands | 15 | 0 | PZO9314E |
| pf2e | Pathfinder #190: The Choosing | 14 | 0 | PZO90190E |
| pf2e | Pathfinder #203: Shepherd of Decay | 13 | 1 | PZO15203E |
| pf2e | Pathfinder #212: A Voice in the Blight | 14 | 0 | PZO15212E |
| pf2e | The Dead God's Hand | 14 | 0 |  |
| pf2e | Pathfinder #155: Lord of the Black Sands | 13 | 0 | PZO90155E |
| pf2e | Pathfinder #185: A Taste of Ashes | 13 | 0 | PZO90185E |
| pf2e | Pathfinder #217: Death Sails a Wine-Dark Sea | 13 | 0 | PZO15217E |
| pf2e | Pathfinder Lost Omens Hellfire Dispatches | 13 | 0 | PZO13008E |
| pf2e | Pathfinder Lost Omens High Seas | 12 | 1 | PZO13009E |
| pf2e | Pathfinder #152: Legacy of the Lost God | 12 | 0 | PZO90152E |
| pf2e | Pathfinder #153: Life's Long Shadows | 12 | 0 | PZO90153E |
| pf2e | Pathfinder #178: Punks in a Powder Keg | 12 | 0 | PZO90178E |
| pf2e | Pathfinder #181: Zombie Feast | 12 | 0 | PZO90181E |
| pf2e | Pathfinder Lost Omens Travel Guide | 5 | 7 | PZO9313E |
| pf2e | Pathfinder Society Scenario #6-09: The Power of Legends | 12 | 0 | PZO160609E |
| pf2e | Pathfinder #174: Shadows of the Ancients | 11 | 0 | PZO90174E |
| pf2e | Pathfinder #176: Lost Mammoth Valley | 11 | 0 | PZO90176E |
| pf2e | Pathfinder #183: Field of Maidens | 11 | 0 | PZO90183E |
| pf2e | Pathfinder #207: The Resurrection Flood | 11 | 0 | PZO15207E |
| pf2e | Pathfinder #209: Destroyer's Doom | 11 | 0 | PZO15209E |
| pf2e | Pathfinder #210: Whispers in the Dirt | 11 | 0 | PZO15210E |
| pf2e | Pathfinder Adventure: Rusthenge | 11 | 0 | PZO9564E |
| pf2e | Pathfinder Adventures: Troubles in Grayce | 11 | 0 |  |
| pf2e | Pathfinder Claws of the Tyrant | 11 | 0 | PZO14003E |
| pf2e | Pathfinder Society Scenario #4-11: Prisoners of the Electric Castle | 11 | 0 | PZOPFS0411E |
| pf2e | Pathfinder War of Immortals | 11 | 0 | PZO12006E |
| pf2e | Pathfinder #154: Siege of the Dinosaurs | 10 | 0 | PZO90154E |
| pf2e | Pathfinder #167: Ready? Fight! | 10 | 0 | PZO90167E |
| pf2e | Pathfinder #168: King of the Mountain | 10 | 0 | PZO90168E |
| pf2e | Pathfinder #175: Broken Tusk Moon | 10 | 0 | PZO90175E |
| pf2e | Pathfinder #184: The Ghouls Hunger | 10 | 0 | PZO90184E |
| pf2e | Pathfinder #186: Ghost King's Rage | 10 | 0 | PZO90186E |
| pf2e | Pathfinder #204: Stage Fright | 10 | 0 | PZO15204E |
| pf2e | Pathfinder Adventure: Crown of the Kobold King | 10 | 0 | PZO9562E |
| pf2e | Pathfinder Lost Omens Character Guide | 10 | 0 | PZO9302E |
| pf2e | Pathfinder Lost Omens Shining Kingdoms | 9 | 1 | PZO13005E |
| pf2e | Pathfinder #170: Spoken on the Song Wind | 9 | 0 | PZO90170E |
| pf2e | Pathfinder #213: Thirst for Blood | 9 | 0 | PZO15213E |
| pf2e | Pathfinder Society Quest #18: Student Exchange | 9 | 0 |  |
| pf2e | Pathfinder Society Scenario #2-00: The King in Thorns | 9 | 0 | PZOPFS0200E |
| pf2e | Pathfinder #148: Fires of the Haunted City | 8 | 0 | PZO90148E |
| pf2e | Pathfinder #151: The Show Must Go On | 8 | 0 | PZO90151E |
| pf2e | Pathfinder #156: The Apocalypse Prophet | 8 | 0 | PZO90156E |
| pf2e | Pathfinder #163: Ruins of Gauntlight | 8 | 0 | PZO90163E |
| pf2e | Pathfinder Lost Omens Gods & Magic | 0 | 8 | PZO9303E |
| pf2e | Pathfinder Society Quest #20: The Dacilane Academy's Show Must Go On | 8 | 0 |  |
| pf2e | Pathfinder Society Scenario #3-15: Cavern of Sundered Songs | 8 | 0 |  |
| pf2e | Pathfinder Society Scenario #3-16: Escape from Oppara | 8 | 0 | PZOPFS0316E |
| pf2e | Pathfinder Society Scenario #5-05: The Island of the Vibrant Dead | 8 | 0 | PZOPFS0505E |
| pf2e | Pathfinder Society Scenario #6-06: Rotten Apples | 8 | 0 | PZO160606E |
| pf2e | Pathfinder Society Scenario #6-15: Lost and Forgotten | 8 | 0 | PZO160615E |
| pf2e | Pathfinder #161: Belly of the Black Whale | 7 | 0 | PZO90161E |
| pf2e | Pathfinder Abomination Vaults Hardcover Compilation | 7 | 0 |  |
| pf2e | Pathfinder Society Quest #22: Friends in Need | 7 | 0 |  |
| pf2e | Pathfinder Society Scenario #3-11: No Time for Treason | 7 | 0 | PZOPFS0311E |
| pf2e | Pathfinder Society Scenario #4-06: Signal from the Electric Laboratory | 7 | 0 | PZOPFS0406E |
| pf2e | Pathfinder Society Scenario #4-07: A Most Wondrous Exchange! | 7 | 0 | PZOPFS0407E |
| pf2e | Pathfinder Society Scenario #4-13: Within the Prairies | 7 | 0 | PZOPFS0413E |
| pf2e | Pathfinder Society Scenario #6-04: An Enkindled Carnival | 7 | 0 | PZO160604E |
| pf2e | Pathfinder Society Scenario #6-10: Once in Whispers | 7 | 0 | PZO160610E |
| pf2e | Pathfinder Society Scenario #7-02: Shipyard Sabotage | 7 | 0 | PZO160702E |
| pf2e | Pathfinder Society Scenario #7-03: A Foot in the Door | 7 | 0 | PZO160703E |
| pf2e | Pathfinder #145: Hellknight Hill | 6 | 0 | PZO90145E |
| pf2e | Pathfinder #149: Against the Scarlet Triad | 6 | 0 | PZO90149E |
| pf2e | Pathfinder Lost Omens Highhelm | 6 | 0 | PZO9316E |
| pf2e | Pathfinder Society Intro: Year of Shattered Sanctuaries | 6 | 0 | PZOPFS0301E |
| pf2e | Pathfinder Society Quest #15: In the Footsteps of Horror | 6 | 0 |  |
| pf2e | Pathfinder Society Scenario #3-14: The Tomb Between Worlds | 6 | 0 | PZOPFS0314E |
| pf2e | Pathfinder Society Scenario #4-02: Return to the Grave | 6 | 0 | PZOPFS0402E |
| pf2e | Pathfinder Society Scenario #4-09: Killer in the Golden Mask | 6 | 0 | PZOPFS0409E |
| pf2e | Pathfinder Society Scenario #5-06: Ukuja, the First Wall | 6 | 0 | PZOPFS0506E |
| pf2e | Pathfinder Society Scenario #5-17: Stranded on Yesterday's Tide | 6 | 0 | PZOPFS0517E |
| pf2e | Pathfinder Society Scenario #6-11: The Godsrain and the Dragon | 6 | 0 | PZO160611E |
| pf2e | Pathfinder #146: Cult of Cinders | 5 | 0 | PZO90146E |
| pf2e | Pathfinder #150: Broken Promises | 5 | 0 | PZO90150E |
| pf2e | Pathfinder Gamemastery Guide | 5 | 0 |  |
| pf2e | Pathfinder Society Intro: Year of Boundless Wonder | 5 | 0 | PZOPFS0401E |
| pf2e | Pathfinder Society Scenario #1-14: Lions of Katapesh | 5 | 0 | PZOPFS0114E |
| pf2e | Pathfinder Society Scenario #3-09: The Secluded Siege | 5 | 0 | PZOPFS0309E |
| pf2e | Pathfinder Society Scenario #3-10: Delve the Pallid Depths | 5 | 0 | PZOPFS0310E |
| pf2e | Pathfinder Society Scenario #4-08: Battle for Star's Fate | 5 | 0 | PZOPFS0408E |
| pf2e | Pathfinder Society Scenario #5-09: Equal Exchange - Skymetal Hoard | 5 | 0 |  |
| pf2e | Pathfinder Society Scenario #5-11: The Hidden Current | 5 | 0 |  |
| pf2e | Pathfinder Society Scenario #7-07: Draconic Folly | 5 | 0 | PZO160707E |
| pf2e | Pathfinder Society Special #3-98: Expedition Into Pallid Peril | 5 | 0 | PZOPFS0398E |
| pf2e | Pathfinder Society Special #3-99: Fate in the Future | 5 | 0 | PZOPFS0399E |
| pf2e | Pathfinder #147: Tomorrow Must Burn | 4 | 0 | PZO90147E |
| pf2e | Pathfinder Adventure: Troubles in Otari | 4 | 0 | PZO9558E |
| pf2e | Pathfinder Lost Omens Firebrands | 0 | 4 | PZO9315E |
| pf2e | Pathfinder Lost Omens Knights of Lastwall | 0 | 4 | PZO9312E |
| pf2e | Pathfinder Society Quest #27: Within the Glacier | 4 | 0 |  |
| pf2e | Pathfinder Society Scenario #2-06: The Crashing Wave | 4 | 0 | PZOPFS0206E |
| pf2e | Pathfinder Society Scenario #2-11: The Pathfinder Trials | 4 | 0 | PZOPFS0211E |
| pf2e | Pathfinder Society Scenario #2-20: Breaking the Storm: Bastion in Embers | 4 | 0 | PZOPFS0220E |
| pf2e | Pathfinder Society Scenario #3-12: Fury's Toll | 4 | 0 | PZOPFS0312E |
| pf2e | Pathfinder Society Scenario #4-05: The Arclord who Never Was | 4 | 0 | PZOPFS0405E |
| pf2e | Pathfinder Society Scenario #5-08: Protecting the Firelight | 4 | 0 | PZOPFS0508E |
| pf2e | Pathfinder Society Scenario #5-20: The Rakshasa's Court | 4 | 0 | PZOPFS0520E |
| pf2e | Pathfinder Society Scenario #6-05: Silver Bark, Golden Blades | 4 | 0 | PZO160605E |
| pf2e | Pathfinder Society Scenario #6-19: What Walks Again | 4 | 0 | PZO160619E |
| pf2e | Pathfinder #171: Hurricane's Howl | 3 | 0 | PZO90171E |
| pf2e | Pathfinder Adventure: Night of the Gray Death | 2 | 1 | PZO9560E |
| pf2e | Pathfinder Adventure: Shadows at Sundown | 3 | 0 | PZO9561E |
| pf2e | Pathfinder Adventure: The Fall of Plaguestone | 3 | 0 | PZO9555E |
| pf2e | Pathfinder Adventure: Things Go to Hell | 3 | 0 |  |
| pf2e | Pathfinder Bounty #21: Against the Unliving | 3 | 0 | PZOPFB0021E |
| pf2e | Pathfinder Dark Archive (Remastered) | 3 | 0 |  |
| pf2e | Pathfinder Game Night: Dawn of the Frogs | 3 | 0 | PZO14006E |
| pf2e | Pathfinder Society Quest #10: The Broken Scales | 3 | 0 | PZOPFQ0010E |
| pf2e | Pathfinder Society Quest #23: Lacking Respect | 3 | 0 |  |
| pf2e | Pathfinder Society Quest #24: Tanuki Trouble | 3 | 0 |  |
| pf2e | Pathfinder Society Scenario #1-01: The Absalom Initiation | 3 | 0 | PZOPFS0101E |
| pf2e | Pathfinder Society Scenario #1-04: Bandits of Immenwood | 3 | 0 | PZOPFS0104E |
| pf2e | Pathfinder Society Scenario #1-05: Trailblazers' Bounty | 3 | 0 | PZOPFS0105E |
| pf2e | Pathfinder Society Scenario #1-11: Flames of Rebellion | 3 | 0 | PZOPFS0111E |
| pf2e | Pathfinder Society Scenario #1-16: The Perennial Crown Part 1, Opal of Bhopan | 3 | 0 | PZOPFS0116E |
| pf2e | Pathfinder Society Scenario #1-17: The Perennial Crown Part 2, The Thorned Monarch | 3 | 0 |  |
| pf2e | Pathfinder Society Scenario #1-20: The Lost Legend | 3 | 0 | PZOPFS0120E |
| pf2e | Pathfinder Society Scenario #2-13: A Gilded Test | 3 | 0 | PZOPFS0213E |
| pf2e | Pathfinder Society Scenario #3-17: Dreams of a Dustbound Isle | 3 | 0 | PZOPFS0317E |
| pf2e | Pathfinder Society Scenario #4-04: To Seek the Heart of Calamity | 3 | 0 | PZOPFS0404E |
| pf2e | Pathfinder Society Scenario #4-14: Shattering Golden Chains | 3 | 0 | PZOPFS0414E |
| pf2e | Pathfinder Society Scenario #4-16: Dacilane Academy's First Great Prank War | 3 | 0 | PZOPFS0416E |
| pf2e | Pathfinder Society Scenario #5-10: The Crocodile's Smile | 3 | 0 | PZOPFS0510E |
| pf2e | Pathfinder Society Scenario #5-18: Equal Exchanges-Tapestry of the Mind | 3 | 0 |  |
| pf2e | Pathfinder Society Scenario #6-17: The Devil in the Details | 3 | 0 | PZO160617E |
| pf2e | Pathfinder #157: Devil at the Dreaming Palace | 2 | 0 | PZO90157E |
| pf2e | Pathfinder #158: Sixty Feet Under | 2 | 0 | PZO90158E |
| pf2e | Pathfinder Adventure: Malevolence | 2 | 0 | PZO9559E |
| pf2e | Pathfinder Adventure: The Enmity Cycle | 2 | 0 | PZO9563E |
| pf2e | Pathfinder Adventure: The Scourge of Sheerleaf | 2 | 0 |  |
| pf2e | Pathfinder Adventure: The Slithering | 2 | 0 | PZO9557E |
| pf2e | Pathfinder Adventures: Dark Archive Web Supplement: In Darkness (Remastered) | 2 | 0 |  |
| pf2e | Pathfinder Game Night: The Dragon's Crown | 2 | 0 |  |
| pf2e | Pathfinder Society Intro #1: The Second Confirmation | 2 | 0 | PZOPFS9901E |
| pf2e | Pathfinder Society Quest #6: Archaeology In Aspenthar | 2 | 0 | PZOPFQ0006E |
| pf2e | Pathfinder Society Scenario #1-02: The Mosquito Witch | 2 | 0 | PZOPFS0102E |
| pf2e | Pathfinder Society Scenario #1-03: Escaping the Grave | 2 | 0 | PZOPFS0103E |
| pf2e | Pathfinder Society Scenario #1-06: Lost on the Spirit Road | 2 | 0 | PZOPFS0106E |
| pf2e | Pathfinder Society Scenario #1-12: The Burden of Envy | 2 | 0 | PZOPFS0112E |
| pf2e | Pathfinder Society Scenario #1-18: Lodge of the Living God | 2 | 0 | PZOPFS0118E |
| pf2e | Pathfinder Society Scenario #2-09: The Seven Secrets of Dacilane Academy | 2 | 0 | PZOPFS0209E |
| pf2e | Pathfinder Society Scenario #2-14: Lost in Flames | 2 | 0 | PZOPFS0214E |
| pf2e | Pathfinder Society Scenario #2-18: The Fanciful March of Urwal | 2 | 0 | PZOPFS0218E |
| pf2e | Pathfinder Society Scenario #3-07: The Locked Lodge | 2 | 0 | PZOPFS0307E |
| pf2e | Pathfinder Society Scenario #3-18: Dacilane Academy's Delightful Disaster | 2 | 0 | PZOPFS0318E |
| pf2e | Pathfinder Society Scenario #4-17: Trapping the Hag's Claw | 2 | 0 | PZOPFS0417E |
| pf2e | Pathfinder Society Scenario #5-13: Thick as Thieves | 2 | 0 | PZOPFS0513E |
| pf2e | Pathfinder Society Scenario #5-15: Cleansing the Flame | 2 | 0 | PZOPFS0515E |
| pf2e | Pathfinder Society Scenario #5-19: Demonic Afterparty | 2 | 0 |  |
| pf2e | Pathfinder Society Scenario #6-01: Intro to the Year of Immortal Influence | 2 | 0 |  |
| pf2e | Pathfinder Society Scenario #6-02: Rain Falls on the Mountain of Sea and Sky | 2 | 0 | PZO160602E |
| pf2e | Pathfinder Society Scenario #6-03: Godsrain in a Godless Land | 2 | 0 | PZO160603E |
| pf2e | Pathfinder Society Scenario #6-08: Upon Wheels and Rime | 2 | 0 | PZO160608E |
| pf2e | Pathfinder Society Scenario #6-18: Symposium on a Fallen God | 2 | 0 | PZO160618E |
| pf2e | Pathfinder Society Scenario #6-99: Under the Eye of the Mantis | 2 | 0 |  |
| pf2e | Pathfinder Society Scenario #7-01: Intro to the Year of Battle's Spark: Enough is Enough | 2 | 0 |  |
| pf2e | Pathfinder #159: All or Nothing | 1 | 0 | PZO90159E |
| pf2e | Pathfinder #162: Ruins of the Radiant Siege | 1 | 0 | PZO90162E |
| pf2e | Pathfinder #172: Secrets of the Temple-City | 1 | 0 | PZO90172E |
| pf2e | Pathfinder #199: To Bloom Below the Web | 1 | 0 | PZO90199E |
| pf2e | Pathfinder Adventure: A Few Flowers More | 1 | 0 | PZO9500-24E |
| pf2e | Pathfinder Adventure: Little Trouble in Big Absalom | 1 | 0 | PZO9500-18E |
| pf2e | Pathfinder Bounty #15: Treasure off the Coast | 1 | 0 | PZOPFB0015E |
| pf2e | Pathfinder Bounty #18: From Family Lost | 1 | 0 | PZOPFB0018E |
| pf2e | Pathfinder Bounty #5: Witch's Winter Holiday | 1 | 0 | PZOPFB0005E |
| pf2e | Pathfinder Curtain Call Player's Guide | 0 | 1 |  |
| pf2e | Pathfinder Lost Omens Absalom, City of Lost Omens | 1 | 0 | PZO9304E |
| pf2e | Pathfinder One-Shot #2: Dinner at Lionlodge | 0 | 1 |  |
| pf2e | Pathfinder One-Shot #4: Mark of the Mantis | 1 | 0 | PZOPF1004E |
| pf2e | Pathfinder Player Core | 1 | 0 |  |
| pf2e | Pathfinder Society Intro #2: United in Purpose | 1 | 0 | PZOPFS9902E |
| pf2e | Pathfinder Society Quest #11: A Parchment Tree | 1 | 0 | PZOPFQ0011E |
| pf2e | Pathfinder Society Quest #19: The Elsewhere Feast | 1 | 0 |  |
| pf2e | Pathfinder Society Quest #9: Wayfinder Origins | 1 | 0 | PZOPFQ0009E |
| pf2e | Pathfinder Society Scenario #1-07: Flooded King's Court | 1 | 0 | PZOPFS0107E |
| pf2e | Pathfinder Society Scenario #1-08: Revolution on the Riverside | 1 | 0 | PZOPFS0108E |
| pf2e | Pathfinder Society Scenario #1-09: Star-Crossed Voyages | 1 | 0 | PZOPFS0109E |
| pf2e | Pathfinder Society Scenario #1-13: Devil at the Crossroads | 1 | 0 | PZOPFS0113E |
| pf2e | Pathfinder Society Scenario #1-21: Mistress of the Maze | 1 | 0 | PZOPFS0121E |
| pf2e | Pathfinder Society Scenario #2-03: Catastrophe's Spark | 1 | 0 | PZOPFS0203E |
| pf2e | Pathfinder Society Scenario #2-08: A Frosty Mug | 1 | 0 | PZOPFS0208E |
| pf2e | Pathfinder Society Scenario #2-15: A Dirge for Sarkoris | 1 | 0 | PZOPFS0215E |
| pf2e | Pathfinder Society Scenario #2-21: In Pursuit of Water | 1 | 0 | PZOPFS0221E |
| pf2e | Pathfinder Society Scenario #3-02: The East Hill Haunting | 1 | 0 | PZOPFS0302E |
| pf2e | Pathfinder Society Scenario #3-03: Echoes of Desperation | 1 | 0 | PZOPFS0303E |
| pf2e | Pathfinder Society Scenario #3-04: The Devil-Wrought Disappearance | 1 | 0 | PZOPFS0304E |
| pf2e | Pathfinder Society Scenario #3-19: Mean Streets of Shadow Absalom | 1 | 0 | PZOPFS0319E |
| pf2e | Pathfinder Society Scenario #6-12: The Burning of Greensteeples | 1 | 0 | PZO160612E |
| pf2e | Pathfinder Society Scenario #6-13: All That Glitters | 1 | 0 | PZO160613E |
| pf2e | Pathfinder Society Scenario #6-14: Twice in Steel | 1 | 0 | PZO160614E |
| pf2e | Pathfinder Society Scenario #7-05: Battle of the Thorns | 1 | 0 | PZO160705E |
| pf2e | Pathfinder Society Scenario #7-19: The Lost Legacy | 1 | 0 | PZO160719E |
| pf2e | Pathfinder Society Scenario #7-22: The Handmaiden's Gaze | 1 | 0 |  |
| pf2e | Pathfnder Society Scenario #7-21: The Home of Empty Breath | 1 | 0 |  |
| sf2e | Starfinder Alien Core | 234 | 0 | PZO22003E |
| sf2e | Starfinder Player Core | 0 | 25 | PZO12001E |
| sf2e | Starfinder Absalom Station | 22 | 0 |  |
| sf2e | Starfinder Secrets of the Swarm Adventure Path | 16 | 0 |  |
| sf2e | Starfinder Murder in Metal City Deluxe Adventure | 11 | 0 |  |
| sf2e | Beyond the Blood Door Player's Guide | 0 | 8 |  |
| sf2e | Starfinder Guilt of the Grave World | 6 | 0 | PZO24006E |
| sf2e | Starfinder GM Core | 0 | 2 | PZO12002E |
| sf2e | Starfinder Society Scenario #1-07: Seize and Destroy | 1 | 0 | PZO260107E |
| sf2e | Starfinder Society Scenario #1-09: Abduction | 1 | 0 | PZO260109E |
| sf2e | Starfinder Society Scenario #1-17: Corpse Fleet Conflict | 1 | 0 | PZO260117E |
