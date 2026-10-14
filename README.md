# Field Guide

Looking up a rule, a spell or a monster at the table usually means a laptop, a website that needs a signal,
or a stack of books.

Field Guide is an iPad app that carries the Pathfinder and Starfinder compendium, offline: actions, creatures,
equipment, feats, hazards, spells, conditions, ancestries, classes, deities and more. Search as you type,
filter by level, rarity, traits and source, and follow the links from one entry to the next. Creatures can be
shown as battle cards with art from your own pawn and Battle Cards PDFs, and equipment with art from your item
decks.

The content comes from the Foundry VTT pf2e system repository, under the ORC License and the Open Game License.
See `docs/specs/field-guide/` for the requirements and design.

## Use
- Pick Pathfinder or Starfinder at the top of the sidebar, then a category: Actions, Bestiary, Campaign
  Features, Equipment, Feats, Hazards, Spells, Conditions, Ancestries, Heritages, Backgrounds, Classes or
  Deities.
- Search names as you type; the sort menu also searches the entries' text, and sorts by level.
- Filters narrow by level, rarity, traits, source and each category's own (spell rank, tradition and
  casting time, item type, feat category, creature size and more).
- Links in an entry open the linked entry, and traits open their description; Back returns.
- A creature's page switches between its stat block and its battle card (Card at the top); Turn Over shows
  the card's back with the creature's art.
- **Art from PDFs** (sidebar toolbar) reads creature art from your own Paizo pawn, token and Battle Cards PDFs,
  and item art from your item decks (Potions & Talismans, Magic Armaments, Alchemy, Guns, Gears, Relics, Deck
  of Endless Treasure, and Weapons & Armor, sold as pictures), shown on equipment in place of the Rexard icon:
  Import from Scrollkeeper uses the PDFs Scrollkeeper downloaded where they are (on the iPad, pick On My iPad ▸
  Scrollkeeper), and new downloads there are picked up at launch; Add PDFs copies other files in. PDFs that
  were deleted from Scrollkeeper are listed as missing, and creatures that lose their art say which PDF it
  needs.

## Updating
`make update` switches `pf2e.release` to pf2e's newest release, imports again and installs on the iPad. GitHub
makes the same switch every Monday, and when the new release changes the compendium and Field Guide has a
release, it builds the next patch version into a draft release. Commit `pf2e.release`, `import.sha256` and
`icon-matches.tsv` after a local import. The steps on their own:

- `make import` reads the pf2e release named in `pf2e.release`, which it downloads into `build/pf2e` (set
  `PF2E_REPO` to read your own checkout), and writes `Generated/`: `catalog.sqlite`, the icons, the fonts,
  `import-report.md` (what could not be converted), `Creatures/` (the battle cards' creatures, by Tabletop
  Kit's `CreatureImport`) and `CardArt/` (the cards' UI art, copied from your Rexard packs in
  `REXARD_PACKS`, default `~/git/rexard-packs`). Deities show their religious symbols from Paizo's Community Use
  Package in `COMMUNITY_USE` (default `~/git/community-use-artwork`). Action icons use Paizo's Pathfinder-Icons
  font from the `Artwork` submodule (`ARTWORK`). No creature art is imported; the app reads it from your PDFs.
  Icons are your own Rexard pictures standing in for Foundry's (`.build/field-guide-import/icon-map.tsv` lists
  each pick and why); to correct one, add `"<Foundry path or entry id>": "<file in the packs>"` to
  `icon-overrides.json`. `icon-matches.tsv` keeps each Foundry icon's match for imports without the Foundry
  app, such as GitHub's.
  `cwebp` (`brew install webp`) shrinks the icons.
- `make ipad-install` builds the iPad app with `Generated/` inside and installs it on a connected iPad. Put
  your team in `ios/Local.xcconfig` (`DEVELOPMENT_TEAM = …`); a free team's signature lasts 7 days, so
  reinstall weekly.
- `make run` opens the Mac build on `Generated/`, for trying things out. `FIELD_GUIDE_SELECT=<entry id>`
  opens an entry at launch. `make dmg` builds `build/Field Guide.app` and `build/Field-Guide-<version>.dmg`.
  Pushing a `v*` tag builds the universal app on GitHub from the same pf2e release and the `Artwork`
  submodule, and attaches its disk image to the release.

## Artwork

The `Artwork/` folder is a private Git submodule ([toolkit-artwork](https://github.com/scooper4711/toolkit-artwork)).
Clone with `git clone --recursive`, or run `git submodule update --init` after cloning. Its contents are
licensed and not redistributable. Without access to it, the build still works and falls back to built-in
artwork. The action icons are Paizo's Pathfinder-Icons font, used unaltered under the
[Paizo Compatibility License](https://paizo.com/licenses/compatibility).

## Paizo notices

Field Guide uses trademarks and/or copyrights owned by Paizo Inc., used under Paizo's Community Use Policy
([paizo.com/licenses/communityuse](https://paizo.com/licenses/communityuse)). We are expressly prohibited from
charging you to use or access this content. Field Guide is not published, endorsed, or specifically approved by
Paizo. For more information about Paizo Inc. and Paizo products, visit [paizo.com](https://paizo.com).

Pathfinder and Starfinder are registered trademarks and copyrights of Paizo Inc.

The compendium text comes from the [pf2e system for Foundry VTT](https://github.com/foundryvtt/pf2e) and is used
under the ORC License and the Open Game License 1.0a. The deities' religious symbols are from Paizo's Community
Use Package. The same notices and credits are in the app's About screen (the app menu on the Mac, the sidebar's
About button on the iPad). Contact: [scooper4711 on GitHub](https://github.com/scooper4711).

## Test
`make test`, `make lint` and `make coverage` (80% of lines and regions in `FieldGuideKit` and
`CompendiumImport`). The importer's tests run against a small fake repository, so they need no Paizo data.

## Layout
- `Sources/FieldGuideKit`: the catalog model, its SQLite store and list filtering
- `Sources/CompendiumImport`, `Sources/FieldGuideImport`: the importer
- `Sources/FieldGuideUI`: SwiftUI shared by the iPad and the Mac; the battle cards, bestiary and creature art
  store come from [Tabletop Kit](https://github.com/scooper4711/tabletop-kit); `Sources/FieldGuide`: the Mac app;
  `ios/`: the iPad project
