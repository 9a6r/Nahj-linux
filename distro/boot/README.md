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

Frames retain the original 1280×720 resolution and full RGB color. Generated PNGs are build outputs, not committed files. They increase initramfs size; the theme decodes one frame at a time to avoid preloading the entire sequence into RAM. Frame rate is a target, and slow software rendering can reduce it.

PNGs now store lossless filtered RGB without inner DEFLATE compression; the
initramfs and squashfs provide compression around them. This avoids repeating
that decompression for every displayed frame. Native-size output also skips
Plymouth's software resize. All 240 regenerated frames were checked against the
previous frames byte-for-byte after RGB decoding: no pixel changed. In a local
1280×720 X11 test under concurrent load, captured distinct frames increased
from about 5.5/s to 18.7/s. This is diagnostic evidence, not a VirtualBox timing
guarantee. A zstd level-3 theme archive decreased from 303 MiB to 227 MiB;
uncompressed theme storage increased from 303 MiB to 633 MiB.

The Plymouth script uses a one-way `intro` → `loop` state transition. Password and text prompts are still displayed. Boot completion is never delayed to finish the intro, so a sufficiently fast boot can exit the splash before its glow completes. Plymouth's text fallback remains available if graphics cannot initialize.

`screenshots/boot/` contains rendered preview evidence, not a screenshot of a booted ISO. The installer uses its own separate SVG artwork. An actual ISO boot remains a separate integration check.
