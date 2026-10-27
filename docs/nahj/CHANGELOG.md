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
