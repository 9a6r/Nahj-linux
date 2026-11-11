# Removal of distribution appearance overrides

The restored workspace became accessible and the remote development branch was
confirmed at `c346d92`. No GitHub ISO workflow was dispatched.

The distribution's Hyprland seed previously imposed border colors and width,
gaps, rounding, blur/shadow settings, cursor sizes, animation/input preferences,
and compositor wallpaper/logo preferences. These choices were not part of the
original Vitreus source. Removed that override block and the cursor-size exports.
The seed now keeps monitor detection, basic window/terminal/media bindings, and
the original `hypr_vitreus`, `vitreus_monitors`, `vitreus_hypr` and
`vitreus_colors` imports. Compositor defaults apply until original Vitreus
settings are loaded. This does not disable animations or introduce a new theme.

The original repository does not supply a complete base Hyprland configuration;
its README documents importing the shell's bindings and generated settings into
one. The remaining seed is distribution integration, not a claim that it was
written by the Vitreus author. Existing users' configuration files are not
silently overwritten by session initialization.

All 259 original Git entries, including the symlink target and SDDM files,
still match commit `92cd90b0b3ff8bf88831b12f176051450da4a98a`.
The greeter builder invokes the original `sddm/build-assets.sh` with the supplied
fonts; no replacement QML design was introduced. The installer retains its own
Calamares branding and launcher, separate from Vitreus and SDDM.

The existing Pleamar runtime patch is retained: it fixes ignored original
`show:` conditions inside merged shapes, including the reported ghost GPU ring.
It changes the runtime's interpretation of the original scene, not the scene's
layout or colors. The software-presentation fallback and wallpaper startup retry
are also functional integration fixes, not replacement shell designs.

Validation performed this session:

- All 259 original entries matched their recorded hashes (symlinks compared as
  link targets, not as the contents of the destination file).
- `luac5.4 -p` accepted the reduced Hyprland seed.
- All eleven existing installer target tests passed.
- `git diff --check` passed.

The restored builder does not have a runnable `Hyprland` binary in its PATH;
Lua syntax validation is not compositor runtime or visual validation. No new
ISO or screenshots of this change have been produced yet. Existing installed
configurations and ISO 06 retain the old seed until explicitly updated/rebuilt.
Boot animation smoothness and the previously documented runtime crashes remain
unresolved; this cleanup is not release certification.
