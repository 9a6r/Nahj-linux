# Consolidated verification — November 20, 2026

**Release readiness, complete desktop rendering and original-video smoothness at 1080p remain unverified.** This update publishes retained checks and measurements; it does not ship a runtime fix or a new ISO.

## Build identity and scope

The remote repository already contained six newer commits through `f4caa52` when this evidence was prepared for publication. Those commits were fast-forwarded into the working checkout and preserved. The newest documented build is [ISO09](../tests-2026-11-13/README.md), built from `943607c`, SHA256 `6d9afb542e979cca330ee29498a601f561cd941f830d1f8fa06351369e628e3b`. Its graphical readiness check failed: wallpaper appeared, but the main shell and its IPC were still absent after prolonged startup.

The November 14 guest checks below instead used **ISO06**, built from `7138882`, file `nahj-2026.11.06-x86_64.iso`, SHA256 `309d19d3b862d793ab33f4571ea138fc98ad361047b0c5f1e557016427e0e437`. That image predates the November 11 removal of distribution compositor styling and the newer session probe fixes. These results are not a fresh ISO09 regression pass.

The November 20 native animation tests use the ISO06 theme. All 242 theme frame/script/manifest files used by the native test were compared with the freshly extracted ISO06 contents. This is isolated native Plymouth testing, not timing a full boot inside QEMU or on physical hardware. The 1080p output directory was prepared on November 15; the recorded trials ran on November 20.

## Original source preservation

The retained pre-publication checkout and extracted ISO06 each matched all 259 baseline entries at `92cd90b0b3ff8bf88831b12f176051450da4a98a`; all 21 original scenes compiled with the extracted runtime. The synchronized publication checkout preserves 258 entries exactly, with one existing CI-only exception: `.github/workflows/addons-bump.yml` no longer schedules automatic updates. **All original desktop-shell and SDDM UI files remain unchanged.** See `publication-source-audit.json` for the final checkout audit and `evidence/iso06/` for the older image checks.

## Boot pixels and timing

The supplied video is unchanged: SHA256 `7e62194861a2ce7f6c7e3fa56d66d4b26f827354d2fc3e656253f4dff7cdfa08`, 1280×720, 24 fps, 240 frames. All 240 BMP frames passed the real Plymouth decoder and the source-pixel comparison: 216 exact source frames and 24 frames with the documented loop crossfade. The intro contains 132 frames (5.5 seconds at 24 fps), followed by a 108-frame loop. Pixel correctness does not establish timing correctness.

Three 20-second captures per resolution sampled the actual Plymouth display at 60 Hz. Frame hashes were matched against the real decoder; 1080p references used Plymouth's own resize function.

| Resolution / trial | Observed frame changes per second | Largest interval | Intro duration |
| --- | ---: | ---: | ---: |
| 720p / 1 | 23.99 | 66.67 ms | 5.48 s |
| 720p / 2 | 24.00 | 83.33 ms | 5.52 s |
| 720p / 3 | 23.92 | 66.67 ms | 5.52 s |
| 1080p / 1 | 11.89 | 133.33 ms | 11.08 s |
| 1080p / 2 | 12.43 | 116.67 ms | 10.73 s |
| 1080p / 3 | 12.20 | 133.33 ms | 10.57 s |

The third 720p capture did not observe one sequence frame (`loop-54`); it does not establish whether that frame was never displayed or missed by sampling. The second 1080p capture contains 1,198 of 1,200 expected samples, with a 50 ms maximum capture gap; the others contain all 1,200 samples. No sequence frames were missing in the matched 1080p runs: playback progressed slowly rather than keeping the 24 fps source duration. The 60 Hz sampling rate also quantizes display intervals.

A separate 16-second diagnostic counted frame-load requests with **no screen recorder**:

| Resolution | Requests | Mean request interval | Requests per second |
| --- | ---: | ---: | ---: |
| 1280×720 | 385 | 41.71 ms | 23.98 |
| 1920×1080 | 214 | 76.72 ms | 13.03 |

These are load requests, not completed display scanout. They show that the measured 1080p slowdown is not solely recorder overhead. Scratch `LD_PRELOAD` instrumentation was used only in this diagnostic and is not shipped. The 1080p path performs runtime scaling, but the measurements do not isolate every cause of the slowdown.

## Installer, services and real guest checks

The retained November 14 checks passed all 11 installer target tests, all 13 service-policy assertions against the fresh ISO06 extraction, and ShellCheck for the tested integration helpers. The actual users-module password-policy suite passed 57 tests with no skips. The hostname suite could not exercise the real hostnamed D-Bus service in the container: the root run failed there, while an unprivileged run handled that unavailable service as expected. This is not a passing hostname integration test.

The fresh ISO06 UEFI/TCG guest used four vCPUs, 6 GiB RAM and Virtio VGA at 1280×720, without KVM or a DRM GPU. At sampled points it reached `running` with no failed system/user units or recorded coredumps. SDDM, NetworkManager and Hyprland were running; competing networkd/resolved units stayed disabled. Plymouth quit and the wallpaper helper succeeded. These are sampled service results, not graphical readiness.

The guest desktop remained incomplete and main-scene IPC stopped responding. After a later resume, Hyprland displayed that the lockscreen application had died. The retained diagnostic screenshot is archived with this report, rather than used in the product gallery. Its cause remains unresolved: the screenshot alone cannot distinguish runtime, driver, scheduling or resume effects. No lockscreen fix is claimed.

## Isolated shell health check

The original `dev/health` ran four panel cycles followed by 60 seconds idle on two simulated 1920×1080 monitors. Its report returned **0 failures, 1 warning and 5 successful checks**. RSS settled around 1,323 MB; growth over rounds 2–4 was 0.4 MB/round, idle growth 0.01 MB/minute, and initial/final descriptors, threads and child processes were 32, 54 and 2. The warning was a Vulkan-to-OpenGL software-rendering fallback. The log also recorded 1,847 slow frames, worst 3,890 ms. This is a limited resource-stability result, not a smoothness or visual-parity pass; a separate direct panel query also timed out.

The health command itself exited 1 with that warning; its zero-failure summary must not be reported as an exit-0 pass. An earlier run was invalid for panel interaction: a disposable test-rig font symlink pointed to a missing directory, so panel commands exited before reaching IPC. Only that disposable symlink was repaired, to the existing packaged fonts. The original health script, rig script and shell sources were not edited. The corrected run above supersedes that earlier interaction result.

## Evidence and reproduction limits

- `evidence/native/720p/` and `1080p/`: raw frame hashes and decoded frame runs for all six November 20 trials.
- `evidence/native/boot-comparison.json`: frame sequence and intro-duration comparison.
- `evidence/native/without-recorder/`: raw request timestamps, results and diagnostic source.
- `evidence/health/`: corrected report and font-fixture diagnosis.
- `evidence/iso06/`: checksum, source/scene checks, frame provenance, installer/service/account results and retained guest logs.
- `evidence/verification-summary-before-publication.json`: original test-session summary. Its “no tracked changes” and 259-entry statements describe the older checkout before this publication, not the synchronized repository.
- `evidence/manifest.json`: SHA256 and byte count of every archived evidence file.

Diagnostic scripts retain their original `/build` paths and expect the disposable Arch build container, Plymouth, Xvfb, FFmpeg, Pillow and extracted assets. They are an audit record, not a general installer or a command to run on an active desktop. VM disks, package caches, generated shared libraries and multi-gigabyte ISO/squashfs files are not Git source artifacts. No GitHub ISO workflow was dispatched.

[Login and original-reference gallery](../../../screenshots/README.md). Rejected old diagnostic desktop captures and their gallery references were removed from the current repository files at the user's request; no original UI source was removed.
