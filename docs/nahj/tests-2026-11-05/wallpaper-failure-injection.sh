#!/bin/bash
set -euo pipefail
chmod 644 /usr/lib/systemd/user/nahj-wallpaper.service
as_user() { runuser -u nahj -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-1 "$@"; }
as_user systemd-analyze --user verify /usr/lib/systemd/user/nahj-wallpaper.service
as_user dbus-update-activation-environment --systemd WAYLAND_DISPLAY
install -d -o nahj -g nahj /run/user/1000/systemd/user/nahj-wallpaper.service.d
cat > /run/user/1000/systemd/user/nahj-wallpaper.service.d/90-failure-test.conf <<'DROPIN'
[Service]
ExecStart=
ExecStart=/bin/sh -c 'if [ ! -e /run/user/1000/nahj-retry-test ]; then touch /run/user/1000/nahj-retry-test; exit 1; fi; exec /usr/local/libexec/nahj-wallpaper'
DROPIN
as_user systemctl --user daemon-reload
as_user systemctl --user start --no-block nahj-wallpaper.service
