#!/usr/bin/env bash
# Decides what a nightly builds and what its release is called.
#
#   resolve-release.sh [upstream-sha [overlay-sha [force]]]
#
# An empty or missing sha means the tip of UPSTREAM_REF / OVERLAY_REF from nightly.env; force is
# "true" to rebuild a release that already exists. Prints, as key=value lines for $GITHUB_OUTPUT:
#   tag           nightly-<date>-<upstream sha>[-<overlay sha>]
#   upstream_sha  overlay_sha
#   skip          true when a release for the same pair of commits exists and force is not set
#
# The tag names the inputs, so it is the same for the same sources; the date is that of the first
# build of them. Needs git and an authenticated gh.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../nightly.env
. "$here/nightly.env"

upstream_sha="${1:-}"
overlay_sha="${2:-}"
force="${3:-false}"

if [ -z "$upstream_sha" ]; then
    upstream_sha="$(git ls-remote "$UPSTREAM_REPO" "refs/heads/$UPSTREAM_REF" | cut -f1)"
fi
if [ -z "$overlay_sha" ] && [ -n "${OVERLAY_REPO:-}" ]; then
    overlay_sha="$(git ls-remote "$OVERLAY_REPO" "refs/heads/$OVERLAY_REF" | cut -f1)"
fi
if [ -z "$upstream_sha" ] || { [ -n "${OVERLAY_REPO:-}" ] && [ -z "$overlay_sha" ]; }; then
    echo "::error::could not resolve the upstream or overlay commit" >&2
    exit 1
fi

suffix="$(printf '%.7s' "$upstream_sha")${overlay_sha:+-$(printf '%.7s' "$overlay_sha")}"
tag="$(gh release list --limit 200 --json tagName --jq '.[].tagName' \
       | grep -E "^nightly-[0-9]{8}-${suffix}\$" | head -n1 || true)"
skip=false
if [ -n "$tag" ] && [ "$force" != "true" ]; then
    echo "Release $tag already covers these sources; nothing to do." >&2
    skip=true
fi
[ -n "$tag" ] || tag="nightly-$(date -u +%Y%m%d)-${suffix}"

echo "tag=$tag"
echo "upstream_sha=$upstream_sha"
echo "overlay_sha=$overlay_sha"
echo "skip=$skip"
