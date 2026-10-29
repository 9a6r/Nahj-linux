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


def restore_kernel(root):
    """Archiso strips /boot from squashfs; restore zen before initcpio/GRUB."""
    modules = target_path(root, "usr/lib/modules")
    if modules.is_symlink():
        raise ValueError("Unsafe target modules directory")
    candidates = []
    for pkgbase in modules.glob("*/pkgbase"):
        kernel = target_path(root, str(pkgbase.parent.relative_to(root) / "vmlinuz"))
        if pkgbase.is_symlink() or kernel.is_symlink():
            raise ValueError("Unsafe target kernel metadata")
        if pkgbase.read_text().strip() == "linux-zen" and kernel.is_file():
            candidates.append(kernel)
    if len(candidates) != 1:
        raise ValueError("Expected exactly one installed linux-zen kernel")
    boot = target_path(root, "boot")
    if boot.is_symlink():
        raise ValueError("Unsafe target boot directory")
    boot.mkdir(exist_ok=True)
    destination = target_path(root, "boot/vmlinuz-linux-zen")
    if destination.is_symlink():
        raise ValueError("Unsafe target kernel destination")
    shutil.copyfile(candidates[0], destination)
    destination.chmod(0o644)


def configure_target(root_path):
    root = Path(root_path).resolve(strict=True)
    if root == Path("/") or not (root / "etc/nahj/live-image").is_file():
        raise ValueError("Refusing cleanup without a copied Nahj live-image marker in a target root")
    if not target_path(root, "etc/passwd").is_file():
        raise ValueError("The copied target has no account database")

    restore_kernel(root)

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
    # The live keyring is a tmpfs mount; unpackfs copies the image, not that
    # initialized mount. The installed system needs its own persistent keyring
    # before the live-only pacman-init service is retired.
    for command in (["pacman-key", "--init"], ["pacman-key", "--populate", "archlinux"]):
        result = libcalamares.utils.target_env_call(command)
        if result:
            return ("Could not initialize package verification", f"{' '.join(command)} exited with status {result}.")
    # Remove the live-only installer from the target's package database as well
    # as its files. Dependencies remain; the running installer is on live media.
    result = libcalamares.utils.target_env_call(["pacman", "-R", "--noconfirm", "nahj-installer"])
    if result:
        return ("Could not remove the live installer", f"pacman exited with status {result}.")
    return None
