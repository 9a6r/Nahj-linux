# Lossless BMP boot candidate

Status: **native checks passed; release validation still open**. The current
ISO checksum in the parent report refers to the earlier PNG image. This change
requires a new ISO and installed-system test. No Actions build was dispatched.

Plymouth's installed `libply-splash-graphics.so.5` accepts uncompressed 24-bit
BMP. All 240 BMP frames were regenerated from the checksum-verified source video
and compared against the previous PNG frames through that library. Every ARGB
pixel matches, in all three benchmark passes. No source frame, color, size,
frame rate or intro/loop transition changed.

| Native frame-load diagnostic | Previous PNG | BMP |
| --- | ---: | ---: |
| Median wall time | 15.55 ms | 5.09 ms |
| Mean wall time | 18.68 ms | 6.90 ms |
| 99th percentile | 51.49 ms | 20.22 ms |
| Maximum | 408.73 ms | 490.55 ms |

The occasional long outlier remains: these measurements do not certify an
absence of stalls. Raw values and the diagnostic C source are included. Each
round alternates the order of the two formats. The benchmark includes actual
Plymouth decoding and compares both resulting buffers, not just file hashes.

A separate 16-second X11 capture of the candidate at 1280×720 recorded 956/960
expected samples, 363 distinct matched image changes, mean interval 42.03 ms,
maximum interval 133.33 ms and one interval above 84 ms. The recorder itself had
a 66.67 ms gap. Both disposable VMs were paused and no build ran during capture.
The previous isolated PNG capture averaged 46.49 ms and had six intervals above
84 ms. One capture is not proof of hardware, virtual-machine or long-run timing.

The compressed-size tradeoff is explicit: tar/zstd-3 grew from 227 to 326 MiB.
Uncompressed frame storage remains about 633 MiB. Only one frame is decoded at a
time; all-frame preloading is still excluded. The 456-frame preview remains
1280×720 at 24 fps, with one intro and three background cycles.

`distro/boot/check_frames.py` now verifies all frame checksums and dimensions,
then compares Plymouth's decoded pixels with Pillow's. The manual build workflow
runs it after generation. An altered checksum and a malformed BMP with a
matching checksum were both rejected in separate disposable fixtures. This
covers corruption and actual decoder support; it does not replace runtime tests.

The composer now supports `--mirror-url file:///absolute/path` for a clean local
build from the cached signed Arch repositories. The prepared profile retained
`SigLevel = Required DatabaseOptional` for official packages and `Required` for
the local installer repository. Signature verification was not weakened.
