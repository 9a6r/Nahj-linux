# Resumed local ISO validation

**Release blocked: smooth boot and VirtualBox login are not certified.** No
GitHub Actions build was dispatched. All tests below ran locally.

## Image built successfully

- Source: `11984ec` on `codex/nahj-archiso`.
- ISO: `nahj-2026.10.30-x86_64.iso`, 3,423,879,168 bytes. Its filename and
  ISO timestamp retain the original build epoch, although composition completed
  on 4 November UTC.
- SHA-256: `c15c1c5a5bb02c01896299d74ec625cbd9907c46488a9f390748f3398251d628`.
- BIOS and UEFI boot images were generated successfully. This alone does not
  establish runtime UEFI support.
- The signed, cached official Arch repository and packages were used because
  HTTPS downloads from inside the build container timed out. Official package
  signature checking remained enabled. Only our expired local build key was
  renewed and its local packages/repository re-signed.
- Container devtmpfs lacked `/dev/stdin`, `/dev/stdout`, `/dev/stderr` and
  `/dev/fd` in arch-chroot. Restoring those standard symlinks in the disposable
  chroot allowed mkinitcpio to finish. The 409 MiB initramfs and final squashfs
  built successfully. No signature, integrity or initramfs failure was ignored.

## Checks repeated

- All 259 tracked upstream files match Vitreus
  `92cd90b0b3ff8bf88831b12f176051450da4a98a`, including symlink contents.
- Nine installer target tests pass.
- ShellCheck passes for the ISO composer, asset builder, session launcher and
  wallpaper helper.
- The current ISO boots its custom Plymouth animation through BIOS in QEMU
  TCG with 2 virtual CPUs, 6 GiB RAM and virtio-vga, at 1280×720. The two
  linked images are actual screenshots of this ISO, not rendered previews.
- During startup, the text console exposed a long `ldconfig.service` job
  (over two minutes under TCG). Its cause and impact remain under investigation.

## Animation timing is not yet a pass

The native X11 diagnostic uses the final packaged frames and Plymouth script.
The VM was paused while recording. Of 960 expected 60 Hz capture samples,
952 were recorded. Distinct matched image changes averaged 46.49 ms, with a
maximum observed gap of 166.67 ms and six gaps above 84 ms. The recorder itself
had a 100 ms sample gap, so these values cannot all be attributed to Plymouth.
See `boot-x11-capture.json`. Image hashes with two names are intentional:
`intro-131` and `loop-107` have identical pixels; this is not a repeated glow.

A separate diagnostic interposed only `fopen64` to timestamp frame loads,
without recording the screen. Its median interval was 41.71 ms (target 41.67),
but maximum interval was 1245.96 ms. This measures frame-load requests, not
completed scanout. Both results still contain scheduling stalls; neither
establishes smooth real-machine or VirtualBox playback. The diagnostic C file
is evidence only and is **not included in the ISO**.

Rejected experiments remain outside the shipped payload: preloading every
frame delayed first display by about ten seconds; disabling PNG filters did
not establish a worthwhile improvement. Final frames remain lossless and the
original UI files remain unchanged.

Current screenshots: [ISO boot captures](../../../screenshots/iso-local-2026-11-05/).
The previous [runtime review](../tests-2026-10-30/README.md) documents theme
palette checks and limitations. Current-image desktop/login, wallpaper
transitions, installed-system boot and actual VirtualBox remain release gates.
