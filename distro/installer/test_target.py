#!/usr/bin/env python3
"""Exercise live-to-installed cleanup in disposable filesystem fixtures only."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

module_path = Path(__file__).parent / "nahjtarget/main.py"
spec = importlib.util.spec_from_file_location("nahjtarget", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InstalledTargetTest(unittest.TestCase):
    def run_with_commands(self, statuses):
        call = Mock(side_effect=statuses)
        calamares = SimpleNamespace(
            globalstorage=SimpleNamespace(value=lambda key: str(self.root)),
            utils=SimpleNamespace(target_env_call=call),
        )
        with patch.dict("sys.modules", libcalamares=calamares):
            result = module.run()
        return result, call

    def test_installed_keyring_initialized_before_removing_installer(self):
        result, call = self.run_with_commands([0, 0, 0])
        self.assertIsNone(result)
        self.assertEqual([c.args[0] for c in call.call_args_list], [
            ["pacman-key", "--init"], ["pacman-key", "--populate", "archlinux"],
            ["pacman", "-R", "--noconfirm", "nahj-installer"],
        ])

    def test_keyring_init_failure_stops_installation(self):
        result, call = self.run_with_commands([1])
        self.assertIn("package verification", result[0])
        self.assertEqual(call.call_count, 1)

    def test_keyring_population_failure_stops_installation(self):
        result, call = self.run_with_commands([0, 2])
        self.assertIn("package verification", result[0])
        self.assertIn("status 2", result[1])
        self.assertEqual(call.call_count, 2)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nahj-target-test-")
        self.root = Path(self.temporary.name)
        files = {
            "etc/nahj/live-image": "Nahj live image\n",
            "usr/lib/modules/test-zen/pkgbase": "linux-zen\n",
            "usr/lib/modules/test-zen/vmlinuz": "test kernel payload\n",
            "etc/passwd": "root:x:0:0:root:/root:/bin/bash\nother:x:1001:1001::/home/other:/bin/bash\nnahj:x:1000:1000::/home/nahj:/bin/bash\n",
            "etc/shadow": "root:!:1::::::\nother:!:1::::::\nnahj:PUBLIC-LIVE-HASH:1::::::\n",
            "etc/group": "root:x:0:\nwheel:x:998:nahj,other\nnahj:x:1000:\n",
            "etc/gshadow": "root:!::\nwheel:!:nahj,other:nahj,other\nnahj:!::\n",
            "etc/sudoers.d/10-nahj-live": "nahj ALL=(ALL:ALL) NOPASSWD: ALL\n",
            "etc/sudoers.d/keep": "%wheel ALL=(ALL:ALL) ALL\n",
            "etc/sddm.conf.d/10-nahj-live.conf": "[Autologin]\nUser=nahj\n",
            "etc/sddm.conf.d/20-nahj-theme.conf": "[Theme]\nCurrent=vitreus\n",
            "etc/machine-id": "live-machine-id\n",
            "etc/mkinitcpio.conf.d/archiso.conf": "HOOKS=(archiso)\n",
            "home/nahj/live-only": "live data\n",
            "home/other/keep": "preserve other account\n",
        }
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (self.root / "etc/shadow").chmod(0o600)
        wants = self.root / "etc/systemd/system/multi-user.target.wants"
        wants.mkdir(parents=True)
        (wants / "pacman-init.service").symlink_to("/usr/lib/systemd/system/pacman-init.service")
        (wants / "NetworkManager.service").symlink_to("/usr/lib/systemd/system/NetworkManager.service")

    def tearDown(self):
        self.temporary.cleanup()

    def test_removes_live_credentials_and_keeps_desktop(self):
        module.configure_target(self.root)
        for name in ("passwd", "shadow", "group", "gshadow"):
            self.assertNotIn("nahj", (self.root / "etc" / name).read_text())
        self.assertEqual((self.root / "etc/shadow").stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.root / "etc/sudoers.d/10-nahj-live").exists())
        self.assertFalse((self.root / "etc/sddm.conf.d/10-nahj-live.conf").exists())
        self.assertFalse((self.root / "home/nahj").exists())
        self.assertFalse((self.root / "etc/nahj/live-image").exists())
        self.assertFalse((self.root / "etc/machine-id").exists())
        self.assertTrue((self.root / "etc/sddm.conf.d/20-nahj-theme.conf").exists())
        self.assertTrue((self.root / "home/other/keep").exists())
        wants = self.root / "etc/systemd/system/multi-user.target.wants"
        self.assertFalse((wants / "pacman-init.service").is_symlink())
        self.assertTrue((wants / "NetworkManager.service").is_symlink())

    def test_restores_kernel_missing_from_live_squashfs(self):
        module.configure_target(self.root)
        self.assertEqual((self.root / "boot/vmlinuz-linux-zen").read_bytes(),
                         (self.root / "usr/lib/modules/test-zen/vmlinuz").read_bytes())

    def test_missing_kernel_stops_before_account_changes(self):
        (self.root / "usr/lib/modules/test-zen/vmlinuz").unlink()
        before = (self.root / "etc/passwd").read_bytes()
        with self.assertRaises(ValueError):
            module.configure_target(self.root)
        self.assertEqual((self.root / "etc/passwd").read_bytes(), before)

    def test_refuses_unmarked_or_host_root(self):
        with self.assertRaises(ValueError):
            module.configure_target("/")
        (self.root / "etc/nahj/live-image").unlink()
        before = (self.root / "etc/passwd").read_bytes()
        with self.assertRaises(ValueError):
            module.configure_target(self.root)
        self.assertEqual((self.root / "etc/passwd").read_bytes(), before)

    def test_refuses_account_symlink(self):
        with tempfile.TemporaryDirectory(prefix="nahj-outside-test-") as outside:
            outside_passwd = Path(outside) / "passwd"
            outside_passwd.write_text("do not modify\n")
            (self.root / "etc/passwd").unlink()
            (self.root / "etc/passwd").symlink_to(outside_passwd)
            with self.assertRaises(ValueError):
                module.configure_target(self.root)
            self.assertEqual(outside_passwd.read_text(), "do not modify\n")

    def test_rejects_parent_symlink_escape(self):
        with tempfile.TemporaryDirectory(prefix="nahj-outside-test-") as outside:
            outside_path = Path(outside)
            self.root.joinpath("etc/sudoers.d/10-nahj-live").unlink()
            self.root.joinpath("etc/sudoers.d/keep").unlink()
            self.root.joinpath("etc/sudoers.d").rmdir()
            self.root.joinpath("etc/sudoers.d").symlink_to(outside_path)
            (outside_path / "10-nahj-live").write_text("must remain\n")
            with self.assertRaises(ValueError):
                module.configure_target(self.root)
            self.assertEqual((outside_path / "10-nahj-live").read_text(), "must remain\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
