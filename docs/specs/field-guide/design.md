# Field Guide: design

A SwiftPM package with an Xcode project for the iPad, in the style of Turnkeeper.

## Targets
- `FieldGuideKit` (iOS, macOS): the catalog model and its SQLite store. `GameSystem` (pf2e, sf2e),
  `EntryCategory` (not `Category`, which clashes with an Objective-C type), `EntrySummary` (what lists and filters need), `Catalog` (reads the database), `EntryQuery`
  (search text, filters and sort, applied in memory), `FacetValues` (the filter options of a list).
- `CompendiumImport` (macOS): reads the pf2e repository and writes the database and images. Code that
  Turnkeeper's `FoundryImport` already proved (JSON access, pack manifests, enricher scanning, the
  Foundry art mapping) is adapted rather than shared, so the two apps change independently.
- `FieldGuideImport`: the command-line importer.
- `FieldGuideUI` (iOS, macOS): the SwiftUI app. It uses Tabletop Kit's `BattleCards`, `Bestiary` and
  `CreatureArt`; `FieldGuideImport` uses its `CreatureImport`.
- `FieldGuide`: the Mac app, built into `Field Guide.app` by `scripts/build-app.sh`; the iPad and iPhone app lives
  in `ios/FieldGuide.xcodeproj` (scheme FieldGuide-iPad, device family 1,2) and includes `Generated/` as a folder of resources.

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
- `GMScreen` reads `packs/<system>/journals/*.json`: each page with more than a line of text becomes an entry
  with ID `Compendium.<system>.journals.JournalEntry.<journal>.JournalEntryPage.<page>`. A GM Screen page's
  section is the last level-1 page before it in sort order; the other journals' pages are in the category of
  their journal (Archetypes, Domains, Remaster Changes, else Journals, sectioned by journal name). Relative links
  (`@UUID[.<page>]`) are made absolute before enriching, and `LinkIndex` resolves page links (ignoring
  `#anchors`).
- `JournalDetails` makes each page of the Ancestries and Classes journals the Details of the ancestry or class
  of the same name in its system: the row's `details` column (also searched), with links to the page leading to
  `entry:<id>#details` (`EntryLink`). Pages without such an entry stay in Journals.
- `AreaGeometry` lists the squares an area covers, by the rules: a square counts when the squares moved to reach
  its far side, `max + min / 2` (rounded down), times 5 feet is within the area's size. Bursts start at a grid
  corner, emanations at the edges of the creature's space, reach likewise except that 10-foot reach takes every
  square within 2 (the corners too), diagonal cones at its corner, orthogonal cones at the middle of its side (a
  square counts when its column is no farther out than its row), and lines take the squares a ray from a corner
  passes through, within the burst of the same size.
- `AreaDiagrams` draws each kind as an inline `<svg>` in a `<figure>`: each square shaded by the smallest size that
  covers it (`area-1`…`area-5` in order of size, colored by `entry.css` for light and dark mode), the grid, an
  outline along the edge of each size (`outline-1`…`outline-5`: darker than its color, lighter in dark mode;
  clipped to its own squares so it lies inside its size and never overlaps a neighbor's; shaded squares draw their
  grid lines in a neutral tint, so only the outlines carry color), the origin (a dot, labeled in a left margin for
  the lines, or the creature's space lettered M, L or H) and a key.
- `LinkIndex` maps every imported document's `Compendium.<system>.<pack>.Item|Actor.<id or name>` to its
  ID, so links can be checked and rewritten.
- `Enricher` replaces `@UUID`, `@Check`, `@Damage`, `@Template`, `@Localize`, `@Embed` and `[[/r …]]` in
  description HTML. A link to an imported entry becomes `<a href="entry:<id>">`; any other becomes its
  label. Checks and damage are wrapped in spans for styling. Formulas in damage and inline rolls go through
  Tabletop Kit's `FormulaWording` with the values `PageBuilder` passes: the entry's `level.value` as
  `@item.level` and `@item.rank`, and on creature pages the creature's level as `@actor.level`
  (`CreatureBlock.values`). A pf2e label still wins, and a damage type the player chooses is left out. Last, `ActionGlyphs` rewrites Foundry's
  `<span class="action-glyph">` (the pf2e action font's letters 1–3, A, D, T, F and R in either case, or ranges
  such as "1 - 3") as one span per icon holding Paizo's Pathfinder-Icons code point (Tabletop Kit's
  `ActionIcons`), with separators left as text, since that font draws letters and hyphens blank. The entry
  pages' own glyphs (`HTML.actionGlyph`) go through the same conversion. The import copies the font unaltered
  from the `Artwork` submodule (`--artwork`) into `Generated/Fonts`; `entry.css` sets it at 0.97em, 0.075em
  below the baseline, matching the pf2e action font it replaced.
- `PageBuilder` writes each entry's HTML body: a header (name, type and level), traits, a details block
  for the entry's kind (`DetailLines`), then the enriched description. Creatures and hazards use
  `StatBlockBuilder`, which follows Turnkeeper's parsers for senses, skills, defenses, Strikes and
  spellcasting.
- `FacetExtractor` records each entry's filter values: level, rarity, traits, source title and the
  category's own facets as a JSON object. A deity's subtitle is its kind: Deity, Pantheon, Covenant or
  Philosophy.
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
  `<img>` removes itself when the app has no art for it.
- `ReligiousSymbols` lists the PNGs in the Community Use Package's Religious Symbols folders by name
  (`--symbols`, `--starfinder-symbols`; default `~/git/community-use-artwork/Community Use Package- …`).
  A deity takes the picture named as it is, or whose name starts with its name and a space ("Thamir Gixx"
  for Thamir), ignoring a leading "The "; Starfinder deities look in the Starfinder folder first.
  `ImageCollector` writes it as WebP to `Images/symbols/<system>/<name>.webp`, the deity's image in place of
  any Rexard icon, and `PageBuilder` puts it in the header as `<img class="symbol">`, in the top-right corner,
  instead of the art on the left.
- `FieldGuideImport` also runs Tabletop Kit's `BestiaryImporter` into `Generated/Creatures`, and
  `scripts/import.sh` runs `CardArtImport` to copy the Rexard card pieces into `Generated/CardArt`.
- `CatalogWriter` writes `Generated/catalog.sqlite`: table `entries` (id, system, category, name, level,
  rarity, traits, source, image, subtitle, facets JSON, html) and an FTS5 table over name and text.
- Trait descriptions come from the language files through `traits.ts`, as in Turnkeeper, and are stored
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
  toolbar picker switches to it in the web view. `FittedCard` lays the card out 440 points wide and scales it to
  the column's width. An entry with Details gets an [Overview | Details] picker instead (`EntryTab`, opened on
  Details by `entry:<id>#details` links). `RootView` is the Mac's `battleCardFullScreenHost()`. The web
  fonts in `Generated` are registered at launch for the cards.
- `PDFArtView` ("Art from PDFs"), from the sidebar's toolbar, is Turnkeeper's creature art settings adapted (a second
  copy; a third would move to Tabletop Kit).
- `CatalogStore` (`@Observable`) holds the system, category, query and results, and keeps the system and
  category in user defaults. Prices are formatted in American English at import, whatever the Mac's locale.
- Search Everything: `GlobalSearch` (FieldGuideKit) holds every entry of the system, read once with
  `Catalog.summaries(in:)`, and ranks names in memory: names starting with the text, then names with each word
  at a word's start, then the rest. Text searches run on `TextSearcher`, an actor with its own connection, using
  `Catalog.rankedSearch` (bm25, the name weighted ten to one; the match materialized first so it runs once);
  a newer search cancels one still running. The sidebar shows `GlobalSearchResults` while its search has text;
  the entry column's toolbar button shows the sidebar with the search focused. From the entry alone (iPad
  portrait), iOS turns a request for every column into the list and the entry, so the button asks for the list
  and the entry first and every column a moment later. The columns get a compact width on the iPad too, so
  `RootView` decides whether the window shows one column at a time and passes it down as `showsOneColumn`. In a
  compact width (the iPhone), where the split view shows one column at a time, the list's toolbar has the button
  too, and it opens `SearchEverythingSheet` instead: `GlobalSearchResults` in a sheet, dismissed when a match or
  Show All is opened. The list hides its system switch there; the categories screen has it. `RootView` binds the
  split view's `preferredCompactColumn`: the categories at launch (the entry with `FIELD_GUIDE_SELECT`), the list or
  the entry when the search opens one. The categories are buttons there rather than the list's selection,
  because a selected category opens its list by itself in a collapsed split view, also when switching the
  system chooses one.
- `FIELD_GUIDE_SELECT` opens an entry at launch and `FIELD_GUIDE_DATA` points the Mac build at another data
  folder, for trying pages out from a script.
- Mac menus: `FieldGuideCommands` adds the Go menu and Art from PDFs… to File. The store is the app's, so
  the system commands set it directly; Back and Search Everything reach the window through focused scene
  values (`entryPath`, the detail column's navigation path, and `searchEverything`, `RootView`'s action), and
  `SidebarView` shows Art from PDFs for `showArtFromPDFs`.
- About: Tabletop Kit's `AppNotices`, with `AboutInfo.fieldGuide` (`About.swift`): `AboutCommands` on the Mac and
  an `AboutSheet` from the sidebar's toolbar on the iPad.

## Updating and releasing
- `pf2e.release` holds a pf2e commit and the system release tags on it. `make import` fetches that one commit
  from `foundryvtt/pf2e` into `build/pf2e` (`scripts/fetch-pf2e.sh`) and runs `FieldGuideImport` on it.
  `scripts/update.sh` (`make update`) writes pf2e's newest `pf2e-*` or `sf2e-*` release
  (`scripts/latest-pf2e-release.sh`) to `pf2e.release`, imports and installs on the iPad.
- `IconMap` compares the Foundry icons whose files are on this machine and takes the matches saved in
  `icon-matches.tsv` (Foundry path, Rexard file, distance) for the rest; an import with the Rexard packs
  rewrites that table. `make import` also writes `import.sha256` (`scripts/fingerprint.sh`): a SHA-256 of the
  catalog's entries and traits and the battle cards' creatures; fonts and pictures are left out, since tool
  versions change their bytes.
- `scripts/build-app.sh` builds `build/Field Guide.app`: the `FieldGuide` executable, the SwiftPM resource bundles,
  an icon made from the iPad's, and `Generated/` (found through `Bundle.main`), signed by `scripts/sign-app.sh` (see
  Signing) with `Resources/FieldGuide.entitlements` (R7.5): the App Sandbox, network client (WebKit's web content
  process won't start without it, though pages are local), read-only access to files the user picks, and app-scoped
  bookmarks for the art library's PDFs and watched folders. `Resources/container-migration.plist` goes into the
  bundle's Resources; on the first sandboxed launch macOS moves `Application Support/Field Guide` and the
  preferences into the container. On the Mac, "Import from Scrollkeeper…" then can't read Scrollkeeper's folder and
  opens the folder picker instead. `scripts/make-dmg.sh` packages it (`make dmg`).
- **Release workflow** (on `v*` tags, or called): fetches the `Artwork` submodule with the `ARTWORK_SSH_KEY`
  deploy key, installs `cwebp`, imports with `REXARD_PACKS=Artwork/rexard` and
  `COMMUNITY_USE=Artwork/community-use`, warns when `import.sha256` or `icon-matches.tsv` differs from the
  committed one, tests, builds the universal app and attaches `Field-Guide-<version>.dmg` to the release,
  creating a draft if there is none. Run by hand, it keeps the disk image as a workflow artifact instead.
- **Signing.** `scripts/sign-app.sh` signs the app with the first Developer ID Application certificate in the
  keychain, with the hardened runtime and a secure timestamp, or ad hoc when there is none (`SIGNING_IDENTITY`
  overrides it). On GitHub, `scripts/add-signing-certificate.sh` puts the certificate from the
  `DEVELOPER_ID_CERTIFICATE` and `DEVELOPER_ID_CERTIFICATE_PASSWORD` secrets into a temporary keychain; without it a
  release fails and a trial build is signed ad hoc. For a release, `scripts/notarize.sh` signs the disk image, has
  Apple's notary service check it (the `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID` and `NOTARY_PASSWORD` secrets, or a
  notarytool keychain profile on a Mac) and staples the ticket to it. The team ID is kept only in the secrets and
  the keychain.
- **pf2e update workflow** (Mondays, or by hand): when pf2e has a newer release, a Linux job lists the files
  changed between the two commits (fetched without their contents). If none is under `packs` or `static`, it
  commits `pf2e.release` alone. Otherwise a macOS job imports the new release; an unchanged fingerprint commits
  `pf2e.release` alone, and a changed one commits it with `import.sha256` and `icon-matches.tsv` and, if the
  app has a `v*` tag, tags the next patch version and calls the release workflow. Commits go through the
  GraphQL API (`scripts/commit-to-github.sh`) so GitHub signs them.
