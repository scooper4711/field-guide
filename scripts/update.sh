#!/bin/sh
# Switches pf2e.release to pf2e's newest release, imports again and installs on the iPad.
set -eu

cd "$(dirname "$0")/.."

scripts/latest-pf2e-release.sh > pf2e.release
echo "Now on pf2e $(cut -d ' ' -f 2- pf2e.release)"
scripts/import.sh
scripts/install-ipad.sh
