# Nahj boot animation

The source is the video supplied for this project, kept intact in `source/nahj.mp4` with SHA-256 `7e62194861a2ce7f6c7e3fa56d66d4b26f827354d2fc3e656253f4dff7cdfa08`.

The original video already contains the requested feather sweep from right to left, then the full glow. The generator uses it once, then repeats only the settled background. It does not change the artwork or the desktop theme.

```sh
python3 distro/boot/generate.py \
  --output /tmp/nahj-payload/usr/share/plymouth/themes/nahj \
  --preview-dir /tmp/nahj-boot-preview
```

Dependencies: Python 3.11+, Pillow, and FFmpeg with PNG and libx264 support. The source checkout may be read-only. Existing output is replaced only when it carries this generator's marker. Source checksum verification stays enabled.

At 24 fps, the intro has 132 frames (5.5 seconds). The loop has 108 frames (4.5 seconds): source frames 132–215 followed by a smooth one-second dissolve from frames 216–239 into settled frames 108–131. Its next frame is source frame 132 again, so the wrap continues forward without restarting the glow or reversing the water. The overlap hides the source video's cut; it is a crossfade, not new simulated water motion.

Frames retain the original 1280×720 resolution and full RGB color. Generated BMPs are build outputs, not committed files. They increase initramfs size; the theme decodes one frame at a time to avoid preloading the entire sequence into RAM. Frame rate is a target, and slow software rendering can reduce it.

The theme now uses Plymouth's native 24-bit BMP reader. This avoids PNG filter
reconstruction on every frame without changing a pixel. A three-pass comparison
of all 240 frames through the installed Plymouth library found identical ARGB
pixels. Median image-load time in that local diagnostic decreased from 15.55 ms
to 5.09 ms. A 16-second native X11 capture averaged 42.03 ms between distinct
frames (24 fps targets 41.67 ms), but still recorded one gap above 84 ms. This
is an improvement, not certification of zero stalls on real hardware.

The tradeoff is compressed size: a zstd-3 theme archive is about 326 MiB, versus
227 MiB for the previous filtered PNG frames. Both unpack to about 633 MiB; only
the displayed frame is decoded. Whole-sequence preloading was rejected because
it delayed the first image by about ten seconds in the test environment.

After generation, verify that the actual Plymouth library can decode every
frame with exactly the expected pixels (requires Plymouth and Pillow):

```sh
python3 distro/boot/check_frames.py /tmp/nahj-payload/usr/share/plymouth/themes/nahj
```

The manual ISO workflow runs this check before composing an image. Native timing
and pixel comparisons are diagnostic checks; the rebuilt ISO and installed
system still require runtime validation.

The Plymouth script uses a one-way `intro` → `loop` state transition. Password and text prompts are still displayed. Boot completion is never delayed to finish the intro, so a sufficiently fast boot can exit the splash before its glow completes. Plymouth's text fallback remains available if graphics cannot initialize.

`screenshots/boot/` contains rendered preview evidence, not a screenshot of a booted ISO. The installer uses its own separate SVG artwork. An actual ISO boot remains a separate integration check.
