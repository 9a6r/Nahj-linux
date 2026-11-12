# Follow-up: isolate emulation cost and fix inconclusive Vulkan detection

## Concrete login-path correction

`nahj-session` previously discarded a failed/timed-out `vulkaninfo` status and
selected the portable presentation path only for a nonempty CPU-only result.
Empty successful output, an outright failure or partial hardware output followed
by failure therefore left the normal DMA-BUF presentation path enabled without
establishing that hardware rendering was available. The original timeout also
had no kill-after bound when the probe ignored SIGTERM.

Moved this selection into the sourced `nahj-vulkan-env` helper. An incomplete,
failed, empty or CPU-only probe selects Pleamar's existing swapchain path. A
successful hardware or mixed-device probe retains the normal path. An explicitly
set user variable is preserved and bypasses the probe. The real timeout now
sends SIGKILL two seconds after an ignored 15-second termination deadline.
This changes presentation selection, not the Vulkan driver, source scenes,
colors, layout or animations. It does not supply a missing Vulkan driver or
make CPU emulation equivalent to accelerated hardware.

Three cases reproduce against the old wrapper ([expected failures](vulkan-probe-before.txt)).
All eight regression tests pass after the fix, including the real 17-second
hung-process test ([results](vulkan-probe-after.txt)). The helper was also run
against the actual Vulkan tools/libraries in an extracted ISO root
([CPU result](vulkan-probe-actual-iso.txt)). Bash syntax, ShellCheck and fresh
profile composition passed; the generated profile contains the helper. The
manual ISO workflow includes the regression test before building the image.

This is **not the cause of the latest slow TCG run**: that VM's Hyprland already
had `PLEAMAR_SWAPCHAIN=1` ([observed environment](existing-vm-presentation.txt)).
The new correction handles a separate real failure path and must not be
reported as resolving all login failures or the measured TCG slowness.

## Native versus emulated rendering

The cloud machine exposes neither KVM nor a DRM rendering device. Native
Hyprland could parse the configuration but could not create its display backend
without a usable graphics device/compositor. The original upstream `dev/rig`
was therefore used solely as a separate diagnostic in the extracted ISO root.
The original main scene responded and produced its first frame after 15705ms;
the TCG run reported 949175ms. They use different compositors/resolutions and
are not a controlled speedup benchmark. The difference supports investigating
emulation cost; it does not prove native Hyprland or VirtualBox correctness.
The [actual diagnostic capture](../../../screenshots/native-diagnostic-2026-11-12/)
is explicitly not a booted-ISO or complete-desktop screenshot.

The upstream Pleamar repository was inspected for rendering fixes; no wholesale
runtime update or unverified GPU error suppression was applied. In particular,
the reported `600ms` demo stall is not evidence that every Luau handler is
artificially delayed: the relevant code applies it to legacy layer events.

## New native Plymouth timing capture

With QEMU paused and the headless rig finished, the unchanged BMP theme was
run through actual Plymouth on a dedicated 1280×720 Xvfb display and captured
at 60 Hz for 16 seconds. Source pixels were matched by hashes, not by an estimated
FPS counter. [Timing data](boot-timing-isolated.json) and
[raw capture hashes](boot-timing-capture.md5) are retained.

- 960 capture samples; maximum sampling interval 16.67 ms.
- 364 displayed image changes matched the exact intro-once/loop sequence.
- No skipped or reordered image was detected in that captured interval.
- Mean interval 41.60 ms (24 fps targets 41.67 ms); maximum 66.67 ms.
- Zero intervals exceeded 84 ms in this run.

This is better than the prior native capture, without changing the theme or
reducing its source resolution, colors or frame rate. It remains a short X11
renderer test, not end-to-end boot timing, guaranteed zero jitter, or physical
hardware/VirtualBox certification. The existing ISO predates the new probe fix;
no new release or GitHub ISO workflow run is claimed.
