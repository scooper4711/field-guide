#!/bin/sh
# Lets a Developer ID build of the Mac app sync sourcebook lore through iCloud (docs/specs/lore-sync): adds the CloudKit
# container and push entitlements to the entitlements to sign with, embeds the provisioning profile that allows them,
# and names the container in the Info.plist, which turns syncing on.
#
# Usage: scripts/add-icloud-entitlements.sh <app> <entitlements> <team ID> <provisioning profile>
# ICLOUD_ENVIRONMENT  CloudKit environment, Production (default) or Development. An iPad build installed from Xcode
#                     uses Development, so to sync with one, build the Mac app for Development too.
set -eu

APP="$1"
ENTITLEMENTS="$2"
TEAM_ID="$3"
PROFILE="$4"
ENVIRONMENT="${ICLOUD_ENVIRONMENT:-Production}"
CONTAINER="iCloud.io.github.scooper4711.FieldGuide"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Contents/Info.plist")"

case "$ENVIRONMENT" in
    Production) PUSH=production ;;
    Development) PUSH=development ;;
    *) echo "Adding iCloud failed: ICLOUD_ENVIRONMENT must be Production or Development." >&2; exit 1 ;;
esac

cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
/usr/libexec/PlistBuddy \
    -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" \
    -c "Add :com.apple.developer.team-identifier string $TEAM_ID" \
    -c "Add :com.apple.developer.icloud-container-identifiers array" \
    -c "Add :com.apple.developer.icloud-container-identifiers:0 string $CONTAINER" \
    -c "Add :com.apple.developer.icloud-services array" \
    -c "Add :com.apple.developer.icloud-services:0 string CloudKit" \
    -c "Add :com.apple.developer.icloud-container-environment string $ENVIRONMENT" \
    -c "Add :com.apple.developer.aps-environment string $PUSH" \
    "$ENTITLEMENTS"
plutil -insert LoreSyncContainer -string "$CONTAINER" "$APP/Contents/Info.plist"
echo "Added iCloud ($ENVIRONMENT) for $CONTAINER"
