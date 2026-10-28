# Nahj development log

## 2026-10-27 — Arch live/install image foundation

Requested scope:

- Preserve the existing Vitreus shell, default glass appearance, and animation logic.
- Arch Linux, Wayland, Hyprland, with `linux-zen` as the initial kernel choice.
- A live ISO with a graphical installation option and VirtualBox support.
- Plymouth boot artwork derived from the supplied Nahj video: one glow sequence, then a moving background loop.
- GitHub Actions ISO builds, incremental Git history, and a separate `screenshots/` directory.

Implementation is kept under `distro/` and `.github/workflows/`, with documentation here. Existing application source is preserved. UwU stays available because its cat effects share shell logic; removing those effects is outside the preservation requirement. Glass remains the default.

Initial evidence:

- Existing checkout: `f8a930e5008c98a04eedf195a27476e272712da2`.
- Source video: 1280 × 720, 24 fps, about 10 seconds.
- Read-only Git access and push dry-run succeeded.
- Cloud host is Debian 13; Arch build tools will run in an official Arch Linux container.
- Docker is available. This machine exposes no `/dev/kvm` or `/dev/dri`; hardware-accelerated VM/desktop claims require separate testing.

Build and validation results are recorded below as they are completed. A configured workflow is not evidence that an ISO built or booted.

## 2026-10-28 — Recovered implementation and first build submission

- Added Archiso overlay, linux-zen boot configuration, preserved Vitreus SDDM theme, live session, and Calamares packaging.
- Added pinned runtime/font/desktop source downloads with checksums and an Arch builder container.
- Generated the supplied-video splash: 132 intro frames followed by a 108-frame glow-free loop; preview artifacts are in `screenshots/boot/`.
- Four installer target-cleanup tests passed. Bash and Python syntax checks passed.
- Cloud container build initially failed on mirror DNS routing; retry uses the environment proxy and trusted CA. No TLS or package-signature verification is disabled.
- Added GitHub Actions build with ISO/checksum artifacts and retained failure logs. A submitted build is not a boot validation.
- Outstanding: complete compilation and ISO build, then actual BIOS/UEFI/live/installed and VirtualBox visual checks. Fast boot currently can finish Plymouth before the intro completes; this needs integration review.

Additional validation:

- Verified all 240 generated PNG checksums and phase counts.
- Verified all 14 pinned desktop source/font archive checksums.
- Validated installer module configurations against the pinned Calamares schemas; YAML parsing passed.
- Git comparison confirms no original shell files were modified.
- Commits `f9b4c89` and `b86f805` were pushed. GitHub run https://github.com/9a6r/Nahj-linux/actions/runs/40607837434 was observed in progress; result not yet verified.
- Cloud build proxy DNS was resolved through Docker's explicit host mapping; the remaining failure is an actual `CONNECT 403` for geo.mirror.pkgbuild.com. GitHub API is likewise blocked in the current instance, although Git push and the public Actions page work. The necessary two domains are saved in the environment draft and await runtime activation.
- No ISO boot, real desktop screenshot, or hardware install has yet been verified. Do not treat this branch as a tested release.

## 2026-10-28 — Image and installer correctness review

Confirmed and fixed:

- SDDM's configured X11 greeter needed `xorg-server`; added it. The desktop session remains Hyprland/Wayland.
- Archiso's actual overlay copy uses `--no-preserve=mode`, dropping execute bits on added runtimes and shell helpers. The generated profile now records those executable permissions explicitly. Reproduced the copy behavior and verified a copied program runs after applying the generated permissions.
- Archiso removes `/boot` contents from the squashfs. The installer now restores `vmlinuz-linux-zen` from the installed kernel's module directory before initramfs/GRUB setup; missing or ambiguous kernels fail the installation step. Added regression tests.
- Original SDDM assets now use Space Grotesk from the image payload, with an explicit missing-font failure instead of a silent builder-font substitution. Generated the actual original login backgrounds and verified three font weights and 1920×1080 backgrounds.
- Builder failures now retain `toolchain.log` in the workflow evidence artifact.

Validation: six target-installer tests passed; Calamares module schemas, shell syntax and whitespace checks passed. Existing shell/application source remains unchanged. Full compilation, real live/installed boot and VirtualBox performance remain unverified; the cloud still blocks the configured Arch mirror and GitHub API with CONNECT 403.
