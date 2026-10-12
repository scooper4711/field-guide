#!/bin/sh
# Imports both systems from the pf2e repository into Generated/.
#
# PF2E_REPO      the pf2e system repository (default ~/git/pf2e)
# FOUNDRY_APP    the Foundry app's public folder, for core icons
# SCROLLKEEPER   Scrollkeeper's downloads, for the area diagrams in the Player Core PDFs
# REXARD_PACKS   the folder holding the user's Rexard UI packs, for the battle cards' art (default ~/git/rexard-packs)
#
# Creature art isn't imported: the app reads it from the user's own PDFs (Creature Art in the sidebar).
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
FOUNDRY_APP="${FOUNDRY_APP:-/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public}"
SCROLLKEEPER="${SCROLLKEEPER:-$HOME/Library/Application Support/Scrollkeeper/Files}"
REXARD_PACKS="${REXARD_PACKS:-$HOME/git/rexard-packs}"

command -v cwebp >/dev/null || echo "cwebp is not installed (brew install webp); the area diagrams will stay PNG."

swift build -c release --product FieldGuideImport
"$(swift build -c release --show-bin-path)/FieldGuideImport" --pf2e "$PF2E_REPO" --foundry-app "$FOUNDRY_APP" \
    --scrollkeeper "$SCROLLKEEPER" --out Generated
echo "Copying the battle cards' art from $REXARD_PACKS..."
swift run -c release CardArtImport "$REXARD_PACKS" Generated/CardArt
echo "See Generated/import-report.md for what could not be converted."
