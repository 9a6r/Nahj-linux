#!/usr/bin/env bash
# Reproduce the upstream shell's fonts and optional desktop programs from pinned
# sources. Run inside the Arch build image; never install onto the build host.
set -euo pipefail

download_only=false
if [[ ${1:-} == --download-only ]]; then
    download_only=true
    shift
fi
if (( $# != 2 )); then
    echo "Usage: $0 [--download-only] PAYLOAD_DIRECTORY CACHE_DIRECTORY" >&2
    exit 2
fi
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
manifest="$repo/distro/runtime/desktop-assets.lock.json"
payload=$(realpath -m "$1")
cache=$(realpath -m "$2")
for path in "$payload" "$cache"; do
    case "$path" in
        /|/usr|/usr/*|/etc|/etc/*|"$repo"|"$repo"/*)
            echo 'Payload and cache must be dedicated build directories outside the checkout and system paths.' >&2
            exit 2 ;;
    esac
done
mkdir -p "$cache/downloads"

verify() {
    printf '%s  %s\n' "$2" "$1" | sha256sum --check --status
}

while IFS=$'\t' read -r filename url checksum; do
    target="$cache/downloads/$filename"
    if [[ ! -f "$target" ]]; then
        temporary=$(mktemp "$cache/downloads/.fetch.XXXXXX")
        if ! curl --fail --show-error --silent --location --retry 3 \
            --connect-timeout 20 --max-time 180 --proto '=https' \
            --proto-redir '=https' "$url" -o "$temporary"; then
            rm -f "$temporary"
            exit 1
        fi
        if ! verify "$temporary" "$checksum"; then
            rm -f "$temporary"
            echo "Downloaded asset checksum mismatch: $filename" >&2
            exit 1
        fi
        mv "$temporary" "$target"
    elif ! verify "$target" "$checksum"; then
        echo "Cached asset checksum mismatch: $target. Remove that cached file before retrying." >&2
        exit 1
    fi
done < <(jq -r '.assets[] | [.file, .url, .sha256] | @tsv' "$manifest")

if $download_only; then
    echo "Verified $(jq '.assets | length' "$manifest") pinned desktop source/font assets."
    exit 0
fi

jobs=${NAHJ_BUILD_JOBS:-2}
[[ $jobs =~ ^[1-9][0-9]*$ ]] || { echo 'NAHJ_BUILD_JOBS must be a positive integer.' >&2; exit 2; }
mkdir -p "$payload"
work=$(mktemp -d "$cache/build.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/iris" "$work/mpvpaper"
tar -xzf "$cache/downloads/iris.tar.gz" --strip-components=1 -C "$work/iris"
tar -xzf "$cache/downloads/mpvpaper.tar.gz" --strip-components=1 -C "$work/mpvpaper"

# Build without contacting a Python package index. Dependencies come from the
# verified Arch package database installed in the build image.
python -m build --wheel --no-isolation --outdir "$work/wheels" "$work/iris"
python -m installer --destdir "$payload" "$work"/wheels/iris_colors-*.whl
install -Dm644 "$work/iris/LICENSE" "$payload/usr/share/licenses/iris-colors/LICENSE"

meson setup "$work/mpvpaper-build" "$work/mpvpaper" \
    --prefix=/usr --buildtype=release --wrap-mode=nodownload
meson compile -C "$work/mpvpaper-build" -j "$jobs"
DESTDIR="$payload" meson install -C "$work/mpvpaper-build" --no-rebuild
install -Dm644 "$work/mpvpaper/LICENSE" "$payload/usr/share/licenses/mpvpaper/LICENSE"
install -Dm644 "$work/mpvpaper/mpvpaper.man" "$payload/usr/share/man/man1/mpvpaper.1"

while IFS=$'\t' read -r filename destination; do
    install -Dm644 "$cache/downloads/$filename" "$payload/$destination"
done < <(jq -r '.assets[] | select(.install) | [.file, .install] | @tsv' "$manifest")
install -Dm644 "$manifest" "$payload/usr/share/doc/nahj/desktop-assets.lock.json"

# Exercise actual palette generation using the same options as Vitreus. Calling
# the generator directly avoids Iris's per-user cache writes in a build job.
PYTHONPATH="$work/iris" python - "$repo/assets/banner.jpeg" <<'PY'
import re
import sys
from iris.generator import generate

palette = generate(sys.argv[1], dark_mode=1, glass=True)
for key in ("bg", "surface", "fg", "dim", "accent", "red"):
    assert re.fullmatch(r"#[0-9a-fA-F]{6}", palette[key]), (key, palette[key])
print("Iris generated all six semantic colors used by Vitreus.")
PY
"$payload/usr/bin/mpvpaper" --help >/dev/null
test -x "$payload/usr/bin/iris"
test -x "$payload/usr/bin/mpvpaper-holder"
echo 'Installed and checked Iris, mpvpaper, and six original font families in the payload.'
