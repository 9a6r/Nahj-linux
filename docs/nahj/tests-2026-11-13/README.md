# ISO09: completed local build and artifact checks

**Not release certified. No GitHub ISO workflow was dispatched.**

Built locally from `943607c58dc2211a99cdb55eb04cf54572674ca8`, which is published
on both `main` and `codex/nahj-archiso`. The image completed on November 12 UTC;
the extracted-image checks and new cold boot were performed on November 13.

- File: `nahj-2026.11.12-x86_64.iso`, 3,584,294,912 bytes.
- SHA256: `6d9afb542e979cca330ee29498a601f561cd941f830d1f8fa06351369e628e3b`.
- `sha256sum -c SHA256SUMS`: passed.
- Kernel package: `linux-zen 7.2.11.zen1-1`; no generic `linux` package.
- Installer package: `nahj-installer 3.3.14-5`.

## Build failures diagnosed before the successful image

ISO07 failed because a shared cached detached signature came from an expired
local build key. The [cache-order correction](../tests-2026-11-12/package-cache.md)
passed positive and negative pacman transaction checks, and the fresh ISO09
build completed with the corrected order and signature verification enabled.

ISO08 passed package verification but failed to generate its initramfs. The
restored cloud machine's devtmpfs lacked the standard `fd`, `stdin`, `stdout`
and `stderr` symlinks. Arch-install-scripts mounts that devtmpfs inside the
build root, so mkinitcpio's `install /dev/stdin` failed even though Docker's own
`/dev/stdin` existed. The same piped install was reproduced
[before](dev-stdin-before.txt) and passed [after](dev-stdin-after.txt) restoring
the missing links. The [setup script](restore-build-device-links.sh) records
the environment-only repair; it refuses to replace unexpected existing entries.
devtmpfs entries are shared by its mounts, so this is a cloud build-machine
repair, not an edit to the shipped desktop or a private filesystem simulation.

ISO09 used a fresh work directory after that repair. Its linux-zen initramfs,
squashfs and final ISO all completed. The [full build log](build.log) retains
mkinitcpio's optional-device firmware warnings. No failed initramfs or package
integrity check was suppressed. The ISO itself is retained in the cloud build
output, not committed as a multi-gigabyte Git object or published as a release.

## Checks against files extracted from the completed ISO

- [Source audit](source-audit.json): all 259 seeded entries match the current
  source. 258 match the original upstream baseline exactly; the only exception
  is the already documented CI-only add-on workflow schedule removal.
- All original shell sources and six installed greeter files match upstream.
- Current Hyprland seed, session wrapper, Vulkan helper and SDDM session
  configuration match the fixed source. SDDM exposes only the Nahj/Hyprland
  session. All 40 original pacman requirements are installed.
- The live account's stored password verifies as `nahj`; root stays locked.
- [All thirteen service assertions](service-presets.txt) pass after simulating
  first-boot enable-only presets using the image's actual units and links.
- [All 240 BMP frames](boot-decoder.json) decode correctly with the actual
  Plymouth library at 1280×720, with matching checksums and pixels.
- [Boot layout](boot-layout.txt) contains BIOS and UEFI El Torito entries and
  the Archiso hybrid removable-media layout. Layout inspection alone does not
  establish successful boot on every device or hypervisor.

## Cold boot and remaining validation

A fresh QEMU q35/TCG VM uses this exact ISO, OVMF UEFI, two virtual CPUs, 8 GiB
RAM, Virtio VGA at 1280×720 and a blank disposable 40 GiB NVMe disk. The default
entry reached the supplied-video Plymouth screen; its [actual capture](../../../screenshots/iso09-2026-11-13/)
is not a desktop screenshot or a frame-timing test. Escape was later pressed
only to inspect startup jobs. No guest files or boot arguments were changed.
The guest agent confirms kernel `7.2.11-zen1-1-zen` and UEFI. SDDM accepted the
live autologin and started the configured session. At the initial sample,
NetworkManager and SDDM were active, no system units were failed and package
keyring initialization was still in progress. The sampled kernel-error log
reported only unsupported host TDX. This early sample is not a clean-kernel
or complete-desktop certification.

Full graphical responsiveness, visual parity, zero-stutter end-to-end boot and
a complete installer -5 run remain unverified. This host has no KVM or DRM GPU;
the previous TCG graphics failures must not be treated as fixed merely because
this build and its artifact checks pass. The earlier isolated native Plymouth
[timing capture](../tests-2026-11-12/graphics-follow-up.md) is separate evidence.
