#!/bin/sh
# Imports both systems from the pf2e repository into Generated/.
#
# PF2E_REPO      the pf2e system repository (default ~/git/pf2e)
# FOUNDRY_APP    the Foundry app's public folder, for core icons
# FOUNDRY_DATA   Foundry's data folder, for the token art modules
# COMBAT_PAD     Combat Pad's Generated folder, for art it extracted from the Paizo PDFs
set -eu

cd "$(dirname "$0")/.."

PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"
FOUNDRY_APP="${FOUNDRY_APP:-/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public}"
FOUNDRY_DATA="${FOUNDRY_DATA:-$HOME/Library/Application Support/FoundryVTT/Data}"
COMBAT_PAD="${COMBAT_PAD:-$HOME/git/combat-pad/Generated}"

command -v cwebp >/dev/null || echo "cwebp is not installed (brew install webp); creature art will be left out."

swift build -c release --product FieldGuideImport
"$(swift build -c release --show-bin-path)/FieldGuideImport" --pf2e "$PF2E_REPO" --foundry-app "$FOUNDRY_APP" \
    --foundry-data "$FOUNDRY_DATA" --combat-pad "$COMBAT_PAD" --out Generated
echo "See Generated/import-report.md for what could not be converted."
