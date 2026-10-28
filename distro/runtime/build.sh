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

pleamar_commit=f2689bb76906ba3e0b8f279fd196640a0cf9b600
wm_commit=ac0b35ecc197f2a6dcd96a394c61ac3d8131dd2a
pleamar_sha=60260f8e86d7c223e2ac6a1f3df792e2272c1e116a4a3a2c6783d2fc31c0e1e3
wm_sha=98ecab84ad409f15d4f388a516adf30a3c77c7434da081ee4de7bbb27954f0bc

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
fetch pleamar-wm "$wm_commit" "$wm_sha"

# Fresh extracted sources prevent a previous local edit from becoming an ISO.
# Cargo's compiled dependencies are retained separately for repeat builds.
work=$(mktemp -d "$cache/sources.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/pleamar" "$work/pleamar-wm"
tar -xzf "$cache/downloads/pleamar-$pleamar_commit.tar.gz" -C "$work/pleamar" --strip-components=1
tar -xzf "$cache/downloads/pleamar-wm-$wm_commit.tar.gz" -C "$work/pleamar-wm" --strip-components=1
(
    cd "$work"
    sha256sum pleamar/Cargo.toml pleamar/Cargo.lock pleamar-wm/Cargo.toml pleamar-wm/Cargo.lock > manifests.sha256
)

export CARGO_HOME="$cache/cargo" CARGO_TARGET_DIR="$cache/target" CARGO_BUILD_JOBS="$jobs"
rustc --version
cargo --version
(
    cd "$work/pleamar"
    cargo build --release --locked --bin pleamar
)
(
    cd "$work/pleamar-wm"
    # The optional streaming encoder is a separate workspace target.
    cargo build --release --locked --package pleamar-wm --bin pleamar-wm
)
(
    cd "$work"
    sha256sum --check manifests.sha256
)

install -Dm755 "$CARGO_TARGET_DIR/release/pleamar" "$payload/usr/bin/pleamar"
install -Dm755 "$CARGO_TARGET_DIR/release/pleamar-wm" "$payload/usr/bin/pleamar-wm"
install -Dm644 "$work/pleamar/LICENSE" "$payload/usr/share/licenses/pleamar/LICENSE"
install -Dm644 "$work/pleamar/THIRD-PARTY.md" "$payload/usr/share/licenses/pleamar/THIRD-PARTY.md"
install -Dm644 "$work/pleamar-wm/LICENSE" "$payload/usr/share/licenses/pleamar-wm/LICENSE"

"$payload/usr/bin/pleamar" --version
# Upstream pleamar-wm --version intentionally reports its embedded pleamar.
"$payload/usr/bin/pleamar-wm" --version
install -d "$payload/usr/share/nahj"
{
    printf 'pleamar 0.4.31 %s archive-sha256=%s\n' "$pleamar_commit" "$pleamar_sha"
    printf 'pleamar-wm 0.6.2 %s archive-sha256=%s\n' "$wm_commit" "$wm_sha"
    rustc --version
    cargo --version
} > "$payload/usr/share/nahj/runtime-build.txt"
printf 'Runtime payload prepared: %s\n' "$payload"
