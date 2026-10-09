# Field Guide

A private iPad app for looking things up at the table: Foundry VTT's compendium browser for Pathfinder 2e and
Starfinder 2e, offline, with art. It is built from the Foundry pf2e system repository and is not distributed,
since the content and art are Paizo's. See `docs/specs/field-guide/` for the requirements and design.

## Use
- Pick Pathfinder or Starfinder at the top of the sidebar, then a category: Actions, Bestiary, Campaign
  Features, Equipment, Feats, Hazards, Spells, Conditions, Ancestries, Heritages, Backgrounds, Classes or
  Deities.
- Search names as you type; the sort menu also searches the entries' text, and sorts by level.
- Filters narrow by level, rarity, traits, source and each category's own (spell rank, tradition and
  casting time, item type, feat category, creature size and more).
- Links in an entry open the linked entry, and traits open their description; Back returns.

## Updating
`make update` brings `~/git/pf2e` up to date with the official repository (fast-forward only), imports again
and installs on the iPad. The steps on their own:

- `make import` reads `~/git/pf2e` and writes `Generated/`: `catalog.sqlite`, the images, the fonts and
  `import-report.md` (what could not be converted). Creature art comes from Combat Pad's
  `~/git/combat-pad/Generated` (Foundry token modules and art from the Paizo PDFs), else from the Foundry
  token modules; `cwebp` (`brew install webp`) scales it down. The first import takes several minutes for
  the art; later ones about a minute and a half.
- `make ipad-install` builds the iPad app with `Generated/` inside and installs it on a connected iPad. Put
  your team in `ios/Local.xcconfig` (`DEVELOPMENT_TEAM = …`); a free team's signature lasts 7 days, so
  reinstall weekly.
- `make run` opens the Mac build on `Generated/`, for trying things out. `FIELD_GUIDE_SELECT=<entry id>`
  opens an entry at launch.

## Test
`make test`, `make lint` and `make coverage` (80% of lines and regions in `FieldGuideKit` and
`CompendiumImport`). The importer's tests run against a small fake repository, so they need no Paizo data.

## Layout
- `Sources/FieldGuideKit`: the catalog model, its SQLite store and list filtering
- `Sources/CompendiumImport`, `Sources/FieldGuideImport`: the importer
- `Sources/FieldGuideUI`: SwiftUI shared by the iPad and the Mac; `Sources/FieldGuide`: the Mac app;
  `ios/`: the iPad project
