# Nahj Arch image

This directory packages the existing shell as an Arch Linux live/install image. The shell's application files and default glass theme remain unchanged.

The intended stack is Wayland + Hyprland + Vitreus/pleamar, `linux-zen`, the existing Vitreus SDDM login theme, and a Nahj Plymouth boot animation generated from the supplied video. Calamares provides the optional graphical installer. Launching the live image must not install to or format a disk.

Development decisions and validation evidence: [development log](../docs/nahj/CHANGELOG.md). Visual evidence is kept separately in [screenshots](../screenshots/README.md).

VirtualBox must use VMSVGA with 3D acceleration, sufficient graphics memory and RAM. Software rendering is a fallback, not a guarantee of native animation performance. Full visual parity and hardware behavior must be checked on the target machine.

Build and test instructions will accompany the implemented scripts. Do not execute host disk-partitioning commands to test an installer configuration.

## Build

The `Build Nahj ISO` GitHub Actions workflow runs on pushes to `main` or `codex/nahj-archiso` affecting image files, and supports manual dispatch once present on the default branch. Successful runs upload an ISO with SHA256SUMS; failure logs are uploaded separately. Artifacts expire after seven days. Builds use rolling Arch packages, with pinned application source archives; they are not bit-for-bit reproducible snapshots.

For a local build on a Docker-capable Linux machine, follow the exact container invocations in `.github/workflows/iso.yml`. Use a dedicated output directory outside this checkout. The ISO stage needs a privileged container for Archiso mounts; the runtime and installer compile as an unprivileged user. Do not run the ISO stage against an installed desktop root.

The live account is `nahj`, with the public live password `nahj`. Calamares removes that account and its passwordless sudo/autologin configuration from the installed target before creating the chosen user.

Current validation status is recorded in the development log. No hardware or VirtualBox performance guarantee is made by a successful image build alone.
