#!/usr/bin/env bash
# Writes the manifest and publishes the release, replacing one of the same tag.
#
#   publish-release.sh <dist-dir> <tag> <owner/repo>
#
# <dist-dir> holds what prepare and build produced: opendaq.json, bindings-overlay.patch,
# opendaq-c-headers.tar.gz, source-info.env and the opendaq-native-*.tar.gz archives.
# Needs an authenticated gh.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"

dist="${1:?usage: publish-release.sh <dist-dir> <tag> <owner/repo>}"
tag="${2:?}"
repository="${3:?}"

python3 "$here/scripts/write-manifest.py" "$dist" --tag "$tag" --repository "$repository"
cat "$dist/manifest.json"

# shellcheck source=/dev/null
. "$dist/source-info.env"
notes="openDAQ API spec and C bindings built from $UPSTREAM_REPO @ $UPSTREAM_SHA"
notes+="${OVERLAY_SHA:+ with the generator overlay $OVERLAY_REPO @ $OVERLAY_SHA}."
notes+=" Consumed by the language bindings through manifest.json; not meant for manual installation."

if gh release view "$tag" >/dev/null 2>&1; then
    gh release delete "$tag" --yes --cleanup-tag
fi
gh release create "$tag" --title "$tag" --notes "$notes" \
    "$dist/manifest.json" "$dist/SHA256SUMS" "$dist/opendaq.json" "$dist/opendaq-c-headers.tar.gz" \
    "$dist/bindings-overlay.patch" "$dist"/opendaq-native-*.tar.gz
