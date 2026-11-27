#!/bin/sh
# Prints a SHA-256 fingerprint of the imported compendium (the catalog's entries and traits, and the creatures
# for the battle cards), which "make import" keeps in import.sha256. The pf2e update workflow releases only when a
# new pf2e release changes it. Fonts and pictures are left out: their bytes can differ with the tools' versions
# while showing the same, and so are the Organized Play guides: they come from Lorespire, a live wiki, and change
# without a pf2e release or a commit.
set -eu

cd "$(dirname "$0")/../Generated"
{
    sqlite3 catalog.sqlite "SELECT * FROM entries WHERE category != 'organizedPlay' ORDER BY id; SELECT * FROM traits ORDER BY system, slug;"
    find Creatures -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256
} | shasum -a 256 | cut -d ' ' -f 1
