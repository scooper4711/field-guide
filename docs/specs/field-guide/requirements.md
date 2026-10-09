# Field Guide: requirements

A private iPad app for looking up Pathfinder 2e and Starfinder 2e rules at the table, in the manner of
Foundry VTT's compendium browser. It is not distributed: the data and art it carries are Paizo's.

## R1 Data
- R1.1 The content comes from the Foundry pf2e system repository at `~/git/pf2e`, whose `packs` folder
  holds both systems.
- R1.2 `make update` brings that repository up to date with the official one (fast-forward only, leaving
  it alone if it has local commits), imports again and installs the app on the iPad, so new and corrected
  content arrives with one command.
- R1.3 The import is repeatable and needs no network: running it twice on the same repository gives the
  same result.
- R1.4 Each import writes a report: entries per system and category, links that lead nowhere, and
  enrichers it could not convert.

## R2 Systems
- R2.1 One app holds both systems. A Pathfinder / Starfinder switch at the top changes everything shown,
  and the app remembers the choice.
- R2.2 Each system shows only its own packs.

## R3 Categories
- R3.1 Foundry's compendium browser tabs: Actions, Bestiary, Campaign Features, Equipment, Feats, Hazards
  and Spells.
- R3.2 Also: Conditions, Ancestries, Heritages, Backgrounds, Classes and Deities.
- R3.3 A category with no entries in a system, such as Campaign Features in Starfinder, is not shown.

## R4 Browsing
- R4.1 Each category lists its entries with a small image, name, level (where it has one) and type.
- R4.2 Search matches names as you type, ignoring case and accents. A switch extends the search to the
  entries' text.
- R4.3 Filters: level range, rarity, traits and source in every category that has them, plus each
  category's own: action type; creature size; equipment type; feat category; hazard complexity; spell
  rank, kind (cantrip, focus, ritual), tradition and casting time.
- R4.4 Sort by name or by level.
- R4.5 The number of matching entries is shown.

## R5 Entries
- R5.1 An entry shows its image, name, type and level, traits (rarity colored as in Foundry), the details
  of its kind (such as a spell's range, area, targets, defense and duration, or an item's price and bulk),
  and its description.
- R5.2 Foundry's text enrichers become readable text: checks ("DC 20 basic Reflex save"), damage, areas,
  inline rolls and localized text.
- R5.3 Links to other compendium entries open them in the app; Back returns. Links to entries the app
  doesn't hold read as plain text.
- R5.4 Creatures and hazards show a full stat block: traits, Perception and senses, languages, skills,
  attribute modifiers, items, AC, saves, HP, immunities, resistances and weaknesses, speeds, Strikes,
  actions and reactions in stat-block order, and spellcasting by rank; then the creature's description.
- R5.5 Tapping a trait shows its description.

## R6 Images
- R6.1 Items, spells, feats and actions show their Foundry icons.
- R6.2 Creatures show their art: from the Foundry token-art modules, else the art Combat Pad extracted
  from the Paizo PDFs, else the creature's icon.
- R6.3 Large art is scaled down so the app stays a reasonable size.

## R7 The app
- R7.1 iPadOS 18 or later, in every orientation, with a Mac build for development.
- R7.2 Everything works offline.
