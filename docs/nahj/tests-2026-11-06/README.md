# Installed-system login and BIOS follow-up

**Not release certified.** No GitHub Actions build was dispatched.

## Installed NVMe system

The UEFI VM was powered down fully, its ISO disconnected, and the installed
NVMe disk booted through its own GRUB. The installed custom Plymouth theme
displayed. `findmnt /` reports `/dev/nvme0n1p2 ext4`, and `uname -r` reports
`7.2.11-zen1-1-zen`. No system units were failed at the initial check.

In the original Vitreus SDDM greeter, the public live password `nahj` was
rejected by PAM. The newly chosen password was then accepted. SDDM reported
successful authentication, session creation and a successful greeter exit;
Hyprland PID 1101 and all six original Pleamar scene processes started.
[Authentication evidence](installed-login.txt) omits only the lengthy stock
Arch live MOTD. This is an actual installed-system login, not just a hash test.

The VM remains QEMU TCG with VirGL backed by host software rendering. The shell
takes a long time to render; process startup does not establish visual parity
or responsiveness. Real hardware, actual VirtualBox, full theme/wallpaper
transitions and uninterrupted boot animation remain open release gates.
The earlier UEFI panic is not explained by this successful installed boot.

## BIOS and SATA

ISO 05 booted through its actual Syslinux BIOS loader and detected a 40 GiB
SATA disk as `/dev/sda`. `/sys/firmware/efi` was absent. This diagnostic appended
`systemd.unit=multi-user.target console=ttyS0,115200`; it is a boot/storage test,
not a default graphical-session or completed BIOS installation test.
Plymouth quit completed successfully and no system units were failed.

## Service-policy regression caught by the real boot

The BIOS guest still reported networkd/resolved as enabled. Existing releng
D-Bus aliases (`dbus-org.freedesktop.network1.service` and
`dbus-org.freedesktop.resolve1.service`) survived the old cleanup. networkd was
inactive, but resolved was active. Presets applied in enable-only mode do not
remove these aliases. The earlier test incorrectly began with an empty
`etc/systemd/system`, so its passing result did not cover this state.

The image setup now applies the full preset policy to the named desktop and
network services during composition. The test now copies the image's actual
enablement directory, including aliases, and checks that its packaged preset
matches the current source. A fixture extracted from the running ISO 05 guest
reproduced the failure; applying the same full policy removed both stale
aliases and all thirteen assertions passed after a simulated first boot.
See [before](preset-regression-before.txt), [after](preset-regression-after.txt)
and [BIOS observations](bios-before-service-fix.txt). A fresh image/cold boot
with this final correction is still required.

## Installer package

Installer 3.3.14-5 built successfully, including eleven target tests and the
three native account suites. SHA-256:
`2401ce6d0c4370ae93e4c05201c9eea01020a47dd4c3b98ee5e4b1ffb38be204`.
It includes the password, partition-label contrast and target GPG cleanup
fixes. The installed-system test above used installer 3.3.14-3 followed by the
documented manual daemon cleanup; it is not a full-install regression of -5.

[Actual installed-system captures](../../../screenshots/installed-2026-11-06/)
and [preceding installation evidence](../tests-2026-11-05/README.md).
