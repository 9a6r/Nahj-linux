#!/usr/bin/env bash
# Build in the provided Arch container, not on a user's installed desktop.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
releng=/usr/share/archiso/configs/releng
work= out= payload= packages=
prepare_only=false
usage() {
    cat <<'EOF'
Usage: distro/build-iso.sh --work-dir DIR --out-dir DIR --payload-dir DIR --package-dir DIR
                          [--releng-dir DIR] [--prepare-only]

The work directory must not already contain a generated profile. The payload is
an installed filesystem tree with pleamar, fonts, desktop helpers, and the Nahj
Plymouth theme. The package directory contains locally built nahj-installer.
--prepare-only composes and validates the profile without installing packages,
signing the build repository, mounting filesystems, or creating an ISO.
The full build requires root in an Arch container with mount capabilities.
EOF
}
die() { printf 'Nahj build: %s\n' "$*" >&2; exit 1; }
while (($#)); do
    case "$1" in
        --work-dir|--out-dir|--payload-dir|--package-dir|--releng-dir)
            (($# >= 2)) || die "missing value for $1"
            case "$1" in
                --work-dir) work=$2;; --out-dir) out=$2;; --payload-dir) payload=$2;;
                --package-dir) packages=$2;; --releng-dir) releng=$2;;
            esac
            shift 2;;
        --prepare-only) prepare_only=true; shift;;
        --help|-h) usage; exit 0;;
        *) die "unknown argument: $1";;
    esac
done
[[ -n $work && -n $out && -n $payload && -n $packages ]] || { usage >&2; exit 2; }
work=$(realpath -m "$work"); out=$(realpath -m "$out")
payload=$(realpath -e "$payload"); packages=$(realpath -e "$packages")
releng=$(realpath -e "$releng")
for path in "$work" "$out"; do
    [[ $path != / && $path != "$repo" && $path != "$repo/"* ]] || die "build paths must be outside the checkout: $path"
done
[[ -f $releng/profiledef.sh && -f $releng/packages.x86_64 ]] || die "Archiso releng profile not found"
[[ ! -e $work/profile ]] || die "profile already exists in $work; use a fresh work directory to avoid stale build checkpoints"
for required in usr/bin/pleamar usr/bin/iris usr/bin/mpvpaper usr/share/plymouth/themes/nahj/nahj.plymouth; do
    [[ -f $payload/$required ]] || die "missing payload file: $required"
done
shopt -s nullglob
local_packages=("$packages"/*.pkg.tar.zst)
((${#local_packages[@]})) || die "no locally built packages in $packages"
installer_packages=("$packages"/nahj-installer-[0-9]*.pkg.tar.zst)
((${#installer_packages[@]} == 1)) || die "expected exactly one nahj-installer package"
mkdir -p "$work" "$out"
profile=$work/profile
cp -a "$releng" "$profile"
cp -a "$repo/distro/archiso/airootfs/." "$profile/airootfs/"
cp -a "$payload/." "$profile/airootfs/"
cat "$repo/distro/archiso/profiledef.override.sh" >> "$profile/profiledef.sh"

# Keep official rescue utilities, replacing only the generic kernel package.
cat "$releng/packages.x86_64" "$repo/distro/archiso/packages.x86_64" \
    | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' -e '/^linux$/d' -e '/^linux-headers$/d' -e '/^virtualbox-guest-utils-nox$/d' \
    | sort -u > "$profile/packages.x86_64"
printf '%s\n' nahj-installer >> "$profile/packages.x86_64"

# The packaged seed is a source snapshot, not a second development checkout.
seed=$profile/airootfs/usr/share/nahj/vitreus
mkdir -p "$seed"
tar -C "$repo" --exclude='./.git' --exclude='./distro' --exclude='./screenshots' --exclude='./docs/nahj' -cf - . \
    | tar -C "$seed" -xf -
find "$seed" -type d -exec chmod 0755 {} +
find "$seed" -type f -perm /111 -exec chmod 0755 {} +
find "$seed" -type f ! -perm /111 -exec chmod 0644 {} +

# Use the original login theme and original backdrop. This script writes only
# the generated image tree; it does not touch the repository's SDDM files.
bash "$repo/distro/runtime/build-greeter.sh" "$payload" "$profile/airootfs/usr/share/sddm/themes/vitreus"

# mkarchiso copies the overlay with --no-preserve=mode. Record every payload
# and shell executable explicitly so programs remain runnable in the live image.
python3 - "$profile" <<'PY_PERMISSIONS'
from pathlib import Path
import shlex
import sys
profile = Path(sys.argv[1])
root = profile / "airootfs"
with (profile / "profiledef.sh").open("a") as handle:
    for directory in ("usr/bin", "usr/local", "usr/share/nahj/vitreus"):
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and not path.is_symlink() and path.stat().st_mode & 0o111:
                key = shlex.quote("/" + str(path.relative_to(root)))
                handle.write(f'\nfile_permissions[{key}]="0:0:755"\n')
PY_PERMISSIONS

# NetworkManager exclusively owns the desktop network. Remove live releng's
# competing network stack and automatic root shell; leave rescue services.
rm -rf "$profile/airootfs/etc/systemd/system/getty@tty1.service.d" \
       "$profile/airootfs/etc/systemd/system/cloud-init.target.wants" \
       "$profile/airootfs/etc/systemd/network" \
       "$profile/airootfs/etc/systemd/networkd.conf.d" \
       "$profile/airootfs/etc/systemd/resolved.conf.d" \
       "$profile/airootfs/etc/systemd/system/systemd-networkd-wait-online.service.d"
rm -f "$profile/airootfs/root/.automated_script.sh" "$profile/airootfs/root/.zlogin" \
      "$profile/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service" \
      "$profile/airootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
      "$profile/airootfs/etc/systemd/system/multi-user.target.wants/systemd-resolved.service" \
      "$profile/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service" \
      "$profile/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service" \
      "$profile/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" \
      "$profile/airootfs/etc/resolv.conf"
ln -s /run/NetworkManager/resolv.conf "$profile/airootfs/etc/resolv.conf"

# Every loader references the actual zen kernel and initramfs. Keep upstream's
# UUID placeholders intact so mkarchiso still resolves removable media properly.
while IFS= read -r -d '' file; do
    sed -i -e 's/vmlinuz-linux\([[:space:]]\|$\)/vmlinuz-linux-zen\1/g' \
           -e 's/initramfs-linux\.img/initramfs-linux-zen.img/g' \
           -e 's/Arch Linux install medium/Nahj Linux live desktop/g' \
           -e 's/MENU TITLE Arch Linux/MENU TITLE Nahj Linux/g' "$file"
done < <(find "$profile/syslinux" "$profile/efiboot" "$profile/grub" -type f \( -name '*.cfg' -o -name '*.conf' \) -print0)

# Pin the network destination, while retaining the package signature policy.
sed -i 's|^Include = /etc/pacman.d/mirrorlist$|Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch|' "$profile/pacman.conf"
local_repo=$work/local-repo
mkdir -p "$local_repo"
cp "${local_packages[@]}" "$local_repo/"
cat >> "$profile/pacman.conf" <<EOF

[nahj-build]
SigLevel = Required
Server = file://$local_repo
EOF

# Cheap structural checks fail before the costly pacstrap/squashfs work.
grep -qx 'linux-zen' "$profile/packages.x86_64"
! grep -qx 'linux' "$profile/packages.x86_64"
! grep -REq 'vmlinuz-linux([[:space:]]|$)|initramfs-linux\.img' "$profile/syslinux" "$profile/efiboot" "$profile/grub"
test -f "$profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
test -f "$profile/airootfs/etc/skel/.config/pleamar/autostart"
test -f "$profile/airootfs/usr/share/sddm/themes/vitreus/background.jpg"
test -f "$profile/airootfs/usr/share/plymouth/themes/nahj/nahj.plymouth"
printf 'Profile prepared: %s\n' "$profile"
$prepare_only && exit 0
((EUID == 0)) || die 'the ISO build needs root inside the Arch build container'
for command in mkarchiso repo-add pacman-key gpg bsdtar; do
    command -v "$command" >/dev/null || die "required command missing: $command"
done

# A dedicated local signing key authenticates our own freshly built packages.
# Official Arch repositories continue to require their normal trusted signatures.
# The private key stays in the build workspace, never in the image or artifacts.
signing=$work/signing
install -d -m 0700 "$signing"
gpg --homedir "$signing" --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key 'Nahj local image build <build@nahj.invalid>' ed25519 sign 1d
fingerprint=$(gpg --homedir "$signing" --with-colons --list-secret-keys | awk -F: '$1 == "fpr" { print $10; exit }')
[[ $fingerprint =~ ^[A-F0-9]{40}$ ]] || die 'could not determine package signing key'
gpg --homedir "$signing" --batch --export "$fingerprint" > "$work/local-build-key.gpg"
pacman-key --init
pacman-key --add "$work/local-build-key.gpg"
pacman-key --lsign-key "$fingerprint"
for package in "$local_repo"/*.pkg.tar.zst; do
    bsdtar -xOf "$package" .PKGINFO | grep -q '^pkgname = ' || die "invalid package: $package"
    gpg --homedir "$signing" --batch --yes --detach-sign "$package"
done
GNUPGHOME="$signing" repo-add --sign --key "$fingerprint" "$local_repo/nahj-build.db.tar.gz" "$local_repo"/*.pkg.tar.zst
mkarchiso -v -w "$work/mkarchiso" -o "$out" "$profile"
(
    cd "$out"
    sha256sum nahj-*.iso > SHA256SUMS
)
printf 'ISO and checksums: %s\n' "$out"
