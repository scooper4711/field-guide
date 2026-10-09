# Field Guide: design

A SwiftPM package with an Xcode project for the iPad, in the style of Combat Pad.

## Targets
- `FieldGuideKit` (iOS, macOS): the catalog model and its SQLite store. `GameSystem` (pf2e, sf2e),
  `Category`, `EntrySummary` (what lists and filters need), `Catalog` (reads the database), `EntryQuery`
  (search text, filters and sort, applied in memory), `FacetValues` (the filter options of a list).
- `CompendiumImport` (macOS): reads the pf2e repository and writes the database and images. Code that
  Combat Pad's `FoundryImport` already proved (JSON access, pack manifests, enricher scanning, the
  Foundry art mapping) is adapted rather than shared, so the two apps change independently.
- `FieldGuideImport`: the command-line importer.
- `FieldGuideUI` (iOS, macOS): the SwiftUI app.
- `FieldGuide`: the Mac app, for trying things out; the iPad app lives in `ios/FieldGuide.xcodeproj`
  (scheme FieldGuide-iPad) and includes `Generated/` as a folder of resources.

## Import
- `PackScanner` reads `system.pf2e.json` and `system.sf2e.json` for each Item and Actor pack's folder and
  link name (`spells` is linked as `spells-srd`). Every document is read once.
- `CategoryMapper` assigns a category by document type: `action`; `npc` (Bestiary); `campaignFeature`;
  the physical item types (Equipment); `feat`; `hazard`; `spell`; `condition` and everything in a
  `conditions` pack; `ancestry`, `heritage`, `background`, `class`, `deity`. Effects, macros, journals,
  tables, vehicles and characters are skipped.
- `LinkIndex` maps every imported document's `Compendium.<system>.<pack>.Item|Actor.<id or name>` to its
  ID, so links can be checked and rewritten.
- `Enricher` replaces `@UUID`, `@Check`, `@Damage`, `@Template`, `@Localize`, `@Embed` and `[[/r …]]` in
  description HTML. A link to an imported entry becomes `<a href="entry:<id>">`; any other becomes its
  label. Checks and damage are wrapped in spans for styling.
- `PageBuilder` writes each entry's HTML body: a header (name, type and level), traits, a details block
  for the entry's kind (`DetailLines`), then the enriched description. Creatures and hazards use
  `StatBlockBuilder`, which follows Combat Pad's parsers for senses, skills, defenses, Strikes and
  spellcasting.
- `FacetExtractor` records each entry's filter values: level, rarity, traits, source title and the
  category's own facets as a JSON object.
- `ImageCollector` resolves Foundry paths (`systems/<system>/…` → the repository's `static/`, `icons/…` →
  the Foundry app's `public/icons`, `modules/…` → the Foundry data folder) and copies each image once into
  `Generated/Images`. Creature art comes from Combat Pad's `Generated/Bestiary/index.json` (portrait, else
  card back) and, where Combat Pad is missing, from the token modules' `compendiumArtMappings`. Art wider
  or taller than 512 px is scaled with `cwebp`.
- `CatalogWriter` writes `Generated/catalog.sqlite`: table `entries` (id, system, category, name, level,
  rarity, traits, source, image, subtitle, facets JSON, html) and an FTS5 table over name and text.
- Trait descriptions come from the language files through `traits.ts`, as in Combat Pad, and are stored
  in table `traits` (system, slug, label, html).

## App
- `NavigationSplitView`: categories in the sidebar under the system switch, the entry list in the middle,
  the entry on the right. The list loads every summary of the category once and filters in memory; text
  search uses the FTS table.
- `EntryView` shows an entry's HTML in a `WKWebView` with the app's stylesheet. A `WKURLSchemeHandler` for
  `fieldguide:` serves images from `Generated/Images`; `entry:` and `trait:` links are intercepted and
  pushed onto the entry's navigation stack.
- The chosen system and the last category are kept in `@AppStorage`.

## Updating
- `scripts/update.sh`: fetches the pf2e repository's `upstream` remote and fast-forwards the checked-out
  branch to `upstream/<branch>`; then `make import` and `make ipad-install`.
- `make import` builds and runs `FieldGuideImport`; `make ipad-install` builds the iPad app and installs it,
  as Combat Pad does.
