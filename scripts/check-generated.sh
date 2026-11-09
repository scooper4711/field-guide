#!/bin/sh
# Stops a build when Generated/ is missing or out of date: its fingerprint (scripts/fingerprint.sh) must match the
# committed import.sha256, which "make import" keeps current. A stale Generated/ would otherwise be bundled as is,
# with whatever an older importer put in it.
#
# $1  what the caller is doing, for the error message (e.g. "Building the app")
set -eu

cd "$(dirname "$0")/.."
ACTION="${1:-Building}"

if [ ! -f Generated/catalog.sqlite ]; then
    echo "$ACTION failed: Generated/ is missing; run \"make import\" first." >&2
    exit 1
fi
if [ "$(scripts/fingerprint.sh)" != "$(cat import.sha256)" ]; then
    echo "$ACTION failed: Generated/ is out of date (it doesn't match import.sha256); run \"make import\"." >&2
    exit 1
fi
