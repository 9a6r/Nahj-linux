"""Convert the copied Nahj live filesystem into an installed system.

Runs inside Calamares after unpackfs and before users. No disk discovery,
partitioning, or formatting is performed here.
"""
from pathlib import Path
import shutil


LIVE_FILES = (
    "etc/nahj/live-image",
    "etc/sddm.conf.d/10-nahj-live.conf",
    "etc/sudoers.d/10-nahj-live",
    "etc/pacman.d/hooks/85-nahj-image-setup.hook",
    "usr/local/libexec/nahj-image-setup",
    "etc/mkinitcpio.conf.d/archiso.conf",
    "etc/machine-id",
    "var/lib/dbus/machine-id",
)
LIVE_UNITS = {"choose-mirror.service", "pacman-init.service", "etc-pacman.d-gnupg.mount"}


def target_path(root, relative):
    """Resolve parents only: removing a symlink must never follow its target."""
    path = root / relative
    if not path.parent.resolve().is_relative_to(root):
        raise ValueError(f"Target path escapes the installation root: {relative}")
    return path


def remove_path(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def configure_target(root_path):
    root = Path(root_path).resolve(strict=True)
    if root == Path("/") or not (root / "etc/nahj/live-image").is_file():
        raise ValueError("Refusing cleanup without a copied Nahj live-image marker in a target root")
    if not target_path(root, "etc/passwd").is_file():
        raise ValueError("The copied target has no account database")

    # Remove the public live login before the users module creates the chosen
    # account, so the installed username may legitimately be 'nahj' too.
    for relative in ("etc/passwd", "etc/shadow", "etc/group", "etc/gshadow"):
        path = target_path(root, relative)
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Missing or unsafe target account database: {relative}")
        lines = []
        for line in path.read_text().splitlines():
            fields = line.split(":")
            if fields[0] == "nahj":
                continue
            if relative in ("etc/group", "etc/gshadow") and len(fields) == 4:
                fields[3] = ",".join(name for name in fields[3].split(",") if name != "nahj")
                if relative == "etc/gshadow":
                    fields[2] = ",".join(name for name in fields[2].split(",") if name != "nahj")
            lines.append(":".join(fields))
        # Writing in place retains root ownership and shadow-file permissions.
        path.write_text("\n".join(lines) + "\n")
    remove_path(target_path(root, "home/nahj"))

    unit_root = target_path(root, "etc/systemd/system")
    if unit_root.is_dir() and not unit_root.is_symlink():
        for path in list(unit_root.rglob("*")):
            if path.name in LIVE_UNITS:
                remove_path(target_path(root, str(path.relative_to(root))))
    for relative in LIVE_FILES:
        remove_path(target_path(root, relative))


def pretty_name():
    return "Preparing the installed Nahj system"


def run():
    import libcalamares
    root = libcalamares.globalstorage.value("rootMountPoint")
    if not root:
        return ("Missing installation target", "Calamares did not supply rootMountPoint.")
    try:
        configure_target(root)
    except (OSError, ValueError) as error:
        return ("Could not prepare the installed system", str(error))
    # Remove the live-only installer from the target's package database as well
    # as its files. Dependencies remain; the running installer is on live media.
    result = libcalamares.utils.target_env_call(["pacman", "-R", "--noconfirm", "nahj-installer"])
    if result:
        return ("Could not remove the live installer", f"pacman exited with status {result}.")
    return None
