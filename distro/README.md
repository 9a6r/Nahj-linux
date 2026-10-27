# Nahj Arch image

This directory packages the existing shell as an Arch Linux live/install image. The shell's application files and default glass theme remain unchanged.

The intended stack is Wayland + Hyprland + Vitreus/pleamar, `linux-zen`, the existing Vitreus SDDM login theme, and a Nahj Plymouth boot animation generated from the supplied video. Calamares provides the optional graphical installer. Launching the live image must not install to or format a disk.

Development decisions and validation evidence: [development log](../docs/nahj/CHANGELOG.md). Visual evidence is kept separately in [screenshots](../screenshots/README.md).

VirtualBox must use VMSVGA with 3D acceleration, sufficient graphics memory and RAM. Software rendering is a fallback, not a guarantee of native animation performance. Full visual parity and hardware behavior must be checked on the target machine.

Build and test instructions will accompany the implemented scripts. Do not execute host disk-partitioning commands to test an installer configuration.
