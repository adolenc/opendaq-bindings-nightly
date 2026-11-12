#!/usr/bin/env bash
# Builds and runs the tests of the C bindings (bindings/c/tests): test_ccoretypes, test_ccoreobjects,
# the test_copendaq_* suites, and test_c_compile_and_run, which compiles the umbrella header as C.
#
#   test-c-bindings.sh <src-dir> <build-dir>
#
# Configures like the release build (OPENDAQ_CMAKE_ARGS) with the tests switched on, but builds only
# what bindings/c/tests needs and runs only those tests, not openDAQ's whole suite. Needs Ninja,
# whose per-directory "<dir>/all" targets make that possible.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../nightly.env
. "$here/nightly.env"

src="${1:?usage: test-c-bindings.sh <src-dir> <build-dir>}"
build="${2:?}"

# Later -D options win, so these override the OFF in OPENDAQ_CMAKE_ARGS.
# shellcheck disable=SC2086
cmake -S "$src" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release $OPENDAQ_CMAKE_ARGS \
    -DOPENDAQ_ENABLE_TESTS=ON -DOPENDAQ_ENABLE_TEST_UTILS=ON -DOPENDAQ_ENABLE_C_BINDINGS_TESTS=ON

testfile="$(cd "$build" && find . -path '*/bindings/c/tests/CTestTestfile.cmake' | head -n1)"
if [ -z "$testfile" ]; then
    echo "::error::the configured build has no bindings/c/tests directory" >&2
    exit 1
fi
tests_dir="$(dirname "${testfile#./}")"

cmake --build "$build" --target "$tests_dir/all" --parallel
ctest --test-dir "$build/$tests_dir" --output-on-failure --no-tests=error --timeout 600
