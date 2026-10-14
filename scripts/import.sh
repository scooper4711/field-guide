#!/bin/sh
# Imports both systems from the pf2e repository into Generated/.
#
# PF2E_REPO      a pf2e system repository to read instead of the release in pf2e.release, which is fetched
#                into build/pf2e (scripts/fetch-pf2e.sh); release builds always use that release
# FOUNDRY_APP    the Foundry app's public folder, for core icons; without it, icon-matches.tsv stands in
# REXARD_PACKS   the folder holding the user's Rexard packs, for the entries' icons and the battle cards' art
#                (default ~/git/rexard-packs)
# COMMUNITY_USE  the folder holding Paizo's Community Use Package, for the deities' religious symbols
#                (default ~/git/community-use-artwork)
# ARTWORK        the toolkit-artwork checkout, for Paizo's Pathfinder-Icons font (default the Artwork submodule)
#
# Creature art isn't imported: the app reads it from the user's own PDFs (Creature Art in the sidebar).
set -eu

cd "$(dirname "$0")/.."

if [ -z "${PF2E_REPO:-}" ]; then
    scripts/fetch-pf2e.sh build/pf2e
    PF2E_REPO=build/pf2e
else
    echo "Reading $PF2E_REPO; release builds read $(cut -d ' ' -f 2- pf2e.release) instead." >&2
fi
FOUNDRY_APP="${FOUNDRY_APP:-/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public}"
REXARD_PACKS="${REXARD_PACKS:-$HOME/git/rexard-packs}"
COMMUNITY_USE="${COMMUNITY_USE:-$HOME/git/community-use-artwork}"
ARTWORK="${ARTWORK:-Artwork}"

command -v cwebp >/dev/null || echo "cwebp is not installed (brew install webp); the icons will stay PNG."

swift build -c release --product FieldGuideImport
"$(swift build -c release --show-bin-path)/FieldGuideImport" --pf2e "$PF2E_REPO" --foundry-app "$FOUNDRY_APP" \
    --rexard "$REXARD_PACKS" \
    --symbols "$COMMUNITY_USE/Community Use Package- Religious Symbols" \
    --starfinder-symbols "$COMMUNITY_USE/Community Use Package- Starfinder Religious Symbols" \
    --artwork "$ARTWORK" --out Generated
echo "Copying the battle cards' art from $REXARD_PACKS..."
swift run -c release CardArtImport "$REXARD_PACKS" Generated/CardArt
echo "Copying the licenses the bundled content requires..."
# The About screen lists every file here (Tabletop Kit's LicenseText.all(in:)), titled by its name.
rm -rf Generated/Licenses
mkdir -p Generated/Licenses
cp Resources/Licenses/* Generated/Licenses/
cp "$PF2E_REPO/static/licenses/OpenGameLicense.md" "Generated/Licenses/Open Game License.md"
cp "$PF2E_REPO/static/licenses/ORCLicense.md" "Generated/Licenses/ORC License.md"
# The weekly pf2e update compares this to decide whether a new pf2e release changes anything Field Guide shows.
scripts/fingerprint.sh > import.sha256
echo "See Generated/import-report.md for what could not be converted."
