#!/usr/bin/env bash
# Build the pinned desktop runtime; all generated files stay outside the checkout.
# Usage: build.sh PAYLOAD_DIRECTORY CACHE_DIRECTORY
set -euo pipefail

payload=${1:?Usage: build.sh PAYLOAD_DIRECTORY CACHE_DIRECTORY}
cache=${2:?Usage: build.sh PAYLOAD_DIRECTORY CACHE_DIRECTORY}
jobs=${NAHJ_BUILD_JOBS:-${CARGO_BUILD_JOBS:-2}}
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo 'NAHJ_BUILD_JOBS must be a positive integer' >&2; exit 2; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
    echo 'The Nahj ISO runtime targets Linux x86_64.' >&2; exit 2;
}

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
mkdir -p "$payload" "$cache/downloads" "$cache/cargo" "$cache/target"
payload=$(realpath "$payload")
cache=$(realpath "$cache")
for directory in "$payload" "$cache"; do
    case "$directory/" in
        "$repo/"*) echo 'Use payload and cache directories outside the source checkout.' >&2; exit 2 ;;
    esac
done

pleamar_commit=82d4e1cf7eadff41fce5fe433a408ee55228903a
pleamar_sha=bf23f4fe17c449616994b1bcbfa08be09a5d748e2be74e7c50ea7ceedafc4ff1

fetch() {
    local project=$1 commit=$2 checksum=$3 archive
    archive="$cache/downloads/$project-$commit.tar.gz"
    if [[ ! -f "$archive" ]]; then
        curl --fail --show-error --location --retry 3 --proto '=https' --tlsv1.2 \
            "https://codeload.github.com/k4ditano/$project/tar.gz/$commit" \
            --output "$archive.partial"
        printf '%s  %s\n' "$checksum" "$archive.partial" | sha256sum --check --status
        mv "$archive.partial" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check
}
fetch pleamar "$pleamar_commit" "$pleamar_sha"

# Fresh extracted sources prevent a previous local edit from becoming an ISO.
# Cargo's compiled dependencies are retained separately for repeat builds.
work=$(mktemp -d "$cache/sources.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/pleamar"
tar -xzf "$cache/downloads/pleamar-$pleamar_commit.tar.gz" -C "$work/pleamar" --strip-components=1
patch --directory="$work/pleamar" --strip=1 --forward < "$repo/distro/runtime/patches/pleamar-body-show.patch"
(
    cd "$work"
    sha256sum pleamar/Cargo.toml pleamar/Cargo.lock > manifests.sha256
)

export CARGO_HOME="$cache/cargo" CARGO_TARGET_DIR="$cache/target" CARGO_BUILD_JOBS="$jobs"
rustc --version
cargo --version
(
    cd "$work/pleamar"
    cargo build --release --locked --bin pleamar
)
(
    cd "$work"
    sha256sum --check manifests.sha256
)

install -Dm755 "$CARGO_TARGET_DIR/release/pleamar" "$payload/usr/bin/pleamar"
install -Dm644 "$work/pleamar/LICENSE" "$payload/usr/share/licenses/pleamar/LICENSE"
install -Dm644 "$work/pleamar/THIRD-PARTY.md" "$payload/usr/share/licenses/pleamar/THIRD-PARTY.md"
# Hyprland is the only compositor shipped by Nahj. Clear stale outputs when
# reusing a payload from before this policy; keep upstream scene sources intact.
rm -f "$payload/usr/bin/pleamar-wm"
rm -rf "$payload/usr/share/licenses/pleamar-wm"

"$payload/usr/bin/pleamar" --version
install -d "$payload/usr/share/nahj"
{
    printf 'pleamar 0.4.31 %s archive-sha256=%s\n' "$pleamar_commit" "$pleamar_sha"
    sha256sum "$repo/distro/runtime/patches/pleamar-body-show.patch"
    rustc --version
    cargo --version
} > "$payload/usr/share/nahj/runtime-build.txt"
printf 'Runtime payload prepared: %s\n' "$payload"
