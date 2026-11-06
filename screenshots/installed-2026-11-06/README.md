# Captures from the installed NVMe system

The ISO was disconnected. These are actual QEMU display captures of the
installed UEFI/NVMe system, using linux-zen and the original Vitreus greeter.
The guest display window was resized to fit the capture screen; the files are
direct captures, not reconstructed mockups.

- [Installed Plymouth](plymouth.png): the custom animation is present after
  installation. One frame does not prove smooth playback.
- [Original login screen](greeter.png): the new account appears with the single
  Nahj Hyprland/Vitreus session.
- [Old live password rejected](live-password-rejected.png): `nahj` cannot unlock
  the installed account. The new password subsequently authenticated and
  started Hyprland and the original shell processes.

These captures do not yet show a fully rendered desktop or certify animation
performance. See the [runtime report](../../docs/nahj/tests-2026-11-06/README.md).

- [Incomplete original lock screen](lockscreen-incomplete.png): actual installed
  session after idle locking. The large clock is absent in this capture. This
  records a visual issue under investigation, not a complete-desktop success.
