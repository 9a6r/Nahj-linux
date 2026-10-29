# Video reference and original-source audit

Reference: the user's uploaded `m2-res_1080p.mp4` (1920×1080, 30 fps, 91.33 seconds). This is distinct from the Nahj Plymouth source video. The desktop reference is evidence of desired behavior, not a source of replacement UI artwork.

GitHub identifies `9a6r/Nahj-linux` as a fork of `natepayn3/Vitreus`. The preserved source baseline is `f8a930e5008c98a04eedf195a27476e272712da2`.

## What is present

Compared every one of the baseline's **204 tracked files**, including its symbolic link, against both the checkout and the actual shell seed extracted from the GitHub ISO built at `f98ddb1ec551a73e3fb681fdd6c2bdb991522625`. All match. No original shell file was rewritten or replaced with a visual imitation.

ISO SHA256: `71a56010bad23f927b23abea9c9bf77b015f1b61372a295749bd17da8f2046df`. Build: https://github.com/9a6r/Nahj-linux/actions/runs/40687384829.

The audit resolved 127 literal PLM imports, includes and shader references. `palette.plm` and `wm-palette.plm` are intentionally generated from the original `.default.plm` files by session initialization, as upstream expects; they are not missing source. All 19 scene entry points, including the original add-on templates, passed the packaged Pleamar runtime's `--check` after this initialization in a separate temporary tree. This checks scene compilation, not runtime animation speed or all Luau event handlers.

Every package in upstream `install.sh`'s `pacman_pkgs` list exists in the ISO's package database. The original Pleamar runtime, Iris, mpvpaper and the compiled upstream `vitreus-inhibit.c` helper are present and executable. The runtime was built from the original pinned Pleamar source, not recreated. All five theme definitions remain present: Glass, Retro, Cyber, Milkbox and UwU. Their font files are included.

Machine-readable evidence: [source files and hashes](source-audit.json), [scene compiler results](scene-audit.json).

## Mapping the reference to existing code

| Visible feature | Original implementation |
| --- | --- |
| Persistent left strip and frame | `logic/bar_position.luau`, `pages/bar_glass.plm`, `pages/bar_icons.plm` |
| Hidden top-edge launcher handle | `vitreus.plm`: `ntz_t`, `ntn_t`, `nt_hold_t`, `nt_vis_t` |
| Right-edge Desk handle and drawer | `vitreus.plm`: `ntz_r`, `ntn_r`, `desk_open`; `pages/desk.plm` |
| Large hour over smaller minutes | `desktopclock/desktopclock.plm`, `desktopclock/clockface.plm`: existing Hero layout 5 |
| Bottom-right system monitor | `desktopsysmon/`, `bin/vitreus-sysmon` |
| Media player, audio visualizer and detached player | `pages/player.plm`, `pages/media_float.plm`, `logic/visualizer.luau` |
| Hexagonal wallpaper picker and transition | `pages/wallpaper.plm`, `wptrans/hexreveal.wgsl`, `wptrans/wptrans.plm` |
| Theme switching and original effects | `pages/theme.plm`, `themes/*.toml`, `bin/vitreus-themes`, original WGSL shaders |
| Pad, Shelf, clipboard, Focus, terminal and Ask tabs | `pages/desk.plm`, `logic/pad.luau`, `logic/shelf.luau`, `logic/clipboard.luau`, `logic/focus.luau`, `logic/term.luau`, `logic/ask.luau` |

In Frame mode, hovering near the top or right edge reveals a small handle. **Clicking** the top handle opens the launcher; clicking the right handle opens Desk. Hover alone does not open the entire Desk. `Super+D` also toggles Desk. The earlier horizontal Island bar was the upstream default layout, not the requested video layout.

## Configuration change, not replacement UI

Three first-login JSON preferences in `/etc/skel/.local/share/pleamar/` now select the existing left Frame layout, show the original Hero clock at the top right, and enable the original system monitor at the bottom right. Existing user preferences are not overwritten. The clock retains the upstream default size; exact placement/scale and visual behavior still require a fresh ISO runtime check. No new theme, shader, panel or animation was implemented. The old screenshots predate these preferences and are not proof of the corrected layout.

## Assets not supplied by this fork

The reference shows a moving ocean wallpaper, a snowy city wallpaper and a large personal wallpaper gallery. Those original media files are **not** in the baseline repository. Its `assets/screenshots/` files are recordings of the desktop, not the underlying clean wallpapers. The repo includes `assets/greeter.jpeg`; that is the distinct backdrop seen in the earlier ISO screenshots.

Exact wallpaper parity needs the original media files or their original download source. No frame from the demonstration has been substituted for a wallpaper, and no imitation was generated. Browser/music content, application accounts and personal files displayed in the video are likewise separate from the shell's source. Presence and compilation of the complete shell do not establish identical content, successful installation, hardware acceleration or smooth VirtualBox animation.
