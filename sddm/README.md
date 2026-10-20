# The Vitreus login screen (SDDM)

The lock screen's look, as a theme for SDDM's greeter: your picture arrives sharp and blurs into place, then the clock, the date, your face and a glass password bar rise one after another.
A typed character is a random shape (the password itself is never drawn). A wrong password shakes the bar. Sleep, restart and power off are held for a second.
The corners show the machine's name and the session (click it to change it); if there are several users, click the face to change.

An SDDM greeter is a Qt program and a theme is QML, so this one is not a pleamar scene (the lock screen is). It needs `sddm` and `qt6-declarative`, which SDDM already depends on.

## Trying it first (no sudo, nothing installed)

```sh
./sddm/build-assets.sh /tmp/vitreus-greeter && QT_QPA_PLATFORM=xcb sddm-greeter-qt6 --test-mode --theme /tmp/vitreus-greeter
```

It opens the login screen in a window (`QT_QPA_PLATFORM=xcb` runs it through XWayland: without `qt6-wayland` it cannot open natively). Entering a password does not log in. If you see SDDM's blue default screen with
"Main.qml: No such file", the `--theme` path does not hold the theme: it only is in `/usr/share/sddm/themes/vitreus` after `install.sh`.

## Installing

Vitreus's own `install.sh` offers this (it asks, since it needs sudo; `--no-login` skips it), or run it yourself:

```sh
./sddm/install.sh                       # the picture is ~/Downloads/greeter.jpg
./sddm/install.sh ~/Pictures/other.jpg  # or another
```

It makes the pictures (sharp and blurred, 1920 x 1080) with ImageMagick, copies the theme to `/usr/share/sddm/themes/vitreus` with Space Grotesk, your `~/.face` and the colours of
Vitreus's palette, and makes it the theme in use. If SDDM has no theme set, that is done at once; **if it already has one it asks first** (`--set` or `--yes` says yes, `--no-set` only installs it, and with no keyboard to answer on it leaves the old one). The file that said which theme is in use is kept as `<file>.before-vitreus`. It asks for your password, as it uses `sudo`. Without a picture of yours (`~/Downloads/greeter.jpg`) it uses the banner in `assets/`.
The next login screen is the new one. To see the installed one without logging out: `QT_QPA_PLATFORM=xcb sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/vitreus`.

(In test mode there is no user list, no session list and no power buttons, so the name, the corners and the power pill are left out.)

`./sddm/install.sh --remove` puts the theme that was in use back. If a login screen ever does not appear, Ctrl+Alt+F3 is a text login, and the same command works from there.

## Changing it

`vitreus/theme.conf` holds the colours and the 12 or 24 hour clock (installing writes the colours from `palette.plm`: install again after the palette changes). `vitreus/Main.qml` is the whole screen.
`./sddm/build-assets.sh OUTDIR [IMAGE]` makes a theme folder without installing it, to try with `--test-mode`.
