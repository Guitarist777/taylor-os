# Screenshots (her asks 2026-11-27): Print Screen = the whole screen, Windows key + Shift + S = drag over a part,
# Alt + Print Screen = the window she is in. Like the Mac, each shows small in the bottom right (Shot.qml): dragged
# into an app it is NOT saved; left alone it is saved to Pictures/Screenshots; a click saves and opens it; its x throws
# it away. Every step uses the real keys and the real mouse.
. .github/vm/checks/lib.sh
expect shots 20
W=1280; HH=800
HELPER=$(gzip -9c .github/vm/checks/shots_helper.py | base64 -w0)
D='"$(/usr/libexec/taylor-screenshot where)"'
M='"$XDG_RUNTIME_DIR/taylor-shots"'
SAVED="ls $D/*.png 2>/dev/null | wc -l"
INMEM="ls $M/*.png 2>/dev/null | wc -l"
NEWEST="ls -t $D/*.png 2>/dev/null | head -1"
SIZE="python3 -c 'import struct,sys; b=open(sys.argv[1],\"rb\").read(24); print(\"PNG\", *struct.unpack(\">II\", b[16:24]))' \"\$($NEWEST)\""
LAYER="python3 /tmp/s.py layer"
# the test's own shell is not inside her desktop: point it at Hyprland's Wayland socket (wl-paste, the test window)
WL='export WAYLAND_DISPLAY=$(cd "$XDG_RUNTIME_DIR" && ls wayland-? 2>/dev/null | head -1)'
QSLOG='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1 | grep taylor-shot | tail -6'
shotxy() { tr -d '\r' < "out/$1.txt" | grep -oE 'SHOT [0-9]+ [0-9]+ [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-; }

vm shots-start \
  "echo $HELPER | base64 -d | gunzip > /tmp/s.py && echo helper-ok" \
  "$WH" \
  "$(ok 'grim, slurp and wl-copy are on the PC' "command -v grim && command -v slurp && command -v wl-copy")" \
  "$(ok 'the kernel leaves Alt + Print Screen to the desktop (SysRq keys off)' "grep -qx 0 /proc/sys/kernel/sysrq")" \
  "$(ok 'the screenshot keys are bound in Hyprland' "hyprctl -j binds | grep -cE '\"key\": \"(Print|Sys_Req)\"' | grep -qx 3")" \
  "rm -rf $D $M; hyprctl binds | grep -B3 -A6 -E 'key: (Print|Sys_Req|S)$' | head -40"
s=$(screen shots-start); [ -n "$s" ] && { W=${s% *}; HH=${s#* }; }

# Print Screen: the whole screen, shown small first (not saved yet), then saved when it goes
$V key print; sleep 2
shot shots-1-thumb
vm shots-print \
  "$WL" \
  "$(ok 'Print Screen shows the little picture in the bottom right' "$LAYER | grep -qv none")" \
  "$(ok '...not saved yet while it shows' "[ \$($SAVED) = 0 ] && [ \$($INMEM) = 1 ]")" \
  "$(ok '...and copied, ready to paste' "wl-paste --list-types | grep -qx image/png")" \
  "$LAYER" "$INMEM; $SAVED; wl-paste --list-types" "$QSLOG"
sleep 7
vm shots-print-kept \
  "$(ok 'left alone, it goes and is saved in Pictures/Screenshots' "$LAYER | grep -q none && [ \$($SAVED) = 1 ] && [ \$($INMEM) = 0 ]")" \
  "$(ok '...the size of the whole screen' "$SIZE | grep -qx 'PNG $W $HH'")" \
  "$SIZE; $NEWEST; $LAYER" "$QSLOG"

# Alt + Print Screen: only the window she is in (a terminal, floating at its own size)
$V key meta_l-ret; sleep 3
$V key meta_l-v; sleep 1
$V key alt-print; sleep 8
vm shots-window \
  "$(ok 'Alt + Print Screen saves just the window she is in' "[ \$($SAVED) = 2 ] && python3 -c 'import json,subprocess; w=json.loads(subprocess.run([\"hyprctl\",\"-j\",\"activewindow\"],capture_output=True,text=True).stdout); print(\"WIN\", *w[\"size\"])' | grep -qx \"WIN \$($SIZE | cut -d\" \" -f2-)\"")" \
  "$SIZE; hyprctl -j activewindow | grep -A1 '\"size\"'"
$V key meta_l-q; sleep 2

# Windows key + Shift + S: Esc cancels and saves nothing; a drag saves the part dragged over
$V key meta_l-shift-s; sleep 2
shot shots-2-area-overlay
$V key esc; sleep 2
vm shots-cancel "$(ok 'Esc on the drag-over-a-part screen saves nothing' "[ \$($SAVED) = 2 ] && [ \$($INMEM) = 0 ] && ! pgrep -x slurp")" "$SAVED; $INMEM; pgrep -a slurp"
$V key meta_l-shift-s; sleep 2
$V drag 200 150 600 450 $W $HH; sleep 8
vm shots-area \
  "$(ok 'Windows key + Shift + S then a drag saves the part she dragged over' "[ \$($SAVED) = 3 ] && $SIZE | awk '{exit !(\$2>=380 && \$2<=420 && \$3>=280 && \$3<=320)}'")" \
  "$SIZE; ls -l $D"

# drag the little picture into an app: it goes there and is NOT saved (a test window that takes dropped files)
vm shots-target \
  "$WL" \
  "python3 /tmp/s.py droptarget; rm -f /tmp/drop.txt; (setsid quickshell -p /tmp/droptest >/tmp/droptest.log 2>&1 &); sleep 4" \
  "hyprctl dispatch movewindowpixel 'exact 80 120,title:^(droptest)\$' >/dev/null; sleep 1; python3 /tmp/s.py drop"
read DX DY < <(tr -d '\r' < out/shots-target.txt | grep -oE 'DROP [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
$V key print; sleep 2
vm shots-drag-where "$LAYER"
read SX SY SW SHH < <(shotxy shots-drag-where)
echo "drag from the picture at $SX $SY ($SW x $SHH) to the app at $DX $DY"
$V drag $((SX + SW / 2)) $((SY + SHH / 2)) "${DX:-300}" "${DY:-300}" $W $HH; sleep 4
shot shots-3-dropped
vm shots-dropped \
  "$(ok 'dragging the little picture into an app hands it the picture file' "grep -qE 'URLS file:///.*taylor-shots/Screenshot.*\.png' /tmp/drop.txt")" \
  "$(ok '...and the little picture goes' "$LAYER | grep -q none")" \
  "cat /tmp/drop.txt; cat /tmp/droptest.log | tail -5" "$QSLOG"
sleep 7
vm shots-dropped-later \
  "$(ok '...and it is not saved to Pictures/Screenshots' "[ \$($SAVED) = 3 ]")" "$SAVED; ls $M"

# (the one given to the app stays in the memory folder for the app to read: 1 file there from here on)
# its x (on hover) throws it away
$V key print; sleep 2
vm shots-x-where "$LAYER"
read SX SY SW SHH < <(shotxy shots-x-where)
$V move $((SX + SW / 2)) $((SY + SHH / 2)) $W $HH; sleep 0.6
shot shots-4-hover-x
$V click $((SX + 12 + 6 + 12)) $((SY + 12 + 6 + 12)) $W $HH; sleep 1.5
vm shots-x \
  "$(ok 'the x on the little picture throws it away' "$LAYER | grep -q none && [ \$($INMEM) = 1 ]")" \
  "$(ok '...nothing saved' "sleep 6; [ \$($SAVED) = 3 ]")" "$INMEM; $SAVED" "$QSLOG"

# let go over the bare desktop: nothing took it, so it stays and is saved as usual
vm shots-target-close "pkill -f 'quickshell -p /tmp/droptest'; sleep 1; hyprctl clients | grep -c '^Window' || true"
$V key print; sleep 2
vm shots-desk-where "$LAYER"
read SX SY SW SHH < <(shotxy shots-desk-where)
$V drag $((SX + SW / 2)) $((SY + SHH / 2)) 640 470 $W $HH; sleep 1.5
vm shots-desk \
  "$(ok 'let go over the bare desktop, the little picture stays' "$LAYER | grep -qv none")" "$LAYER" "$QSLOG"
sleep 8
vm shots-desk-later "$(ok '...and is saved when it goes' "[ \$($SAVED) = 4 ]")" "$SAVED"

# a click on it saves it at once and opens it
$V key print; sleep 2
vm shots-click-where "$LAYER"
read SX SY SW SHH < <(shotxy shots-click-where)
$V click $((SX + SW / 2)) $((SY + SHH / 2)) $W $HH; sleep 4
shot shots-5-opened
vm shots-click \
  "$(ok 'a click on the little picture saves it straight away' "$LAYER | grep -q none && [ \$($SAVED) = 5 ]")" \
  "$(ok '...and opens it' "pgrep -af 'Pictures/Screenshots/Screenshot 20' | grep -v pgrep")" \
  "hyprctl clients | grep -E 'class|title'" "pgrep -af Screenshot" "$QSLOG"
$V key meta_l-q; sleep 1
vm shots-end "pkill -f 'quickshell -p /tmp/droptest'; true"
