#!/usr/bin/env bash
# Installs what a job needs on a fresh GitHub runner.
#
#   install-deps.sh generators          mono, to run and rebuild the generators (Linux)
#   install-deps.sh build <src-dir>     what building openDAQ needs on this OS
#
# Windows runners come with everything; Linux takes openDAQ's own package list
# (.github/packages/apt.txt), macOS needs mono for the generator step of the build.
set -euo pipefail

what="${1:?usage: install-deps.sh generators | build <src-dir>}"

apt_install() {
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "$@"
}

case "$what" in
    generators)
        apt_install mono-devel
        ;;
    build)
        src="${2:?usage: install-deps.sh build <src-dir>}"
        case "$(uname -s)" in
            Linux)
                # shellcheck disable=SC2046
                apt_install $(tr '\n' ' ' < "$src/.github/packages/apt.txt")
                ;;
            Darwin)
                HOMEBREW_NO_AUTO_UPDATE=1 brew install mono
                ;;
            *)
                ;;
        esac
        ;;
    *)
        echo "unknown dependency set: $what" >&2
        exit 1
        ;;
esac
