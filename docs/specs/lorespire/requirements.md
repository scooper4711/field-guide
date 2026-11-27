# Offline Lorespire: requirements

Paizo's Organized Play guides, which live on the Lorespire wiki (lorespire.paizo.com), are bundled with Field Guide
so a GM can read them at a table without a connection (issue #110).

## R1 What is bundled
- R1.1 The Pathfinder Society (second edition) guide and the Starfinder Society (second edition) guide, each from
  its Complete Compilation page: introduction, core guide, player options, GM options and supplemental materials.
- R1.2 The Venture-Officer Handbook, for both systems.
- R1.3 The Licenses and Trademarks page: the Open Game License and Paizo's trademark notice.
- R1.4 The images and attachments those pages use.
- R1.5 Not the Starfinder Society (first edition) guide, and not the welcome kits.
- R1.6 Each import downloads them afresh: Lorespire is a live wiki, with no release to pin.

## R2 Entries
- R2.1 One entry per page of the original wiki, split from the compilations, named after its heading, in the part
  of the guide it belongs to (Introduction, Core Guide, Player Options and Tools, GM Options and Tools, Supplemental
  Materials, Venture-Officer Handbook), in guide order.
- R2.2 Links between guide pages open like other Field Guide links; links to pages that weren't downloaded open
  Lorespire on the web.
- R2.3 The entries look like the rest of the app: none of the wiki's own styling, tabs shown one after another,
  footnotes inline.
- R2.4 Full-text search covers them.

## R3 Browsing
- R3.1 One sidebar category, "Organized Play", whose list is grouped by part, in guide order. The system switch
  picks the Pathfinder or Starfinder guide; the Venture-Officer Handbook shows under both.

## R4 Licenses
- R4.1 The About screen shows the licenses page.

## R5 Build
- R5.1 The guides don't change the import's fingerprint: they change without a commit, and the fingerprint checks
  the committed pf2e import.
- R5.2 Tests use synthetic pages, never Paizo's text.
