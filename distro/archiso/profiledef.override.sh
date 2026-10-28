# Sourced after the installed Archiso releng profile, in a generated build copy.
iso_name="nahj"
iso_label="NAHJ_$(date --utc --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m%d)"
iso_publisher="Nahj Linux <https://github.com/9a6r/Nahj-linux>"
iso_application="Nahj Linux Live Desktop and Installer"
iso_version="$(date --utc --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
kernel_params_x86_64="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0"
airootfs_image_type="squashfs"
# Lower peak build memory and faster live decompression than the releng xz default.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M' '-processors' '2')
file_permissions+=(
  ["/usr/local/bin/nahj-session"]="0:0:755"
  ["/usr/local/bin/nahj-session-init"]="0:0:755"
  ["/usr/local/libexec/nahj-image-setup"]="0:0:755"
  ["/usr/local/libexec/nahj-wallpaper"]="0:0:755"
  ["/etc/sudoers.d/10-nahj-live"]="0:0:440"
  ["/etc/sudoers.d"]="0:0:750"
)
