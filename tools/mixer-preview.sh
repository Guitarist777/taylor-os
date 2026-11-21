#!/bin/bash
# A fast local try of the TaylorOS mixer (2026-11-21), like tools/local-preview.sh but with sound: PipeWire, WirePlumber
# and the PulseAudio side running with THIS checkout's mixer channels (files/system/etc/pipewire), two pretend outputs
# ("Speakers" and a "SteelSeries Arctis Nova Pro Wireless", both silent null sinks), her desktop in a screenless sway,
# and a scenario you write: a bash file run as her test account, with these helpers
#   tone NAME FREQ [ROLE] [AMPLITUDE]   play a test tone as an app called NAME (in the background); untone NAME stops it
#   ipc TARGET FUNCTION [ARGS]          quickshell ipc call ... (prints the answer)
#   shot NAME                           a screenshot, OUTDIR/NAME.png
#   click X Y | drag X1 Y1 X2 Y2 | scroll X Y N   the pointer (sway's seat cursor)
#   node NAME                           the PipeWire id of the node called NAME
#   wait_for "CMD" [SECONDS]            until CMD succeeds
# Run inside WSL (FedoraLinux-44): [EXTRA=/a/folder] bash tools/mixer-preview.sh OUTDIR SCENARIO [SIZE=WxH] [SETTINGS='{json}']
# (EXTRA: a folder of your own, seen read-only inside as /w)
set -u
OUT=$(realpath -m "$1"); SCEN=$(realpath -m "$2"); shift 2
W=1920; HH=1080; SETTINGS=""; GDB=""
for a in "$@"; do case "$a" in SIZE=*) s="${a#SIZE=}"; W="${s%x*}"; HH="${s#*x}" ;; SETTINGS=*) SETTINGS="${a#SETTINGS=}" ;; GDB=*) GDB=1 ;; esac; done
REPO=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$OUT" && chmod 777 "$OUT" && rm -f "$OUT"/*.log "$OUT"/*.png
cp "$SCEN" "$OUT/.scenario.sh"
cat > "$OUT/.helpers.sh" <<'EOS'
tone() { ( python3 -c '
import math,struct,sys
f=float(sys.argv[1]);a=float(sys.argv[2]);r=48000
one=b"".join(struct.pack("<hh",int(a*math.sin(2*math.pi*f*i/r)),int(a*math.sin(2*math.pi*f*i/r))) for i in range(r))
try:
    while True: sys.stdout.buffer.write(one)
except BrokenPipeError: pass' "$2" "${4:-8000}" | pw-play -a --format s16 --rate 48000 --channels 2 --media-role "${3:-Music}" -P "{ application.name = \"$1\" }" - ) >>/out/tones.log 2>&1 &
  eval "TONE_$1=\$!"; }
untone() { local p; eval "p=\${TONE_$1:-}"; [ -n "$p" ] && { pkill -P "$p"; kill "$p"; } 2>/dev/null; sleep 0.3; }
ipc() { quickshell ipc -p ~/qs call "$@" 2>&1; }
shot() { grim "/out/$1.png"; echo "shot $1"; }
click() { swaymsg -q seat - cursor set "$1" "$2"; sleep 0.15; swaymsg -q seat - cursor press button1; sleep 0.1; swaymsg -q seat - cursor release button1; sleep 0.3; }
drag() { swaymsg -q seat - cursor set "$1" "$2"; sleep 0.15; swaymsg -q seat - cursor press button1; sleep 0.15
  for i in 1 2 3 4 5 6 7 8 9 10; do swaymsg -q seat - cursor set $(( $1 + ($3 - $1) * i / 10 )) $(( $2 + ($4 - $2) * i / 10 )); sleep 0.05; done
  sleep 0.15; swaymsg -q seat - cursor release button1; sleep 0.4; }
scroll() { swaymsg -q seat - cursor set "$1" "$2"; sleep 0.1; local n=$3 b=button4; [ "$n" -lt 0 ] && { b=button5; n=$(( -n )); }
  for i in $(seq 1 $n); do swaymsg -q seat - cursor press $b; swaymsg -q seat - cursor release $b; sleep 0.05; done; sleep 0.3; }
node() { pw-dump | python3 -c "import json,sys; print(next((o['id'] for o in json.load(sys.stdin) if o['type'].endswith(':Node') and o.get('info',{}).get('props',{}).get('node.name')=='$1'), ''))"; }
wait_for() { local i; for i in $(seq 1 $(( ${2:-10} * 4 ))); do eval "$1" >/dev/null 2>&1 && return 0; sleep 0.25; done; echo "timed out: $1"; return 1; }
EOS
cat > "$OUT/.run.sh" <<EOS
set -u
command -v sway >/dev/null || dnf install -y -q --setopt=install_weak_deps=False sway grim dbus-daemon >/dev/null 2>&1
# the mixer's sound shaping needs these (in the image from the recipe; a preview image made before may lack them)
rpm -q ladspa-swh-plugins mysofa >/dev/null 2>&1 || dnf install -y -q --setopt=install_weak_deps=False ladspa-swh-plugins mysofa >/dev/null 2>&1
id tester >/dev/null 2>&1 || useradd -m tester
dbus-uuidgen > /etc/machine-id 2>/dev/null
cp -a /repo/files/system/etc/pipewire/. /etc/pipewire/
for f in /repo/files/system/usr/libexec/taylor-*; do cp "\$f" /usr/libexec/; chmod 755 "/usr/libexec/\$(basename "\$f")"; done
[ -d /repo/files/system/usr/share/taylor-os/mixer ] && { rm -rf /usr/share/taylor-os/mixer; cp -a /repo/files/system/usr/share/taylor-os/mixer /usr/share/taylor-os/; }
mkdir -p /home/tester/.config/taylor-os
# no systemd user session in here: a stand-in systemctl runs the mixer's sound-shaping units (taylor-mixer-fx@X) itself
mkdir -p /tmp/mixer-bin; cat > /tmp/mixer-bin/systemctl <<'EOT'
#!/bin/bash
u=""; a=""; for x in "\$@"; do case "\$x" in --user) ;; start|stop|restart) a=\$x ;; taylor-mixer-fx@*) u=\${x#taylor-mixer-fx@}; u=\${u%.service} ;; esac; done
[ -z "\$u" ] && exec /usr/bin/systemctl "\$@"
pf=/tmp/fx-\$u.pid; conf=\$HOME/.config/taylor-os/mixer-fx/\$u.conf
running() { [ -f \$pf ] && kill -0 \$(cat \$pf) 2>/dev/null; }
case \$a in
  stop) running && kill \$(cat \$pf); rm -f \$pf ;;
  start) running || { setsid -f bash -c "echo \\$\\$ > \$pf; exec pipewire -c \$conf" >>/out/fx-\$u.log 2>&1; } ;;
  restart) running && { kill \$(cat \$pf); sleep 0.3; }; setsid -f bash -c "echo \\$\\$ > \$pf; exec pipewire -c \$conf" >>/out/fx-\$u.log 2>&1 ;;
esac
echo "systemctl \$a \$u" >> /out/systemctl.log
EOT
chmod 755 /tmp/mixer-bin/systemctl
[ -n '$SETTINGS' ] && echo '$SETTINGS' > /home/tester/.config/taylor-os/settings.json
rm -rf /home/tester/qs && cp -a /repo/files/system/usr/share/taylor-os/quickshell /home/tester/qs && chown -R tester:tester /home/tester
printf 'output HEADLESS-1 resolution ${W}x${HH}\nseat * hide_cursor 0\nfor_window [title="^Mixer\$"] floating enable, resize set 700 486, move position center\n' > /tmp/sway.conf; chmod 644 /tmp/sway.conf
setpriv --reuid=tester --regid=tester --init-groups env HOME=/home/tester USER=tester TZ=America/New_York PATH=/tmp/mixer-bin:\$PATH bash -c '
  cd ~; export XDG_RUNTIME_DIR=/tmp/xdg-tester; mkdir -p -m 700 \$XDG_RUNTIME_DIR
  eval \$(dbus-launch --sh-syntax)
  pipewire >/out/pipewire.log 2>&1 & sleep 1; wireplumber >/out/wireplumber.log 2>&1 & pipewire-pulse >/dev/null 2>&1 & sleep 1.5
  pactl load-module module-null-sink sink_name=pretend_speakers "sink_properties=device.description=Speakers priority.session=1500" >/dev/null
  pactl load-module module-null-sink sink_name=pretend_arctis "sink_properties=device.description=\"SteelSeries Arctis Nova Pro Wireless\" priority.session=1400" >/dev/null
  pactl load-module module-null-sink sink_name=pretend_mic media.class=Audio/Source/Virtual "sink_properties=device.description=Microphone" >/dev/null
  WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 sway -c /tmp/sway.conf >/out/sway.log 2>&1 &
  for i in \$(seq 1 30); do ls \$XDG_RUNTIME_DIR/wayland-* >/dev/null 2>&1 && break; sleep 0.3; done
  export WAYLAND_DISPLAY=\$(basename \$(ls \$XDG_RUNTIME_DIR/wayland-* | grep -v lock | head -1))
  export SWAYSOCK=\$(ls \$XDG_RUNTIME_DIR/sway-ipc.* | head -1)
  if [ -n "$GDB" ]; then QT_QUICK_BACKEND=software gdb -q -batch -ex run -ex "thread apply all bt 25" --args quickshell -p ~/qs > /out/quickshell.log 2>&1 &
  else QT_QUICK_BACKEND=software quickshell -p ~/qs > /out/quickshell.log 2>&1 & fi
  export QS=\$!
  sleep 5
  . /out/.helpers.sh
  . /out/.scenario.sh > /out/scenario.log 2>&1
  kill \$QS; wait \$QS 2>/dev/null
'
EOS
IMG=ghcr.io/guitarist777/taylor-os:latest; podman image exists localhost/tayloros-preview && IMG=localhost/tayloros-preview
podman run --rm --privileged -v "$REPO:/repo:ro" -v "$OUT:/out" ${EXTRA:+-v "$EXTRA:/w:ro"} "$IMG" bash /out/.run.sh > "$OUT/run.log" 2>&1
echo "--- scenario"; cat "$OUT/scenario.log"
echo "--- quickshell log"; grep -vE '^\s*$' "$OUT/quickshell.log" | grep -v "Pipewire: Received" | tail -40
ls "$OUT"/*.png 2>/dev/null
