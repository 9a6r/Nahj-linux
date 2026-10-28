# syntax=docker/dockerfile:1.7
# The base is pinned; the package transaction remains a full Arch upgrade.
ARG ARCH_IMAGE=archlinux:base-devel@sha256:3cbf69d2d5958d6a294f3722c5668e6187c4df8e00fa27f72352f0bf83e495e1
FROM ${ARCH_IMAGE}

# The cloud's HTTPS proxy can require its public CA bundle. Pass it with
# --secret id=cloud_ca,src=/path/to/ca-bundle.pem. Never disable TLS or pacman
# signature checks. Normal GitHub runners omit this optional build secret.
RUN --mount=type=secret,id=cloud_ca \
    if [ -s /run/secrets/cloud_ca ]; then \
        install -Dm644 /run/secrets/cloud_ca /etc/ca-certificates/trust-source/anchors/nahj-cloud.crt; \
        update-ca-trust; \
    fi \
    && printf 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist \
    && pacman -Syu --noconfirm --needed \
        archiso rust clang cmake ninja meson pkgconf git curl \
        wayland wayland-protocols libxkbcommon pam vulkan-icd-loader \
        libinput seatd systemd-libs mesa vulkan-swrast vulkan-tools \
        xorg-xwayland pipewire libpipewire openssl opus ffmpeg mpv \
        dbus fontconfig ttf-dejavu socat jq imagemagick shellcheck \
        python python-pillow python-numpy python-build python-installer \
        python-hatchling python-pyte python-gobject python-fonttools \
        python-pyyaml python-jsonschema pybind11 \
        qt6-base qt6-declarative qt6-svg qt6-wayland qt6-tools \
        yaml-cpp kpmcore kcoreaddons polkit-qt6 extra-cmake-modules \
        libpwquality icu libxcrypt boost \
        parted rsync squashfs-tools dosfstools e2fsprogs \
        grub efibootmgr os-prober plymouth sddm qemu-system-x86 qemu-img \
        qemu-hw-display-virtio-vga qemu-hw-display-virtio-gpu edk2-ovmf \
    && useradd --create-home --uid 1000 --shell /bin/bash builder \
    && install -d -o builder -g builder /build \
    && pacman -Q > /usr/local/share/nahj-build-packages.txt

ENV CARGO_BUILD_JOBS=2
WORKDIR /build

# Keep root as the default for mkarchiso. Build Calamares with `--user builder`
# or `runuser -u builder -- ...`; makepkg must never run as root.
CMD ["/bin/bash"]
