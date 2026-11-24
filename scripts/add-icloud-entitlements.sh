#!/bin/sh
# Lets a Developer ID build of the Mac app sync sourcebook lore through iCloud (docs/specs/lore-sync).
# tabletop-kit's script of the same name adds the CloudKit container and push entitlements to the entitlements to
# sign with, embeds the provisioning profile that allows them, and checks that the profile allows the environment.
# This adds what is Field Guide's own: the container's name in the Info.plist, which turns lore syncing on.
#
# Usage: scripts/add-icloud-entitlements.sh <app> <entitlements> <team ID> <provisioning profile>
# ICLOUD_ENVIRONMENT  CloudKit environment, Production or Development. Default: Production for the App Store
#                     (CHANNEL=appstore), Development for every other build.
# KIT_SCRIPT          another copy of tabletop-kit's script (default: the one beside the resolved package)
set -eu
CONTAINER="iCloud.io.github.scooper4711.FieldGuide"
if [ $# -ne 4 ]; then
    echo "Usage: $0 <app> <entitlements> <team ID> <provisioning profile>" >&2
    exit 2
fi
APP="$1"
# Found beside the package after "swift package resolve", so the script follows the dependency pin.
ICLOUD_CONTAINERS="$CONTAINER" \
    "${KIT_SCRIPT:-.build/checkouts/tabletop-kit/scripts/add-icloud-entitlements.sh}" "$@"
plutil -replace LoreSyncContainer -string "$CONTAINER" "$APP/Contents/Info.plist"
