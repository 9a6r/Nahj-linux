# Native renderer diagnostic — not a booted ISO screenshot

`original-frame.png` is an actual capture produced by the original Vitreus
`dev/rig` tool using the shell and runtime extracted from ISO06. It runs the
main shell in the upstream headless development compositor, outside CPU
emulation. The compositor is a test dependency only and is not shipped in Nahj.
The rig starts only the main scene here, without wallpaper/clock/sysmon daemons;
its black center and absent desktop widgets are expected limitations of this
fixture. This is not the complete Hyprland desktop, an installer preview or
release/animation certification. No reconstructed UI was used.
