# Field Guide: design

A SwiftPM package with an Xcode project for the iPad, in the style of Combat Pad.

## Targets
- `FieldGuideKit` (iOS, macOS): the catalog model and its SQLite store. `GameSystem` (pf2e, sf2e),
  `EntryCategory` (not `Category`, which clashes with an Objective-C type), `EntrySummary` (what lists and filters need), `Catalog` (reads the database), `EntryQuery`
  (search text, filters and sort, applied in memory), `FacetValues` (the filter options of a list).
- `CompendiumImport` (macOS): reads the pf2e repository and writes the database and images. Code that
  Combat Pad's `FoundryImport` already proved (JSON access, pack manifests, enricher scanning, the
  Foundry art mapping) is adapted rather than shared, so the two apps change independently.
- `FieldGuideImport`: the command-line importer.
- `FieldGuideUI` (iOS, macOS): the SwiftUI app. It uses Tabletop Kit's `BattleCards`, `Bestiary` and
  `CreatureArt`; `FieldGuideImport` uses its `CreatureImport`.
- `FieldGuide`: the Mac app, for trying things out; the iPad app lives in `ios/FieldGuide.xcodeproj`
  (scheme FieldGuide-iPad) and includes `Generated/` as a folder of resources.

## Import
- `PackScanner` reads `system.pf2e.json` and `system.sf2e.json` for each Item and Actor pack's folder and
  link name (`spells` is linked as `spells-srd`). Every document is read once.
- `StarfinderDuplicates` adds the Pathfinder documents that `build/duplicates.json` tells the Starfinder build
  to copy into its packs (conditions, basic actions, many spells and feats), with the listed Starfinder
  publication, so Starfinder links to them resolve.
- `CategoryMapper` assigns a category by document type: `action`; `npc` (Bestiary); `campaignFeature`;
  the physical item types (Equipment); `feat`; `hazard`; `spell`; `condition` and everything in a
  `conditions` pack; `ancestry`, `heritage`, `background`, `class`, `deity`. Effects, macros, journals,
  tables, vehicles and characters are skipped.
- `GMScreen` reads `packs/<system>/journals/gm-screen.json`: each page with more than a line of text becomes
  an entry with ID `Compendium.<system>.journals.JournalEntry.<journal>.JournalEntryPage.<page>`, and its
  section is the last level-1 page before it in sort order. Relative links (`@UUID[.<page>]`) are made
  absolute before enriching, and `LinkIndex` resolves page links (ignoring `#anchors`).
- `AreaDiagrams` renders a region of a Player Core page with PDFKit (the PDF is the largest one in
  Scrollkeeper's `Files/<Pathfinder|Starfinder> Player Core` folder; the page is found by its label) at
  three times the page's resolution and stores it as WebP in `Images/gm-screen/`.
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
- `FoundryPaths` resolves Foundry paths (`systems/<system>/…` → the repository's `static/`, `icons/…` →
  the Foundry app's `public/icons`); module paths are not resolved, since module art is Paizo's.
- `RexardIcons` hashes every PNG in the Rexard packs (256-bit difference hash, gray, over black, whole and
  at 12 crops, since Foundry crops some icons), cached by size and date in the import's work folder (`.build/field-guide-import`, since `Generated` goes into
  the app whole).
  `IconMap` picks each entry's icon: overrides, then the nearest Rexard picture to its Foundry icon (hashed
  over black and over white) within 12 bits, then its base item's (`system.baseItem` equal to an item's
  slug), then `LearnedIcons`: the most common icon among matched entries of the category sharing its
  weapon/armor group, consumable category or type for items, a trait (traditions count for spells) for
  the rest, each needing 3 entries of which more than a third show the icon; never the whole category, which would
  give every action or deity one icon, and never an item's traits, which say little about its looks. The import writes `icon-map.tsv` there (entry, Foundry icon, Rexard
  file, rule, distance) and counts per rule in `import-report.md`.
- `ImageCollector` writes each chosen Rexard file once as a WebP of at most 256 pixels to
  `Generated/Images/rexard/<path in the packs>`. No Foundry or pf2e icon file is copied. A creature's or
  hazard's image is `creature/<system>.<pack link name>.<id>`, the bestiary key, drawn by the app; its
  `<img>` removes itself when the app has no art for it. The area diagrams are shrunk with `cwebp`.
- `FieldGuideImport` also runs Tabletop Kit's `BestiaryImporter` into `Generated/Creatures`, and
  `scripts/import.sh` runs `CardArtImport` to copy the Rexard card pieces into `Generated/CardArt`.
- `CatalogWriter` writes `Generated/catalog.sqlite`: table `entries` (id, system, category, name, level,
  rarity, traits, source, image, subtitle, facets JSON, html) and an FTS5 table over name and text.
- Trait descriptions come from the language files through `traits.ts`, as in Combat Pad, and are stored
  in table `traits` (system, slug, label, html).

## App
- `NavigationSplitView`: categories in the sidebar under the system switch, the entry list in the middle,
  the entry on the right. The list loads every summary of the category once and filters in memory; text
  search uses the FTS table.
- `EntryView` shows an entry's HTML in a `WKWebView` with the app's stylesheet. A `WKURLSchemeHandler` for
  `fieldguide:` serves images from `Generated/Images`; `images/creature/<key>` as PNG drawn from the
  art store; and `images/item/…` (`ItemArtPath`: `item/<system>/<name>?fallback=<icon>`, the image the import
  gives equipment) as the item's art when the user's decks have it, else the icon file; both answered
  asynchronously (a request the web view stopped is not answered). `entry:` and `trait:` links are intercepted
  and pushed onto the entry's navigation stack.
- `ArtModel` (`@Observable`) wraps Tabletop Kit's `CreatureArtStore` in `Application Support/Field
  Guide/Creature Art`, the `BestiaryStore` over `Generated/Creatures` and the `CardArtPieces` in
  `Generated/CardArt`. It matches art to creatures, and to items (`art(forItemNamed:game:)`), by name with `LibraryArtMatcher`, adds new PDFs from the
  watched folders at launch, and gives pages, thumbnails and cards their pictures and missing PDFs.
- On a page whose id is `Compendium.<system>.<pack>.Actor.<id>` and whose creature the import wrote,
  `CreatureCardView` shows Tabletop Kit's `InteractiveBattleCard`: the `BattleCard`, and `CardBack` around an
  `ArtPicture`, with the card art, glossary and an `ArtPictureLoader` over `ArtModel` in the environment. When
  the page has lore (`EntryPage.lore`, the `PageDescription` section the import writes after the stat block), a
  toolbar picker switches to it in the web view. `RootView` is the Mac's `battleCardFullScreenHost()`. The web
  fonts in `Generated` are registered at launch for the cards.
- `PDFArtView` ("Art from PDFs"), from the sidebar's toolbar, is Combat Pad's creature art settings adapted (a second
  copy; a third would move to Tabletop Kit).
- `CatalogStore` (`@Observable`) holds the system, category, query and results, and keeps the system and
  category in user defaults. Prices follow the Mac's number format at import, as the import runs there.
- `FIELD_GUIDE_SELECT` opens an entry at launch and `FIELD_GUIDE_DATA` points the Mac build at another data
  folder, for trying pages out from a script.

## Updating
- `scripts/update.sh`: fetches the pf2e repository's `upstream` remote and fast-forwards the checked-out
  branch to `upstream/<branch>`; then `make import` and `make ipad-install`.
- `make import` builds and runs `FieldGuideImport`; `make ipad-install` builds the iPad app and installs it,
  as Combat Pad does.
