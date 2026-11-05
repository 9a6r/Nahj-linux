# Actual ISO installer diagnostic

These are screenshots captured from the running ISO guest through its QEMU SDL
display. They are not generated mockups. The guest uses UEFI, a disposable
40 GiB NVMe disk, linux-zen and Hyprland/Wayland. Calamares is a separate window.

Image: local ISO 04, SHA-256
`4d131179dfa1ce253fcce178fa5e1c1e85e1cd75bc8333e7cc286c0ba6dbab8a`.
Installer 3.3.14-3 was upgraded inside the live guest after checksum validation;
the ISO itself still contains 3.3.14-2. The installer was launched with debug
logging through a transient root service on the guest's actual Wayland session.
This does not test the ordinary launcher or certify a final shipped ISO.

- [Welcome](installer-welcome.png): the independent installer design, without
  the boot-animation background.
- [Partition plan](partition-before-contrast-fix.png): detected NVMe disk and
  EFI/ext4 layout. This capture exposed unreadable black partition labels on
  the dark background; a subsequent installer patch is being tested.
- [Empty password](empty-password-rejected.png): validation blocks progression.
- [Mismatched confirmation](password-mismatch.png): validation blocks progression.
- [Matching password](password-accepted.png): the same UI permits progression.
- [Installation completion](installation-complete.png): Calamares completed all
  32 jobs and displayed success. Post-install inspection then found a lingering
  target gpg-agent; it had to be stopped before the filesystem was fully
  unmounted. The subsequent read-only ext4 check passed with exit status 0.

The test account shown is disposable. From the keyboard step onward, Pleamar
processes were temporarily stopped to isolate installer testing from severe
TCG/software-rendering overhead. No shell or animation code was removed from
the image. These screenshots therefore **do not** prove shell visual parity,
normal desktop performance or installed-system login. Automatic post-install
daemon cleanup also needs a new full-install regression. See the
[test report](../../docs/nahj/tests-2026-11-05/README.md).
