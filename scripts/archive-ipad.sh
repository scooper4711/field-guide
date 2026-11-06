#!/bin/sh
# Archives the iPad app for the App Store into build/FieldGuide.xcarchive, with the version and build number
# from git (scripts/version.sh). Upload it from Xcode's Organizer.
set -eu

cd "$(dirname "$0")/.."

[ -f Generated/catalog.sqlite ] || { echo "Archiving failed: Generated/ is missing; run \"make import\" first." >&2; exit 1; }

ARCHIVE="build/FieldGuide.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild -project ios/FieldGuide.xcodeproj -scheme FieldGuide-iPad -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates archive -quiet
echo "Archived $ARCHIVE ($(scripts/version.sh marketing), build $(scripts/version.sh build))"
