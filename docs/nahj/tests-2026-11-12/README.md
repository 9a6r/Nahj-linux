# Checks before integration onto main

**Not release certified.** This report accompanies source/evidence publication,
not a new ISO release. No GitHub ISO workflow was dispatched.

## Passed

- [Native Hyprland configuration validation](hypr-config.txt) returned
  `config ok`. The actual Hyprland binary and dependencies were taken from ISO06,
  initialized in a disposable extracted root as UID 1000, and checked with the
  current reduced seed using `--verify-config`. This validates the real Lua/API
  loader, not graphical responsiveness. An initial help probe without
  XDG_RUNTIME_DIR failed; the valid invocation supplies a private runtime
  directory and the user home before running verification.
- [Three native installer account suites](accounts.txt) passed with the current
  `users.conf`; [eleven target preparation tests](target.txt) passed. These do
  not replace a full installation with package 3.3.14-5.
- [Thirteen service-policy assertions](services.txt) passed using ISO06's actual
  files and enablement links, including a simulated enable-only first boot.
- [Actual Plymouth decoder verification](boot-decoder.json) passed all 240 RGB24
  BMP frames at 1280×720. [Independent video comparison](boot-source.json) found
  132 intro and 84 loop frames pixel-identical to the supplied source, with 24
  frames matching the documented dissolve. Source remains 24 fps / 240 frames and
  SHA256 `7e62194861a2ce7f6c7e3fa56d66d4b26f827354d2fc3e656253f4dff7cdfa08`.
- [Source audit](original-source.json): 258 original entries remain exact, plus
  one intentional CI-only exception. All original shell and SDDM files remain
  unchanged. All 40 upstream pacman requirements and the original six themes'
  fonts are present; original helper executables were found in the image.

## Fresh UEFI live boot: scoped success, graphical failure remains

A new disposable QEMU q35/TCG VM used ISO06 with 4 vCPUs, 8 GiB RAM, a plain Virtio
GPU and a blank 40 GiB NVMe disk. It booted through the ISO's real UEFI loader
with its default kernel command line. The kernel was 7.2.11-zen1-1-zen, all six
original shell processes started, NetworkManager was enabled/active, and
networkd/resolved were disabled/inactive. The sampled system-unit failure list
was empty. The sampled kernel-error log contained only the host's unsupported
TDX capability message. See [boot evidence](uefi-boot.txt).

This is **not a passing desktop test**. After the prolonged unattended cloud
run, the monitor was inactive. A wake/DPMS diagnostic timed out waiting for
Hyprland IPC, and the captured output did not establish a working desktop.
The shell log reports a Luau handler exceeding 2 seconds, guest llvmpipe rendering,
a first frame after 949175 ms and a slow frame of 157978 ms. These are recorded
observations in TCG, not a controlled hardware performance benchmark. See
[the failure evidence](desktop-failure.txt). The VM was subsequently paused to
avoid continued background resource use. The previously recorded graphical
failures have not been explained or certified fixed.

ISO06 predates the reduced Hyprland seed. The native configuration validation
above applied that seed only to the disposable extracted root. No rebuilt ISO
with the latest appearance cleanup, complete installer-5 regression, native
hardware/VirtualBox graphics test or new boot-timing capture is claimed.
Historical native boot timing still includes a recorded gap above 84 ms; pixel
fidelity alone does not establish smooth playback.

## Publication policy

The user's main branch was an ancestor of the development branch; the changes
can be published by fast-forward without replacing its history. Existing
screenshots and their build-specific caveats accompany the source history.
The imported upstream add-on updater previously had a weekly scheduled job
that edits source and opens a PR. It is now manual-only in this fork. This is
the one original-file exception noted above; the add-on source and UI are not
changed. The ISO workflow remains manual-only, and PR add-on lint remains.
