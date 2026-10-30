# Local validation — 30 October 2026

Status: **not ready for release**. GitHub ISO builds remain manual-only and no
new workflow was dispatched. The builder runs Arch in Docker; the host exposes
neither KVM nor a physical GPU. QEMU TCG and software graphics cannot certify
VirtualBox performance.

## Confirmed checks

- All 259 files in upstream Vitreus `92cd90b0b3ff8bf88831b12f176051450da4a98a`
  still match the imported source byte-for-byte, including its symlink.
- All 21 original scenes pass `pleamar --check` with the patched runtime.
- The extra system-monitor ring is reproduced with the original scene and is
  absent with the explicitly selected patched executable. An earlier launch
  selected an old executable through the test compositor's PATH; its still-bad
  screenshot was rejected. GPU-present coverage remains incomplete: the
  test-only headless compositor hit an OpenGL adapter-context panic in that run.
- The six original theme selections persist in `iris.json`. Every key in each
  fixed theme palette matches the original TOML exactly; Glass generated its
  palette from the test wallpaper. Saved values are in `theme-palettes.json`.
  This does not prove persistence across restarting the complete session.
- All six original theme fonts are now checked by inspecting the actual packaged
  font name tables. The newly required Proxy font, Titan One, and its OFL license
  were missing from packaging and were added from the pinned Google Fonts commit.
- Desktop assets rebuild successfully into an existing payload after fixing
  Iris wheel installation to use a fresh staging directory before copying.
- All nine installer target tests pass. Calamares 3.3.14-2 builds locally and
  passes its configuration-schema and required-plugin checks.
- All 240 optimized boot frames decode to exactly the same RGB pixels as the
  previous generated animation. The intro/loop counts remain 132/108 at 24 fps.
  Native-size resize avoidance and lossless uncompressed PNG storage reduce
  per-frame work. A zstd-3 theme archive measured 303 MiB before, 227 MiB after;
  on-disk uncompressed theme storage grows to 633 MiB. The current frame alone is
  decoded, not the whole sequence preloaded into RAM.
- ShellCheck passes for the ISO composer, desktop-assets builder, session
  launcher and wallpaper helper. The explicit Wayland flag array fixed SC2046.

## Runtime observations and limitations

The original `dev/health` completed three panel/settings cycles and 30 seconds
idle: **0 failed, 2 warnings**. Open files, threads and children were stable.
Memory rose by 9.1 MiB from round 2 to 3 and needs a longer plateau test; idle
growth was 0.35 MiB/min. The other warning is the software renderer's Vulkan-to-GL
fallback. See `upstream-health.txt`. Its first run aborted because the original
shell rewrote its two-monitor layout for one monitor and restarted, invalidating
the health tool's stored PID. The second diagnostic copy used `screens: each max
1`, the same value the original controller had generated; repository source was
unchanged. Headless tests lack real audio, Bluetooth and compositor services.

Software rendering produced multi-second frames and delayed screenshots. Palette
files passing assertions is not proof of responsive rendering. The native images
are named by visual inspection; the first automated naming was ahead of the
displayed state and was not used as theme proof.

The ISO from run 40828123809 was booted with QEMU TCG and virtio-vga. Manually
typing `nahj` at the original SDDM screen authenticated successfully and started
`/usr/local/bin/nahj-session`, with Hyprland still running and kernel
`7.2.11-zen1-1-zen`. The subsequent screen is Vitreus's idle lock screen. This
does **not** reproduce or resolve the user's unknown VirtualBox ISO login loop.
The old ISO had a `plymouth-quit.service` timeout under TCG; the optimized boot
payload still needs an ISO-level retest. The new private SDDM SessionDir also
needs a complete login test in the newly composed image.

Outstanding release gates: current local ISO build/boot, VirtualBox login and
3D graphics, GPU-present ring regression, full wallpaper-picker transitions,
theme font Apply and session restart, sustained memory/performance testing,
and an end-to-end install and boot of the installed system. No claim of complete
hardware compatibility or absence of crashes is made.
