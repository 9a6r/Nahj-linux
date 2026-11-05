# Nahj Arch image

This directory packages the existing shell as an Arch Linux live/install image. The shell's application files and default glass theme remain unchanged.

The intended stack is Wayland + Hyprland + Vitreus/pleamar, `linux-zen`, the existing Vitreus SDDM login theme, and a Nahj Plymouth boot animation generated from the supplied video. Calamares provides the optional graphical installer. Launching the live image must not install to or format a disk.

Development decisions and validation evidence: [development log](../docs/nahj/CHANGELOG.md). Visual evidence is kept separately in [screenshots](../screenshots/README.md).

VirtualBox must use VMSVGA with 3D acceleration, sufficient graphics memory and RAM. Software rendering is a fallback, not a guarantee of native animation performance. Full visual parity and hardware behavior must be checked on the target machine.

Installer integration tests use disposable virtual disks. Do not execute disk-partitioning tests against a host disk.

## Build

The `Build Nahj ISO` GitHub Actions workflow is **manual-only**. Pushing source does not start an ISO build. Do not dispatch it until local release validation passes. Successful runs upload an ISO with SHA256SUMS; failure logs are uploaded separately. Artifacts expire after seven days. Builds use rolling Arch packages, with pinned application source archives; they are not bit-for-bit reproducible snapshots.

For a local build on a Docker-capable Linux machine, follow the exact container invocations in `.github/workflows/iso.yml`. Use a dedicated output directory outside this checkout. The ISO stage needs a privileged container for Archiso mounts; the runtime and installer compile as an unprivileged user. Do not run the ISO stage against an installed desktop root.

The live account is `nahj`, with the public live password `nahj`. Calamares removes that account and its passwordless sudo/autologin configuration from the installed target before creating the chosen user.

The installed account uses the password chosen during setup, with 8–128 characters and matching confirmation. Empty passwords are rejected because the original Vitreus greeter does not submit them. The length ceiling keeps UTF-8 passwords within the hashing library's limit. Failed password hashing is an installation error, not a successful account setup. The live password remains `nahj`.

For local offline builds, `distro/build-iso.sh --mirror-url file:///absolute/mirror/path` uses a prepared Arch mirror with its signed packages. The normal default is the official HTTPS mirror; signature verification remains enabled in either mode.

Current validation status is recorded in the development log. No hardware or VirtualBox performance guarantee is made by a successful image build alone.
