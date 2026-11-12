#!/usr/bin/env python3
"""Exercise presentation selection with complete, failing and hung ICD probes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).parent / "archiso/airootfs/usr/local/libexec/nahj-vulkan-env"


class PresentationTest(unittest.TestCase):
    def probe(self, script, override=None, timeout=5):
        with tempfile.TemporaryDirectory(prefix="nahj-vulkan-test-") as directory:
            executable = Path(directory) / "vulkaninfo"
            executable.write_text("#!/bin/bash\n" + script + "\n")
            executable.chmod(0o755)
            env = os.environ.copy()
            env.pop("PLEAMAR_SWAPCHAIN", None)
            if override is not None:
                env["PLEAMAR_SWAPCHAIN"] = override
            env["PATH"] = directory + os.pathsep + env["PATH"]
            result = subprocess.run(
                ["bash", "-c", 'set -euo pipefail; source "$1"; printf "%s" "${PLEAMAR_SWAPCHAIN-<unset>}"',
                 "presentation-test", str(HELPER.resolve())],
                env=env, capture_output=True, text=True, timeout=timeout, check=True,
            )
            return result.stdout

    def test_cpu_uses_portable_presentation(self):
        self.assertEqual(self.probe("echo 'deviceType = PHYSICAL_DEVICE_TYPE_CPU'"), "1")

    def test_hardware_keeps_original_path(self):
        for kind in ("INTEGRATED_GPU", "DISCRETE_GPU", "VIRTUAL_GPU"):
            with self.subTest(kind=kind):
                self.assertEqual(self.probe(f"echo 'deviceType = PHYSICAL_DEVICE_TYPE_{kind}'"), "<unset>")

    def test_mixed_devices_keep_hardware_path(self):
        self.assertEqual(self.probe("printf 'deviceType = PHYSICAL_DEVICE_TYPE_CPU\\ndeviceType = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU\\n'"), "<unset>")

    def test_empty_success_is_inconclusive(self):
        self.assertEqual(self.probe("exit 0"), "1")

    def test_failed_probe_uses_portable_presentation(self):
        self.assertEqual(self.probe("exit 1"), "1")

    def test_partial_hardware_output_followed_by_failure(self):
        self.assertEqual(self.probe("echo 'deviceType = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU'; exit 1"), "1")

    def test_explicit_user_setting_skips_probe(self):
        for override in ("1", "0", ""):
            with self.subTest(override=override):
                # If invoked, this probe would stall beyond the test timeout.
                self.assertEqual(self.probe("sleep 60", override=override), override)

    def test_hung_probe_ignoring_termination_is_bounded(self):
        # Exercise the real timeout and SIGKILL fallback, not a timeout stub.
        self.assertEqual(self.probe("trap '' TERM; exec sleep 60", timeout=25), "1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
