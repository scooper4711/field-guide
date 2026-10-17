# Field Guide: requirements

An iPad and Mac app for looking up Pathfinder 2e and Starfinder 2e rules at the table, in the manner of
Foundry VTT's compendium browser.

## R1 Data
- R1.1 The content comes from the Foundry pf2e system repository (whose `packs` folder holds both
  systems), at the release named in `pf2e.release`, which the import downloads from `foundryvtt/pf2e`.
  `PF2E_REPO` reads another checkout instead, for development.
- R1.2 `make update` switches `pf2e.release` to pf2e's newest release, imports again and installs the app on
  the iPad, so new and corrected content arrives with one command. Weekly, GitHub makes the same switch and,
  when the new release changes the imported compendium and the app has a release, tags the next patch version
  and builds it into a draft release to publish; a pf2e release that changes nothing Field Guide shows makes
  no release.
- R1.3 The import is repeatable: running it twice on the same pf2e release gives the same result, on this
  Mac or on GitHub. It needs the network only to download a pf2e release it doesn't have.
- R1.4 Each import writes a report: entries per system and category, links that lead nowhere, and
  enrichers it could not convert.

## R2 Systems
- R2.1 One app holds both systems. A Pathfinder / Starfinder switch at the top changes everything shown,
  and the app remembers the choice.
- R2.2 Each system shows only its own packs.

## R3 Categories
- R3.1 Foundry's compendium browser tabs: Actions, Bestiary, Campaign Features, Equipment, Feats, Hazards
  and Spells.
- R3.2 Also: Conditions, Ancestries, Heritages, Backgrounds, Classes and Deities; and from the rules journals,
  Archetypes, Domains and Remaster Changes, each page an entry.
- R3.3 A category with no entries in a system, such as Campaign Features in Starfinder, is not shown.
- R3.4 GM Screen, first in the list: each page of the system's GM Screen journal (such as DCs by Level,
  Simple DCs and Encounter Budget) is an entry, filterable by its section (Playing the Game, Running the
  Game, Subsystems and Variant Rules). Section headings with no content of their own are left out, and links
  between pages work.
- R3.5 GM Screen also has an Areas entry per system: grid diagrams the import draws from the rules for measuring
  areas (every second diagonal counts as 10 feet, except that 10-foot reach reaches 2 squares diagonally), one each
  for bursts, emanation and reach from a Medium creature, emanation and reach from a Large creature, emanation from
  a Huge creature, orthogonal and diagonal cones, and lines at five slopes (straight; 3 across, 1 down; 2 across, 1
  down; 3 across, 2 down; diagonal), each labeled at its start and starting as soon as it keeps a clear square from
  the lines above. Each diagram nests its common sizes on one grid, each size in its own color from a
  color-blind-safe palette (Okabe-Ito: blue, orange, green, yellow, sky blue, from the smallest outward) and
  outlined in a stronger tone of that color, with a key. The diagrams are inline SVG that follows light and dark
  mode, and use no Paizo art.
- R3.6 Journals: the rest of the rules journals, filterable by journal: the Hero Point Deck, and the pages of
  the Ancestries and Classes journals that no ancestry or class is named for (Index, Versatile Heritages,
  Draconic Sorcerer Bloodlines). Links to skill-action macros open the action they run.

## R4 Browsing
- R4.1 Each category lists its entries with a small image, name, level (where it has one) and type.
- R4.2 Search matches names as you type, ignoring case and accents. A switch extends the search to the
  entries' text.
- R4.3 Filters: level range, rarity, traits and source in every category that has them, plus each
  category's own: action type; creature size; equipment type; feat category; hazard complexity; spell
  rank, kind (cantrip, focus, ritual), tradition and casting time.
- R4.4 Sort by name or by level.
- R4.5 The number of matching entries is shown.
- R4.6 Search Everything, in the sidebar and from a button beside the entry, searches every category of the
  system as you type: names as in R4.2, or with a switch the entries' text, names counting most. Matches are
  grouped by category, the category with the best match first, showing the first ten and how many there are;
  a match opens its entry, and Show All opens the category's list searched the same way.

## R5 Entries
- R5.1 An entry shows its image, name, type and level, traits (rarity colored as in Foundry), the details
  of its kind (such as a spell's range, area, targets, defense and duration, or an item's price and bulk),
  and its description.
- R5.2 Foundry's text enrichers become readable text: checks ("DC 20 basic Reflex save"), damage, areas,
  inline rolls and localized text. Damage formulas are worked out from the entry's rank or level (a rank 2
  spell's `floor(@item.level/2)d6` reads "1d6") and a creature's level; ones that depend on the reader's
  character are described as the books do ("1d6 per level", "1d6, increasing by 1d6 at 3rd level and every 2
  levels after", "your Strength modifier"), counting from the entry's own level (Tabletop Kit's
  `FormulaWording`).
- R5.3 Links to other compendium entries open them in the app; Back returns. Links to entries the app
  doesn't hold read as plain text.
- R5.4 Creatures show their battle card and lore (R8). Hazards, and creatures without a battle card, show a
  full stat block: traits, Perception and senses, languages, skills, attribute modifiers, items, AC, saves, HP,
  immunities, resistances and weaknesses, speeds, Strikes, actions and reactions in stat-block order, and
  spellcasting by rank; then the creature's description.
- R5.5 Tapping a trait shows its description.
- R5.6 An ancestry or class switches between its overview and its Details, its page in the Ancestries or
  Classes journal, when it has one; a link to that journal page opens the entry on its Details.

## R6 Images
- R6.1 Items, spells, feats and actions show icons from the user's own Rexard packs, never Foundry's or
  Paizo's: the Rexard original of the entry's Foundry icon; else its base item's icon (a +1 longsword gets
  the longsword's); else the icon most entries like it clearly share (items: same weapon or armor group,
  consumable category or item type; others: same trait); else none, and the list shows the category's symbol.
  `icon-overrides.json` (Foundry path or entry id → Rexard file) corrects bad picks. `icon-matches.tsv` keeps
  each Foundry icon's match, so an import without the Foundry app (on GitHub) picks the same icons.
- R6.2 Creatures and hazards show their art, read on the device from the user's own Paizo pawn, token and
  Battle Cards PDFs (Tabletop Kit's `CreatureArt`); without art the page shows none and the list shows the
  category's symbol. No Paizo or Foundry module art is imported or bundled.
- R6.2a Equipment shows its art from the user's own item decks (Tabletop Kit's item art) when a card names it,
  in any grade ("Healing Potion (Minor)" shows the Healing Potion card); else its Rexard icon (R6.1).
- R6.2b Deities show their religious symbol from Paizo's Community Use Package (Religious Symbols; for
  Starfinder deities, the Starfinder package first) when it has one by the deity's name, in the list in place
  of the category's symbol and in the top-right corner of the page.
- R6.2c Action icons are Paizo's Pathfinder-Icons font, bundled unaltered under the Paizo Compatibility
  License and kept out of the repository.
- R6.3 Import from Scrollkeeper uses the PDFs Scrollkeeper downloaded where they are, without copying them,
  and picks up new downloads at launch; Add PDFs copies other PDFs into the app.
- R6.4 PDFs deleted or moved since they were read are listed as missing in Art from PDFs, and a creature's
  card says which missing PDF its art needs.

## R8 Battle cards
- R8.1 A creature's page switches between its battle card (Tabletop Kit's interactive card, in the Rexard
  style, as in Turnkeeper) and its lore, the description without the stat block; the choice is remembered. A
  creature without lore shows only its card. The card fills the width of its column, padded, and grows when
  the sidebar is hidden.
- R8.2 Tapping an empty part of the card shows its corner icons and a second tap hides them; with a pointer,
  each icon shows while the pointer is over its corner. The top-right icon turns the card over to its back:
  the creature's art in a backdrop chosen by its traits, with its name. The bottom-right icon, or a pinch
  out, shows the card full screen, where flipping works too; its icon, a pinch in or Escape closes it.
- R8.3 Linked words and trait or condition tags on the card open their glossary entries in popovers, two
  deep, instead of showing the icons. Cards pop up, pages navigate: links in the lore and on other pages
  open their entries (R5.3).

## R7 The app
- R7.1 iPadOS 18 or later, in every orientation, and macOS 15 or later. Pushing a version tag makes GitHub
  build the universal Mac app with the same data as a local build and attach its disk image to the release.
- R7.2 Everything works offline.
- R7.3 An About screen (the app menu's About Field Guide on the Mac, the sidebar's About button on the iPad) shows
  the notice Paizo's Community Use Policy requires, the Paizo Compatibility License's trademark line, credits for
  the compendium text, the religious symbols, the Rexard art and the action icon font, and a link for reaching the
  author. It also lists the full texts of the licenses the bundled content requires: the Open Game License and the
  ORC License (the compendium text), the Apache License for Roboto Condensed and the SIL Open Font License for
  Gelasio. The README carries the same notices.
- R7.4 The Mac app is a full Mac app, not only a developer build. Its window opens at 1280 by 820 points. A Go
  menu has Search Everything (⌘F), Back (⌘[, returning from a followed link) and Pathfinder (⌘1) and
  Starfinder (⌘2); File has Art from PDFs… (⇧⌘A). The README says how to install the disk image from a
  release and get past macOS's warning about an app that isn't notarized.
- R7.5 The Mac app runs in the App Sandbox, without a paid Apple developer account. Its first sandboxed launch
  moves the art library and settings an earlier version kept into the sandbox. PDFs added before show as missing
  until their folder is picked again (Import from Scrollkeeper…), which restores them. It reads only the files and
  folders the user picks, and remembers them across launches and updates.
