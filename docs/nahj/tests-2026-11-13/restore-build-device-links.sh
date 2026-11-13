#!/usr/bin/env bash
# Cloud-container setup only: restore standard links missing from its devtmpfs.
set -euo pipefail
mount_dir=/build/qa-devtmpfs-check
mkdir -p "$mount_dir"
mountpoint -q "$mount_dir" && { echo 'Probe directory already mounted' >&2; exit 1; }
mount -t devtmpfs -o mode=0755,nosuid devtmpfs "$mount_dir"
trap 'umount "$mount_dir"' EXIT
for name in fd stdin stdout stderr; do
    case "$name" in
        fd) target=/proc/self/fd;;
        stdin) target=/proc/self/fd/0;;
        stdout) target=/proc/self/fd/1;;
        stderr) target=/proc/self/fd/2;;
    esac
    path=$mount_dir/$name
    if [[ -L $path ]]; then
        [[ $(readlink "$path") == "$target" ]] || { echo "Unexpected link: $path" >&2; exit 1; }
    elif [[ -e $path ]]; then
        echo "Refusing to replace existing entry: $path" >&2
        exit 1
    else
        ln -s "$target" "$path"
        printf 'Restored %s -> %s\n' "$name" "$target"
    fi
done
