#!/bin/bash
# A fast look at the desktop without a virtual PC (2026-11-21), for building: runs the TaylorOS image in podman with
# THIS checkout's desktop files, a screenless Wayland desktop (sway, software drawing; the same layer-shell Hyprland
# speaks), and Quickshell; takes screenshots and keeps the log. Not a Hyprland test (that is .github/workflows/vm-phase.yml).
#
#   tools/local-preview.sh OUTDIR CONFIG [SECONDS] [VAR=value ...] [-- SHOTS]
#     CONFIG   quickshell (her desktop) or greeter (her login screen) or a path inside the repo
#     SECONDS  when the (first) screenshot is taken (default 8)
#     VAR=...  passed to Quickshell (TAYLOR_SKY_HOUR=22, TAYLOR_LAUNCHER_PREVIEW=st, ...)
#     SHOTS    after "--": more screenshot times in seconds after the first, e.g. -- 1 2 4
#   An IPC call can be made while it runs: put IPC="target function args" in the VAR list (done just before the first shot).
#   The settings file: SETTINGS='{"scheme":"night"}' writes ~/.config/taylor-os/settings.json first.
# Run inside WSL (FedoraLinux-44), from the repo: wsl -d FedoraLinux-44 -- bash tools/local-preview.sh /tmp/o quickshell 8
set -u
OUT=$(realpath -m "$1"); CONF="$2"; WAIT="${3:-8}"; shift 3 2>/dev/null || shift $#
ENVS=(); SHOTS=(); IPC=""; SETTINGS=""; W=1920; HH=1080
while [ $# -gt 0 ]; do
  case "$1" in
    --) shift; SHOTS=("$@"); break ;;
    IPC=*) IPC="${1#IPC=}" ;;
    SETTINGS=*) SETTINGS="${1#SETTINGS=}" ;;
    SIZE=*) s="${1#SIZE=}"; W="${s%x*}"; HH="${s#*x}" ;;
    *) ENVS+=("$1") ;;
  esac
  shift
done
REPO=$(cd "$(dirname "$0")/.." && pwd)
case "$CONF" in quickshell|greeter) CONF="files/system/usr/share/taylor-os/$CONF" ;; esac
mkdir -p "$OUT" && chmod 777 "$OUT"   # rootless podman: her test account inside writes here
cat > "$OUT/.run.sh" <<EOS
set -u
command -v sway >/dev/null || dnf install -y -q --setopt=install_weak_deps=False sway grim dbus-daemon >/dev/null 2>&1
id tester >/dev/null 2>&1 || useradd -m tester
dbus-uuidgen > /etc/machine-id 2>/dev/null
mkdir -p /home/tester/.config/taylor-os
[ -n '$SETTINGS' ] && echo '$SETTINGS' > /home/tester/.config/taylor-os/settings.json
rm -rf /home/tester/qs && cp -a /repo/$CONF /home/tester/qs && chown -R tester:tester /home/tester
printf 'output HEADLESS-1 resolution ${W}x${HH}\n' > /tmp/sway.conf; chmod 644 /tmp/sway.conf
setpriv --reuid=tester --regid=tester --init-groups env HOME=/home/tester USER=tester TZ=America/New_York ${ENVS[*]:-} bash -c '
  cd ~; export XDG_RUNTIME_DIR=/tmp/xdg-tester; mkdir -p -m 700 \$XDG_RUNTIME_DIR
  eval \$(dbus-launch --sh-syntax)
  pipewire >/dev/null 2>&1 & sleep 1; wireplumber >/dev/null 2>&1 & pipewire-pulse >/dev/null 2>&1 &
  WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 sway -c /tmp/sway.conf >/tmp/sway.log 2>&1 &
  for i in \$(seq 1 30); do ls \$XDG_RUNTIME_DIR/wayland-* >/dev/null 2>&1 && break; sleep 0.3; done
  export WAYLAND_DISPLAY=\$(basename \$(ls \$XDG_RUNTIME_DIR/wayland-* | grep -v lock | head -1))
  QT_QUICK_BACKEND=software quickshell -p ~/qs > /out/quickshell.log 2>&1 &
  QS=\$!
  sleep $WAIT
  [ -n "$IPC" ] && { quickshell ipc --pid \$QS call $IPC >> /out/ipc.log 2>&1; sleep 1; }
  grim /out/shot-0.png
  prev=0
  for t in ${SHOTS[*]:-}; do sleep \$(python3 -c "print(max(0,\$t-\$prev))"); prev=\$t; grim /out/shot-\$t.png; done
  kill \$QS; wait \$QS 2>/dev/null
'
EOS
IMG=ghcr.io/guitarist777/taylor-os:latest; podman image exists localhost/tayloros-preview && IMG=localhost/tayloros-preview
podman run --rm --privileged -v "$REPO:/repo:ro" -v "$OUT:/out" "$IMG" bash /out/.run.sh > "$OUT/run.log" 2>&1
echo "--- quickshell log"; grep -vE '^\s*$' "$OUT/quickshell.log" | tail -40
ls "$OUT"/*.png 2>/dev/null
