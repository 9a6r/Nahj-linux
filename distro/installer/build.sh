#!/usr/bin/env bash
# Run in the Arch build container as its unprivileged builder user.
set -euo pipefail
if (( EUID == 0 )); then
    echo 'Build the installer as the unprivileged builder user (makepkg forbids root).' >&2
    exit 1
fi
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=${1:?Usage: distro/installer/build.sh PACKAGE_OUTPUT_DIRECTORY}
mkdir -p "$out"
out=$(cd "$out" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/nahj-installer.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp -a "$repo/distro/installer/." "$work/"
cd "$work"
export PKGDEST="$out"
makepkg --cleanbuild --clean --noconfirm
