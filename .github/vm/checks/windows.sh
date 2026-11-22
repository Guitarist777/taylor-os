# Phase 2, her windows and workspaces (2026-11-21): four windows into the four quarters edge to edge, true full screen
# with the dock and clock stepping away and coming back at the edges, a drag to the left edge with the dotted outline,
# a snapped window dragged away floats again, workspaces slide with the dots following, less motion, the scheme colour.
. .github/vm/checks/lib.sh
expect windows 33
QSLOG='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'
# the helper that reads Hyprland's real state, sent into the virtual PC in one line
HELPER=$(gzip -9c .github/vm/checks/windows_helper.py | base64 -w0)
W=1280; HH=800

vm windows-start \
  "echo $HELPER | base64 -d | gunzip > /tmp/w.py && echo helper-ok" \
  "$WH" \
  "$(ok 'her windows file is loaded in Hyprland' "hyprctl repl 'taylor and taylor.version' | grep -q 2026-11-21")" \
  "$(ok 'Hyprland reports no settings errors with her windows' "hyprctl -j configerrors | tr -d ' \t\n' | grep -qxE '\[(\"\")?\]'")" \
  "$(ok 'the workspace dots are under the dock' "python3 /tmp/w.py layer taylor-workspaces present")" \
  "hyprctl repl 'tostring(taylor_windows_error)'" \
  "hyprctl repl 'taylor.tail()'" \
  "hyprctl repl 'tostring(io) .. \" \" .. tostring(dofile)'" \
  "hyprctl getoption general.border_size; hyprctl getoption general.col.active_border; hyprctl getoption decoration.rounding" \
  "hyprctl animations | grep -iA4 'workspaces'" \
  "hyprctl -j configerrors" \
  "$QSLOG | grep -E 'taylor-windows|WARN|ERROR' | tail -20"
s=$(screen windows-start); [ -n "$s" ] && { W=${s% *}; HH=${s#* }; }
echo "screen $W x $HH"
shot windows-0-empty

# Files from the dock opens as a plain maximise (inside the dock's strip); a click on the dock still works with the
# left-button binds the drag watcher uses
vm windows-dockxy "python3 /tmp/w.py dockxy"
xy=$(tr -d '\r' < out/windows-dockxy.txt | grep -oE 'DOCKXY [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
$V click ${xy% *} ${xy#* } $W $HH; sleep 6
shot windows-0-files
vm windows-files \
  "$(ok 'a click on the dock still works (Files opens)' "hyprctl -j clients | grep -qi dolphin")" \
  "$(ok 'Files opens as a plain maximise inside the dock strip' "python3 /tmp/w.py maxed dolphin")" \
  "python3 /tmp/w.py info" "hyprctl repl 'taylor.state()'"
$V key meta_l-q; sleep 2

# four windows, one into each quarter with the keys (Windows key + Enter opens a terminal)
for q in "left up" "right up" "left down" "right down"; do
  $V key meta_l-ret; sleep 3
  for k in $q; do $V key "meta_l-$k"; sleep 0.8; done
  sleep 1
done
sleep 1
shot windows-1-quarters
vm windows-quarters \
  "python3 /tmp/w.py info" \
  "$(ok 'four windows tile the screen exactly, edge to edge with no gaps' "python3 /tmp/w.py quarters")" \
  "$(ok 'the dock steps away when snapped windows reach the top' "python3 /tmp/w.py layer taylor-dock absent")" \
  "$(ok 'the window bar steps away with the dock' "python3 /tmp/w.py layer taylor-windowbar absent")" \
  "hyprctl repl 'taylor.state()'" \
  "\$Q call windows state"

# true full screen (Windows key + F) on the last one
$V key meta_l-f; sleep 2
shot windows-2-fullscreen
vm windows-full \
  "$(ok 'Windows key + F puts the window in true full screen' "python3 /tmp/w.py fullscreen")" \
  "$(ok 'the dock is not shown over a full-screen window' "python3 /tmp/w.py layer taylor-dock absent")" \
  "$(ok 'the clock and tray are not shown over a full-screen window' "python3 /tmp/w.py layer taylor-tray absent")"
$V move $((W/2)) 0 $W $HH; sleep 2
shot windows-3-dock-back
vm windows-dock-back \
  "$(ok 'the pointer at the top edge brings the dock back' "python3 /tmp/w.py layer taylor-dock present")" \
  "hyprctl repl 'taylor.state()'" "\$Q call windows state"
$V move $((W/2)) $((HH/2)) $W $HH; sleep 2
vm windows-dock-leaves \
  "$(ok 'the dock leaves again when the pointer goes down' "python3 /tmp/w.py layer taylor-dock absent")"
$V move $((W-10)) $((HH-1)) $W $HH; sleep 2
shot windows-4-clock-back
vm windows-clock-back \
  "$(ok 'the pointer at the bottom edge brings the clock and tray back' "python3 /tmp/w.py layer taylor-tray present")"
$V move $((W/2)) $((HH/2)) $W $HH; sleep 1
$V key meta_l-f; sleep 1.5

# the whole screen as a snap (Windows key + Down floats it, + Up fills the screen)
$V key meta_l-down; sleep 1.5
$V key meta_l-up; sleep 1.5
shot windows-5-whole-screen
vm windows-whole \
  "$(ok 'Windows key + Up fills the screen edge to edge' "python3 /tmp/w.py active F")" \
  "python3 /tmp/w.py info"
$V key meta_l-down; sleep 1.5

# drag the floating window to the left edge with the Windows key held: the dotted outline, then the left half
vm windows-before-drag "python3 /tmp/w.py active F || true"
r=$(tr -d '\r' < out/windows-before-drag.txt | grep -oE 'info: active \([0-9-]+, [0-9-]+, [0-9]+, [0-9]+\)' | grep -oE '[0-9-]+' | tr '\n' ' ')
set -- $r; cx=$(( ${1:-400} + ${3:-400}/2 )); cy=$(( ${2:-200} + ${4:-300}/2 ))
echo "dragging from $cx,$cy"
$V drag $cx $cy 3 $((HH/2)) $W $HH meta_l &
dp=$!; sleep 2.3
shot windows-6-drag-mid
wait $dp; sleep 2
shot windows-7-dropped
vm windows-drag \
  "$(ok 'a window dragged to the left edge snaps to the left half' "python3 /tmp/w.py active L")" \
  "$(ok 'the dotted outline showed while dragging' "$QSLOG | grep -q 'drag zone L'")" \
  "$(ok 'the dotted outline is a layer on the screen for a zone' "\$Q call windows preview TR $((W/2)) 0 $((W/2)) $((HH/2)) >/dev/null; sleep 1; python3 /tmp/w.py layer taylor-snap present")" \
  "hyprctl repl 'taylor.tail()'" "hyprctl repl 'taylor.state()'" \
  "$QSLOG | grep taylor-windows | tail -12"
shot windows-6b-outline-top-right
vm windows-outline-gone \
  "$(ok 'the dotted outline goes when the drag ends' "\$Q call windows preview none 0 0 0 0 >/dev/null; sleep 1; python3 /tmp/w.py layer taylor-snap absent")"
if ! tr -d '\r' < out/windows-drag.txt | grep -qE '^(tester@[^ ]* )?PASS a window dragged'; then
  # a second try with the button binds (not counted): says whether they are what the watcher needs
  vm windows-drag2-prep "hyprctl dispatch 'hl.dsp.window.move({ x = 300, y = 200 })'"
  $V drag 500 350 3 $((HH/2)) $W $HH meta_l; sleep 2
  vm windows-drag2 "python3 /tmp/w.py active L && echo 'info: the second try snapped' || echo 'info: the second try did not snap'" "hyprctl repl 'taylor.tail()'"
fi

# a snapped window dragged away floats again at its own size
$V drag 200 $((HH/2)) $((W/2)) $((HH/2 + 40)) $W $HH meta_l; sleep 2
shot windows-8-dragged-away
vm windows-away \
  "$(ok 'a snapped window dragged away floats again' "python3 /tmp/w.py floating && hyprctl repl 'taylor.tail()' | tail -3 | grep -q unsnap")" \
  "hyprctl repl 'taylor.tail()'"

# workspaces: Windows key + 2 and back; a picture mid-slide
$V key meta_l-2; sleep 0.18
shot windows-9-slide-mid
sleep 2
shot windows-10-workspace-2
vm windows-ws2 \
  "$(ok 'Windows key + 2 goes to workspace 2' "hyprctl -j activeworkspace | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)[\"id\"] == 2 else 1)'")" \
  "$(ok 'the workspace dots follow' "$QSLOG | grep -q 'taylor-windows: workspace 2'")"
$V key meta_l-1; sleep 2
shot windows-11-workspace-1
vm windows-ws1 \
  "$(ok 'Windows key + 1 comes back to workspace 1' "hyprctl -j activeworkspace | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)[\"id\"] == 1 else 1)'")"

# switching windows (her ask 2026-11-22, the Mac's Cmd + Tab) and Show desktop (Windows key + D)
ACTIVE="hyprctl -j activewindow | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"class\",\"\"))'"
ONWS1="hyprctl -j clients | python3 -c 'import json,sys; print(sum(1 for c in json.load(sys.stdin) if c[\"workspace\"][\"id\"] == 1))'"
vm windows-sw-setup \
  "hyprctl eval 'hl.exec_cmd(\"kitty --class sw_one\")'; sleep 4; hyprctl eval 'hl.exec_cmd(\"kitty --class sw_two\")'; sleep 4; $ACTIVE"
$V key meta_l-tab; sleep 2
shot windows-12-switched
vm windows-sw \
  "$(ok 'Windows key + Tab switches to the window she used before (like Cmd + Tab)' "[ \"\$($ACTIVE)\" = sw_one ]")" \
  "$(ok 'the window switcher loaded with no QML errors' "! $QSLOG | grep -iE 'Switcher.qml' | grep -qiE 'error|TypeError|ReferenceError|not defined'")" \
  "$QSLOG | grep taylor-switcher | tail -3"
$V key alt_l-tab; sleep 2
vm windows-alttab \
  "$(ok 'Alt + Tab switches back the same way' "[ \"\$($ACTIVE)\" = sw_two ]")" \
  "echo on workspace 1: \$($ONWS1)"
$V key meta_l-d; sleep 2
shot windows-13-show-desktop
vm windows-desk \
  "$(ok 'Windows key + D shows the desktop (her windows step aside)' "[ \"\$($ONWS1)\" = 0 ]")" \
  "hyprctl repl 'taylor.tail()' | tail -3"
$V key meta_l-d; sleep 2
vm windows-desk-back \
  "$(ok 'Windows key + D again brings her windows back' "[ \"\$($ONWS1)\" -ge 2 ]")" \
  "pkill -f 'kitty --class sw_'; sleep 1"

# an app's own full-screen square (her ask 2026-11-22): a window that asks to be maximised (what its square button does)
# fills the whole screen; asking again puts it back. The test window asks at 3 s and again at 10 s.
MAXW="hyprctl -j clients | python3 -c 'import json,sys; c=[c for c in json.load(sys.stdin) if c[\"class\"]==\"maxtest\"]; print(c[0][\"size\"][0] if c else 0)'"
SCRW="hyprctl -j monitors | python3 -c 'import json,sys; m=json.load(sys.stdin)[0]; print(int(m[\"width\"]/m[\"scale\"]))'"
vm windows-square \
  "printf '%s\\n' 'import gi' 'gi.require_version(\"Gtk\", \"3.0\")' 'from gi.repository import Gtk, GLib' 'GLib.set_prgname(\"maxtest\")' 'w = Gtk.Window(title=\"maxtest\")' 'w.set_default_size(500, 300)' 'w.show_all()' 'GLib.timeout_add(3000, lambda: w.maximize() or False)' 'GLib.timeout_add(10000, lambda: w.maximize() or False)' 'GLib.timeout_add(16000, Gtk.main_quit)' 'Gtk.main()' > /tmp/maxtest.py" \
  "hyprctl eval 'hl.exec_cmd(\"python3 /tmp/maxtest.py\")'; sleep 6; echo width \$($MAXW) of \$($SCRW)" \
  "$(ok 'an app clicking its full-screen square fills the whole screen' "[ \"\$($MAXW)\" = \"\$($SCRW)\" ]")" \
  "sleep 6; echo width \$($MAXW)" \
  "$(ok '...and clicking it again puts it back to its own size' "w=\$($MAXW); [ \"\$w\" -gt 0 ] && [ \"\$w\" -lt \"\$($SCRW)\" ]")" \
  "hyprctl repl 'taylor.tail()' | grep square | tail -3"

# less motion and her scheme reach Hyprland without a reload
vm windows-look \
  "python3 /tmp/w.py settings reduceMotion=true scheme=night; sleep 4" \
  "$(ok 'less motion makes workspaces fade instead of slide' "python3 /tmp/w.py anim workspaces fade")" \
  "$(ok 'the focused outline takes her scheme colour' "hyprctl getoption general.col.active_border | grep -qi 8fb5a1")" \
  "hyprctl animations | grep -iA4 'name: workspaces'" "hyprctl getoption general.col.active_border" \
  "python3 /tmp/w.py settings reduceMotion=false scheme=taylor; sleep 4" \
  "$(ok 'Hyprland shows no error notices from her windows' "hyprctl repl '#hl.notification.get()' | grep -qx 0")" \
  "hyprctl repl '#hl.notification.get()'" "python3 /tmp/w.py anim workspaces slide; python3 /tmp/w.py anim windows popin" \
  "hyprctl getoption general.col.active_border" "hyprctl repl 'taylor.tail()'"
