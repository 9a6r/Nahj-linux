# Runtime review — 30 October 2026

These are actual captures, not mockups. They are diagnostic evidence, **not a
release approval or proof of smooth VirtualBox operation**.

| Capture | Environment and meaning |
| --- | --- |
| `iso-sddm.png` | Actual ISO from GitHub run 40828123809, QEMU TCG, 1280×720. Autologin was disabled in this disposable guest to test the password. |
| `iso-lockscreen-after-login.png` | The same ISO after manually entering `nahj` at SDDM. Authentication succeeded, Hyprland remained running, and the original idle lock screen appeared later. This is the in-session lock screen, not a return to SDDM. |
| `sysmon-before.png` | Original system-monitor scene in upstream's native headless test compositor, before the runtime fix. No hardware GPU is available; the extra empty ring should be hidden. |
| `sysmon-after.png` | The same original scene with the patched Pleamar executable explicitly selected. The extra ring is absent. Black background is the test compositor's background. |
| `retro-settings-native.png` | Original Retro theme and Settings panel in the native test compositor. No wallpaper daemon was running at capture time. |
| `milkbox-settings-native.png` | Original Milkbox theme, Settings panel, and one of the test wallpapers. |
| `proxy-frame-native.png` | Original Proxy colors on the left bar and frame, with the test wallpaper. |

The native captures are **not ISO desktop screenshots**. The headless compositor
does not reproduce Hyprland's blur and monitor services. Rendering was very slow
on this CPU-only host, so screenshots were visually checked and named by the
theme actually visible, rather than the last requested theme. Theme font Apply
and restart were not exercised; the preview typefaces and packaged font files
were checked separately. These images do not certify animation timing.

ISO SHA-256: `a3cfd433bf208782235552e88994f7d0bf63adb4769e0e88e6918f23bad01e63`.
The ISO predates the latest upstream merge and today's packaging corrections.
See [test results](../../docs/nahj/tests-2026-10-30/README.md).
