#!/usr/bin/env bash
# Reproduces the sources prepare-source.sh produced: the upstream commit with the overlay patch on top.
#
#   checkout-source.sh <dest-dir> <upstream-sha> <bindings-overlay.patch>
#
# The build and test jobs use it, so that the generators run once (in prepare) and every platform
# builds exactly the same tree.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../nightly.env
. "$here/nightly.env"

dest="${1:?usage: checkout-source.sh <dest-dir> <upstream-sha> <patch>}"
upstream_sha="${2:?}"
patch="$(cd "$(dirname "${3:?}")" && pwd)/$(basename "$3")"

git clone --quiet --no-tags -c core.autocrlf=false "$UPSTREAM_REPO" "$dest"
git -C "$dest" checkout --quiet --detach "$upstream_sha"
git -C "$dest" apply --binary --whitespace=nowarn "$patch"
echo "checked out $UPSTREAM_REPO @ $upstream_sha into $dest, overlay applied"
