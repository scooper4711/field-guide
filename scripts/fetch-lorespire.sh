#!/bin/sh
# Downloads Paizo's Organized Play guides from Lorespire (lorespire.paizo.com) into DIR (default
# Generated/Lorespire), for GMs without a connection: the Pathfinder Society and Starfinder Society (second edition)
# guides, each from its Complete Compilation page, the Venture-Officer Handbook, and the licenses page that covers
# them. Each import downloads them afresh: Lorespire is a live wiki, so there is no release to pin.
#
# Usage: scripts/fetch-lorespire.sh [DIR]
set -eu

cd "$(dirname "$0")/.."

swift build -c release --product FieldGuideLorespire
"$(swift build -c release --show-bin-path)/FieldGuideLorespire" "${1:-Generated/Lorespire}"
