# Actual ISO09 UEFI boot capture

![Nahj Plymouth during ISO09 cold boot](plymouth.png)

Captured directly from QEMU while booting `nahj-2026.11.12-x86_64.iso` built
from `943607c58dc2211a99cdb55eb04cf54572674ca8`.
SHA256: `6d9afb542e979cca330ee29498a601f561cd941f830d1f8fa06351369e628e3b`.

OVMF UEFI, q35/TCG, 2 vCPUs, 8 GiB RAM, plain Virtio VGA, 1280×720 and a blank
40 GiB NVMe disk; default boot entry. This is the running ISO's boot screen,
not a generated preview. A still image does not prove smooth animation, and
it is not a successful desktop or installer screenshot.

[Build and validation evidence](../../docs/nahj/tests-2026-11-13/README.md).
