#!/usr/bin/env bash
# Builds openDAQ with the C bindings for one platform and packages the libraries.
#
#   build-natives.sh <triple> <src-dir> <build-dir> <dist-dir>
#
# Configures with OPENDAQ_CMAKE_ARGS from nightly.env plus what the platform needs, builds Release,
# and leaves opendaq-native-<triple>.tar.gz in <dist-dir> (see package-natives.sh).
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../nightly.env
. "$here/nightly.env"

triple="${1:?usage: build-natives.sh <triple> <src-dir> <build-dir> <dist-dir>}"
src="${2:?}"
build="${3:?}"
dist="${4:?}"

case "$triple" in
    linux-x64)    platform_args=(-G Ninja) ;;
    darwin-arm64) platform_args=(-G Ninja -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15) ;;
    windows-x64)  platform_args=(-G "Visual Studio 17 2022") ;;
    *) echo "unsupported triple: $triple" >&2; exit 1 ;;
esac

# shellcheck disable=SC2086
cmake -S "$src" -B "$build" "${platform_args[@]}" -DCMAKE_BUILD_TYPE=Release $OPENDAQ_CMAKE_ARGS
cmake --build "$build" --config Release --parallel
bash "$here/scripts/package-natives.sh" "$build" "$triple" "$dist"
