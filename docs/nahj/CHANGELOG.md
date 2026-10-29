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

## 2026-10-28 — Recovered implementation and first build submission

- Added Archiso overlay, linux-zen boot configuration, preserved Vitreus SDDM theme, live session, and Calamares packaging.
- Added pinned runtime/font/desktop source downloads with checksums and an Arch builder container.
- Generated the supplied-video splash: 132 intro frames followed by a 108-frame glow-free loop; preview artifacts are in `screenshots/boot/`.
- Four installer target-cleanup tests passed. Bash and Python syntax checks passed.
- Cloud container build initially failed on mirror DNS routing; retry uses the environment proxy and trusted CA. No TLS or package-signature verification is disabled.
- Added GitHub Actions build with ISO/checksum artifacts and retained failure logs. A submitted build is not a boot validation.
- Outstanding: complete compilation and ISO build, then actual BIOS/UEFI/live/installed and VirtualBox visual checks. Fast boot currently can finish Plymouth before the intro completes; this needs integration review.

Additional validation:

- Verified all 240 generated PNG checksums and phase counts.
- Verified all 14 pinned desktop source/font archive checksums.
- Validated installer module configurations against the pinned Calamares schemas; YAML parsing passed.
- Git comparison confirms no original shell files were modified.
- Commits `f9b4c89` and `b86f805` were pushed. GitHub run https://github.com/9a6r/Nahj-linux/actions/runs/40607837434 was observed in progress; result not yet verified.
- Cloud build proxy DNS was resolved through Docker's explicit host mapping; the remaining failure is an actual `CONNECT 403` for geo.mirror.pkgbuild.com. GitHub API is likewise blocked in the current instance, although Git push and the public Actions page work. The necessary two domains are saved in the environment draft and await runtime activation.
- No ISO boot, real desktop screenshot, or hardware install has yet been verified. Do not treat this branch as a tested release.

## 2026-10-28 — Image and installer correctness review

Confirmed and fixed:

- SDDM's configured X11 greeter needed `xorg-server`; added it. The desktop session remains Hyprland/Wayland.
- Archiso's actual overlay copy uses `--no-preserve=mode`, dropping execute bits on added runtimes and shell helpers. The generated profile now records those executable permissions explicitly. Reproduced the copy behavior and verified a copied program runs after applying the generated permissions.
- Archiso removes `/boot` contents from the squashfs. The installer now restores `vmlinuz-linux-zen` from the installed kernel's module directory before initramfs/GRUB setup; missing or ambiguous kernels fail the installation step. Added regression tests.
- Original SDDM assets now use Space Grotesk from the image payload, with an explicit missing-font failure instead of a silent builder-font substitution. Generated the actual original login backgrounds and verified three font weights and 1920×1080 backgrounds.
- Builder failures now retain `toolchain.log` in the workflow evidence artifact.

Validation: six target-installer tests passed; Calamares module schemas, shell syntax and whitespace checks passed. Existing shell/application source remains unchanged. Full compilation, real live/installed boot and VirtualBox performance remain unverified; the cloud still blocks the configured Arch mirror and GitHub API with CONNECT 403.

### Shell reference gallery

Uploaded 13 original desktop/shell images and animated WebP files under `screenshots/shell-reference/`, with an Arabic gallery and a source-commit/checksum manifest. All copies match the original assets byte-for-byte. These are labelled reference images, not new ISO runtime screenshots. No shell code or artwork was changed.

### Cloud build resumed after environment publication

The official Arch builder image now builds successfully with TLS and package signatures enabled. Iris palette generation, mpvpaper compilation/help, and all six original font families completed. Added the original Caffeine idle-inhibitor build to the payload and compiled it successfully. To fit this cloud host's Docker VFS storage, compilation uses one shared container instead of several full image copies. Runtime and Calamares compilation are in progress; this is not an ISO boot result.

Calamares 3.3.14 compiled and packaged successfully in the Arch container; its six target tests and module schemas passed. Fixed installer selection to distinguish its main package from makepkg's additional debug package. Repository preflight found `libva-mesa-driver` and `xf86-video-vmware` no longer available; the image retains current Mesa, xorg-server's modesetting driver, and VirtualBox guest utilities. All 208 official image packages now resolve successfully. Pleamar compilation is in progress.

The signed local repository needed `pacman-key --init` before local signing; fixed. Removed releng's `virtualbox-guest-utils-nox` when selecting the graphical guest utilities to avoid their confirmed package conflict. The headless shell rendered its settings panel and responded to IPC (`bar_anchor=top`, `panel=settings`); this is not an ISO screenshot. GitHub logs became accessible and showed the toolchain build itself succeeded, but host-side `tee` failed because logs had container UID ownership. The workflow now keeps logs owned by the host runner.

### First completed ISO and real boot validation

GitHub run https://github.com/9a6r/Nahj-linux/actions/runs/40646940152 completed successfully for `d5bb7e3bee286148613ecee72ac44be68af331e0`, including the linux-zen initramfs and 3.4 GiB ISO. Downloaded that exact artifact; `sha256sum -c SHA256SUMS` passed (`5d4cd12fc7c592ee4cc56a540d272b0f82c92820af633750751fbbdce074aa43`). Xorriso confirms BIOS/EFI boot entries and the hybrid MBR/GPT layout. An interrupted local container build failed in mkinitcpio's `/dev/stdin` preset generation; this did not occur in the clean GitHub build. Use the successful artifact for boot testing, not the incomplete local tree.

Actual QEMU TCG tests reached the BIOS menu, custom Plymouth animation and the OVMF UEFI menu/system startup. Captures are in `screenshots/iso-runtime/`. Desktop, graphical installer, installed-system boot and VirtualBox remain under test/unverified at this point; menu or splash screenshots alone do not prove them. Repeated six installer target tests, shell syntax checks and original-source preservation check successfully. No original tracked file changed.

### Live session findings and compatibility fixes

The BIOS guest reached Hyprland with kernel `7.2.11-zen1-1-zen`; `hyprctl configerrors` returned no errors. The offline guest remained in `starting` because releng enables `systemd-time-wait-sync` with an infinite timeout; disabling that wait allowed pacman initialization and `graphical.target` to finish (`systemctl is-system-running`: `running`). The generated profile now removes only this wait-service enablement; time synchronization stays enabled.

On Virtio VGA with software Vulkan/llvmpipe, Pleamar's own-frame DMA-BUF path caused `invalid arguments for wl_surface.attach`. The runtime's existing `PLEAMAR_SWAPCHAIN=1` presentation mode allowed the original glass bar and Calamares welcome window to render. The session launcher now selects this mode only when Vulkan reports CPU devices exclusively. Hardware devices keep their default presentation path. No shell scenes, themes, animations or upstream runtime source changed. The first software-rendered frame under TCG took approximately 107 seconds, and a Luau startup handler hit its two-second deadline on some attempts; this environment is not evidence of acceptable animation speed or complete shell interaction.

The wallpaper appeared after invoking the existing helper manually. Its startup now shares the original Pleamar autostart mechanism and allows up to 60 seconds for the wallpaper daemon. Added QEMU's separately packaged Virtio display modules and qemu-img to the builder. Fixed ineffective negated-grep assertions in profile validation, removed stale releng file-permission metadata, and matched sudoers directory permissions. Updated shellcheck, shell syntax and profile preparation passed. Actual desktop and installer screenshots are uploaded with these diagnostic changes explicitly disclosed. Installed-system and VirtualBox tests remain outstanding.

## 2026-10-29 — Original video and source completeness

Reviewed the uploaded 91-second desktop reference. The requested layout is the original left Frame, with the original Hero clock and desktop system monitor, not the default top Island shown in earlier test captures. Added only three upstream JSON preferences to `/etc/skel` to select these existing features. No original UI code, effects, shaders or themes were replaced. The top and right edge handles appear on hover; a click opens the launcher or Desk respectively, as implemented upstream.

Audited the actual `f98ddb1` GitHub ISO against the 204 original tracked source files, including the symlink: all match, with original executable modes retained. All original `pacman_pkgs` requirements are installed; all 19 PLM scene entry points pass the actual packaged runtime's compiler check. Static reference checks cover 127 imports/includes/shaders; generated palette files are accounted for. Font assets match their pinned source hashes. Full evidence and the feature-to-source mapping are in [VIDEO-SOURCE-AUDIT.md](VIDEO-SOURCE-AUDIT.md).

The user's reference wallpaper videos/images and personal wallpaper collection are not in the repository. Exact wallpaper parity remains blocked on those original assets; no recreation or screenshot wallpaper was substituted. The latest ISO build succeeded and its checksum was verified, but it predates the three new preferences. Screenshots already uploaded reflect the earlier diagnostic session. The installer is paused before applying its virtual-disk plan; no completed installation or final visual parity is claimed.

## 2026-10-29 — Installer integration review

Removed the boot-video still from the installer package. Its welcome and install pages now use a separate vector composition in the existing Glass palette; no desktop theme or original shell source changed. The installer target now initializes and populates the persistent Arch package keyring, because the live keyring is mounted on tmpfs and is not included by unpackfs. Failures are reported by Calamares. Six target-cleanup tests, shellcheck, branding asset resolution and SVG parsing pass; full installed-guest validation remains pending.

The Frame build at run 40794212158 passed. A separate, manually modified Venus/virgl diagnostic guest aborted inside libvulkan_virtio during swapchain creation; this experimental driver path is not included in the ISO and is not accepted as runtime proof. Software-only TCG testing still cannot establish smooth animation on real hardware or VirtualBox.

## 2026-10-29 — Upstream fidelity and reported failures

Read all of the original README again and compared the current upstream README. Merged the official Vitreus commit `92cd90b0b3ff8bf88831b12f176051450da4a98a`, including its bundled add-ons and fixes, without hand-editing its UI. All 259 upstream tracked files match that commit byte-for-byte. This supersedes the earlier 204-file baseline audit; earlier screenshot and test evidence remains historical.

The overlapping system-monitor ring reproduces with the untouched upstream scene in a native headless renderer, outside the ISO/TCG guest. Investigation found that Pleamar parses child-shape `show:` but drops it when merging shapes inside `body`: the hidden GPU ring is still merged beside the memory ring. A small, separately maintained compiler patch under `distro/runtime/patches/` is being compiled and tested; it does not redraw the widget. No successful fix is claimed before rendered regression evidence.

The user reports a VirtualBox login loop in an RDP-hosted machine and choppy Plymouth animation. Keep linux-zen. The live password is already `nahj` (confirmed in the image setup script). Restrict SDDM to the one configured Nahj session and stop shipping the optional pleamar-wm executable (50 MiB uncompressed); preserve upstream source files. Login-loop reproduction, boot performance, the new runtime patch and the final desktop remain under local validation. ISO workflow is now manual-only: do not dispatch a GitHub build until local validation is satisfactory, per the user's instruction.

Downloaded two 1920×1080 Unsplash photographs into the original wallpaper-gallery folder for the requested picker/transition tests; sources, license link and SHA256 hashes are in `wallpaper-sources.json`. Wallhaven returned HTTP 403. The first-wallpaper helper now retries empty daemon replies and failed image requests. A fault-injection test passed; nine installer target tests pass, including package-keyring failure handling. Actual wallpaper-picker switching is not yet verified.
