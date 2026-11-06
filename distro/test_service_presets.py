#!/usr/bin/env python3
"""Test first-boot presets using real unit files from a composed image.

Run in the Arch build environment. Pass an extracted image root (read only);
only temporary copies of its unit/preset directories are changed. No service
is started and no host systemctl state is changed.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    image = Path(sys.argv[1]).resolve(strict=True)
    policy = Path(__file__).parent / "archiso/airootfs/usr/lib/systemd/system-preset/10-nahj.preset"
    with tempfile.TemporaryDirectory(prefix="nahj-presets-") as directory:
        root = Path(directory)
        for relative in ("usr/lib/systemd/system", "usr/lib/systemd/system-preset"):
            shutil.copytree(image / relative, root / relative, symlinks=True)
        # Preserve real image enablement, including aliases. Starting with an
        # empty directory misses stale releng links that enable-only preserves.
        shutil.copytree(image / "etc/systemd/system", root / "etc/systemd/system", symlinks=True)
        (root / "etc/os-release").write_text("ID=arch\n")
        packaged_policy = root / "usr/lib/systemd/system-preset/10-nahj.preset"
        if not packaged_policy.is_file() or packaged_policy.read_bytes() != policy.read_bytes():
            raise RuntimeError("The image does not contain the current Nahj service preset")
        subprocess.run(["systemctl", f"--root={root}", "--preset-mode=enable-only", "preset-all"], check=True)
        expected = {
            "NetworkManager.service": "enabled",
            "sddm.service": "enabled",
            "bluetooth.service": "enabled",
            "power-profiles-daemon.service": "enabled",
            "vboxservice.service": "enabled",
            "systemd-timesyncd.service": "enabled",
            "systemd-networkd.service": "disabled",
            "systemd-networkd.socket": "disabled",
            "systemd-networkd-wait-online.service": "disabled",
            "systemd-resolved.service": "disabled",
            "iwd.service": "disabled",
            "sshd.service": "disabled",
            "systemd-time-wait-sync.service": "disabled",
        }
        for unit, state in expected.items():
            result = subprocess.run(["systemctl", f"--root={root}", "is-enabled", unit], text=True, capture_output=True)
            actual = result.stdout.strip()
            if actual != state:
                raise RuntimeError(f"{unit}: expected {state}, got {actual!r}: {result.stderr}")
            print(f"PASS {unit}: {state}")
        for link in (root / "etc/systemd/system").rglob("*"):
            if link.is_symlink() and link.name.startswith("systemd-networkd"):
                raise RuntimeError(f"Competing networkd dependency enabled: {link}")


if __name__ == "__main__":
    main()
