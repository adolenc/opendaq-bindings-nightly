#!/usr/bin/env bash
# Collects the runtime libraries of an openDAQ build into opendaq-native-<triple>.tar.gz.
#
#   package-natives.sh <build-dir> <triple> <out-dir>
#
# The archive is flat: the C bindings library (copendaq), the openDAQ core libraries it loads, and the
# modules, all side by side, which is the layout the language bindings load from.
set -euo pipefail

build="${1:?usage: package-natives.sh <build-dir> <triple> <out-dir>}"
triple="${2:?}"
out="${3:?}"

case "$triple" in
    linux-*)   pattern='\.so$' ;;
    darwin-*)  pattern='(\.dylib|\.so)$' ;;
    windows-*) pattern='\.dll$' ;;
    *) echo "unsupported triple: $triple" >&2; exit 1 ;;
esac

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# Everything the build put into a bin/ directory, minus the python module and test-only libraries.
find "$build" -type f -path '*/bin/*' \
        ! -name 'opendaq.cpython*' ! -name '*_test_dll.*' \
    | grep -E "$pattern" \
    | while IFS= read -r library; do cp "$library" "$stage/"; done

for stem in daqcoretypes daqcoreobjects opendaq copendaq; do
    if ! ls "$stage" | grep -q "$stem"; then
        echo "missing a library matching *$stem* in $build" >&2
        exit 1
    fi
done

mkdir -p "$out"
tar -czf "$out/opendaq-native-$triple.tar.gz" -C "$stage" .
echo "opendaq-native-$triple.tar.gz:"
ls -1 "$stage" | sed 's/^/  /'
