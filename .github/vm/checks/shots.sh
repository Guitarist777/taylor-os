# Screenshots (her ask 2026-11-27): Print Screen = the whole screen, Windows key + Shift + S = drag over a part,
# Alt + Print Screen = the window she is in. Each is saved to Pictures/Screenshots and copied for pasting.
. .github/vm/checks/lib.sh
expect shots 8
W=1280; HH=800
D='"$(/usr/libexec/taylor-screenshot where)"'
NEWEST="ls -t $D/*.png 2>/dev/null | head -1"
SIZE="python3 -c 'import struct,sys; b=open(sys.argv[1],\"rb\").read(24); print(\"PNG\", *struct.unpack(\">II\", b[16:24]))' \"\$($NEWEST)\""
COUNT="ls $D/*.png 2>/dev/null | wc -l"

vm shots-start \
  "$WH" \
  "$(ok 'grim, slurp and wl-copy are on the PC' "command -v grim && command -v slurp && command -v wl-copy")" \
  "$(ok 'the screenshot keys are bound in Hyprland' "hyprctl -j binds | grep -c taylor-screenshot | grep -qx 3")" \
  "rm -rf $D; hyprctl -j binds | grep -B2 -A2 taylor-screenshot | head -30"
s=$(screen shots-start); [ -n "$s" ] && { W=${s% *}; HH=${s#* }; }

# Print Screen: the whole screen
$V key print; sleep 3
vm shots-print \
  "$(ok 'Print Screen saves a picture in Pictures/Screenshots' "[ \$($COUNT) = 1 ]")" \
  "$(ok '...the size of the whole screen' "$SIZE | grep -qx 'PNG $W $HH'")" \
  "$(ok '...and copies it, ready to paste' "wl-paste --list-types | grep -qx image/png")" \
  "$SIZE; $NEWEST; wl-paste --list-types"
shot shots-1-print

# Alt + Print Screen: only the window she is in (a terminal, floating at its own size)
$V key meta_l-ret; sleep 3
$V key meta_l-v; sleep 1
$V key alt-print; sleep 3
vm shots-window \
  "$(ok 'Alt + Print Screen saves just the window she is in' "[ \$($COUNT) = 2 ] && python3 -c 'import json,subprocess,sys; w=json.loads(subprocess.run([\"hyprctl\",\"-j\",\"activewindow\"],capture_output=True,text=True).stdout); print(\"WIN\", *w[\"size\"]); sys.exit(0)' | grep -qx \"WIN \$($SIZE | cut -d\" \" -f2-)\"")" \
  "$SIZE; hyprctl -j activewindow | grep -A1 '\"size\"'"
$V key meta_l-q; sleep 2

# Windows key + Shift + S: drag over a part; Esc first cancels and saves nothing
$V key meta_l-shift-s; sleep 2
shot shots-2-area-overlay
$V key esc; sleep 2
vm shots-cancel "$(ok 'Esc on the drag-over-a-part screen saves nothing' "[ \$($COUNT) = 2 ] && ! pgrep -x slurp")" "$COUNT; pgrep -a slurp"
$V key meta_l-shift-s; sleep 2
$V drag 200 150 600 450 $W $HH; sleep 3
vm shots-area \
  "$(ok 'Windows key + Shift + S then a drag saves the part she dragged over' "[ \$($COUNT) = 3 ] && $SIZE | awk '{exit !(\$2>=380 && \$2<=420 && \$3>=280 && \$3<=320)}'")" \
  "$SIZE; ls -l $D"
shot shots-3-after
