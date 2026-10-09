#!/bin/sh
# Brings the pf2e repository up to date with the official one, imports again and installs on the iPad.
#
# The checked-out branch is fast-forwarded to the same branch of the `upstream` remote (or `origin` when
# there is no upstream). A branch with commits of its own is left alone, and the import uses it as it is.
set -eu

cd "$(dirname "$0")/.."
PF2E_REPO="${PF2E_REPO:-$HOME/git/pf2e}"

REMOTE=upstream
git -C "$PF2E_REPO" remote get-url upstream >/dev/null 2>&1 || REMOTE=origin
BRANCH="$(git -C "$PF2E_REPO" branch --show-current)"
echo "Updating $PF2E_REPO ($BRANCH) from $REMOTE..."
git -C "$PF2E_REPO" fetch --quiet "$REMOTE"
if git -C "$PF2E_REPO" merge --ff-only --quiet "$REMOTE/$BRANCH"; then
    echo "Now at: $(git -C "$PF2E_REPO" log -1 --format='%cs %s')"
else
    echo "Not updated: $BRANCH has commits of its own. Importing it as it is." >&2
fi

scripts/import.sh
scripts/install-ipad.sh
