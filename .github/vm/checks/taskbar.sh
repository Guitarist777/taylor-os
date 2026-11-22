# The taskbar (2026-11-21): her icon set is in the image and used; the bar is up; a name shows under it on hover;
# Browser splays its three browsers out below the bar (screenshots mid-way and settled); picking one opens it, the bar
# remembers it (Prefs.lastBrowser) and shows it, and it becomes the PC's default browser (and a default changed elsewhere
# moves the slot: her call 2026-11-21, the two follow each other); the Terminal slot opens kitty and its running dot follows.
# Every click is a real pointer click at the slot's place on the screen (the dock logs where its slots are).
. .github/vm/checks/lib.sh
expect taskbar 28
QL='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'

vm taskbar-1 \
  "$WH" \
  "$(ok 'the dock is on her screen' "hyprctl layers | grep -q taylor-dock")" \
  "$(ok 'her icon set is in the image with its licence and credit' "test -f /usr/share/icons/Slot-Dark-Icons/index.theme && test -f /usr/share/icons/Slot-Dark-Icons/LICENSE && grep -q L4ki /usr/share/icons/Slot-Dark-Icons/TAYLOR-OS-NOTE.txt")" \
  "$(ok 'the desktop uses her icon set and no drawn icons' "grep -q '^//@ pragma IconTheme Slot-Dark-Icons' /usr/share/taylor-os/quickshell/shell.qml && ! ls /usr/share/taylor-os/quickshell/icons/*.svg 2>/dev/null | grep -q .")" \
  "$(ok 'the dock loaded with no QML errors' "! $QL | grep -iE 'Dock.qml|Tray.qml' | grep -qiE 'error|TypeError|ReferenceError|not defined|Unable'")" \
  "$QL | grep 'taylor-dock' | tail -12" \
  "$QL | grep -oE 'slots at y=[0-9]+ x=[0-9,]+' | tail -1 | sed 's/^/DOCK/'" \
  "hyprctl layers | grep -E 'taylor-dock' ; hyprctl -j monitors | grep -E '\"(width|height|reserved)\"' -A0" \
  "systemctl --user status taylor-apps-setup.service --no-pager 2>&1 | head -8; tail -15 ~/.local/state/taylor-os/apps-setup.log 2>&1" \
  "/usr/libexec/taylor-dock-apps | tr '\n' ' '; echo"
read SW SH <<< "$(screen taskbar-1)"; SW=${SW:-1280}; SH=${SH:-800}
DOCK=$(tr -d '\r' < out/taskbar-1.txt | grep -oE 'DOCKslots at y=[0-9]+ x=[0-9,]+' | tail -1)
DY=$(echo "$DOCK" | sed -E 's/.*y=([0-9]+).*/\1/')
XS=($(echo "$DOCK" | sed -E 's/.*x=//' | tr ',' ' '))
echo "screen ${SW}x${SH}; dock y=$DY; slots ${XS[*]}"
BX=${XS[2]}; TX=${XS[3]}           # Browser and Terminal (0 is the dial)
shot taskbar-1-bar

# the name under the bar on hover
$V move "$BX" "$DY" "$SW" "$SH"; sleep 1.5
shot taskbar-2-hover
$V move "$BX" $((DY + 300)) "$SW" "$SH"; sleep 0.5

# Firefox comes with Bazzite (its first start installs it); wait for it so a browser can really open
vm taskbar-wait \
  "for i in \$(seq 1 90); do flatpak info org.mozilla.firefox >/dev/null 2>&1 && break; sleep 10; done; flatpak list --app --columns=application | tr '\n' ' '; echo" \
  "sleep 25; $QL | grep 'on this PC' | tail -1"

# Browser: the splay, mid-way and settled
$V click "$BX" "$DY" "$SW" "$SH"
shot taskbar-3-splay-midway
sleep 1
shot taskbar-4-splay-settled
vm taskbar-splay \
  "$(ok 'a click on Browser splays its apps out' "$QL | grep -q 'taylor-dock: splay browser' && hyprctl layers | grep -q taylor-dock-splay")" \
  "$QL | grep -E 'splay|name under' | tail -3"
# Firefox is the middle one: straight down, 74 px (the tour's arc at this screen's size: 1 at 800 tall)
S=$(python3 -c "print(max(1, min(1.5, $SH / 864)))")
FX=$BX; FY=$(python3 -c "print(round($DY + 74 * $S))")
$V click "$FX" "$FY" "$SW" "$SH"
sleep 1
shot taskbar-5-picked
sleep 20
shot taskbar-6-firefox-open
vm taskbar-pick \
  "$(ok 'picking Firefox opens it' "$QL | grep -q 'taylor-dock: launch firefox' && pgrep -u tester -f 'firefox' >/dev/null")" \
  "$(ok 'the Browser slot remembers Firefox' "grep -q '\"lastBrowser\": *\"firefox\"' ~/.config/taylor-os/settings.json")" \
  "$(ok 'picking Firefox makes it the PC default browser' "test \"\$(xdg-settings get default-web-browser)\" = org.mozilla.firefox.desktop")" \
  "$(ok 'the splay folded away after the pick' "$QL | grep -q 'taylor-dock: fold browser' && ! hyprctl layers | grep -q taylor-dock-splay")" \
  "$(ok 'the dock logs the running apps' "$QL | grep -q 'taylor-dock: windows \['")" \
  "$QL | grep -E 'taylor-dock: (picked|launch|fold|windows)' | tail -6" \
  "hyprctl clients | grep -E 'class:|title:' | head -10"

# Terminal: kitty opens and its running dot follows
$V click "$TX" "$DY" "$SW" "$SH"
sleep 8
shot taskbar-7-terminal
vm taskbar-term \
  "$(ok 'the Terminal slot opens kitty' "pgrep -u tester -x kitty >/dev/null")" \
  "$(ok 'while an app opens its dock icon breathes (no loading dots)' "$QL | grep -q 'terminal opening: its icon breathes' && ! grep -q 'id: dots' /usr/share/taylor-os/quickshell/Dock.qml")" \
  "$(ok 'the terminal copies and pastes like Windows (Ctrl+C/V, select copies)' "grep -q '^map ctrl+v paste_from_clipboard' /etc/xdg/kitty/kitty.conf && kitty +runpy 'from kitty.cli import create_default_opts; print(create_default_opts().copy_on_select)' 2>/dev/null | grep -q clipboard")" \
  "$(ok 'the terminal has her icon (D: the small window with a blue title bar)' "cmp -s /usr/share/icons/Slot-Dark-Icons/apps/48/kitty.svg /usr/share/icons/Slot-Dark-Icons/apps/48/yakuake.svg")" \
  "$(ok 'her two cursor sets are in the image (White and Black, both formats)' "test -f /usr/share/icons/TAYLOR-White/manifest.hl && test -e /usr/share/icons/TAYLOR-White/cursors/left_ptr && test -e /usr/share/icons/TAYLOR-White/cursors/nesw-resize && test -f /usr/share/icons/TAYLOR-Black/manifest.hl && test -e /usr/share/icons/TAYLOR-Black/cursors/left_ptr")" \
  "$(ok 'her cursor pick switches everywhere (Black, then White again)' "/usr/libexec/taylor-cursor black && grep -qx Inherits=TAYLOR-Black ~/.local/share/icons/default/index.theme && /usr/libexec/taylor-cursor white && grep -qx Inherits=TAYLOR-White ~/.local/share/icons/default/index.theme && gsettings get org.gnome.desktop.interface cursor-theme | grep -q TAYLOR-White")" \
  "$(ok 'the dock sees kitty running and in front' "$QL | grep -E 'taylor-dock: windows' | tail -1 | grep -q 'terminal\*'")" \
  "$(ok 'the dock and its log stay clean' "! $QL | grep -iE 'Dock.qml' | grep -qiE 'error|TypeError|ReferenceError'")" \
  "$(ok 'the taskbar apps setup ran at sign in' "test -s ~/.local/state/taylor-os/apps-setup.log")" \
  "$QL | grep -E 'taylor-dock: (launch|windows)' | tail -4" \
  "tail -20 ~/.local/state/taylor-os/apps-setup.log"
# the slot shows Firefox now (look at the screenshot), and Browser's splay shows its green ring on Firefox
$V click "$BX" "$DY" "$SW" "$SH"; sleep 1
shot taskbar-8-splay-ring
$V click 40 $((SH - 40)) "$SW" "$SH"; sleep 1
shot taskbar-9-folded

# the other way: a default browser changed outside the dock (as KDE's settings or a browser's own button would) moves
# the slot at the dock's next look (every 20 s while an app is missing, else every 2 minutes)
vm taskbar-follow \
  "for i in \$(seq 1 60); do flatpak info com.google.Chrome >/dev/null 2>&1 && break; sleep 10; done; flatpak list --app --columns=application | tr '\\n' ' '; echo" \
  "xdg-mime default com.google.Chrome.desktop x-scheme-handler/http x-scheme-handler/https text/html; xdg-settings get default-web-browser" \
  "for i in \$(seq 1 30); do grep -q '\"lastBrowser\": *\"chrome\"' ~/.config/taylor-os/settings.json && break; sleep 5; done" \
  "$(ok 'a default browser changed elsewhere moves the Browser slot' "grep -q '\"lastBrowser\": *\"chrome\"' ~/.config/taylor-os/settings.json && $QL | grep -q 'default browser is chrome'")" \
  "$QL | grep -E 'default browser' | tail -3"

# Power (her pick S3, 2026-11-22): the last slot fans out Lock, Sleep, Restart and Shut down; Lock really locks
LH='s=$(loginctl list-sessions --no-legend | awk '"'"'$3=="tester"{print $1}'"'"' | while read s; do [ "$(loginctl show-session $s -p Seat --value)" = seat0 ] && echo $s; done | head -1); loginctl show-session $s -p LockedHint --value'
PX=${XS[9]}
$V click "$PX" "$DY" "$SW" "$SH"; sleep 1.2
shot taskbar-10-power
vm taskbar-power \
  "$(ok 'Power is the last slot, after a thin line' "$QL | grep -oE 'slots at y=[0-9]+ x=[0-9,]+ \(dial, [a-z, ]+\)' | tail -1 | grep -q 'settings, power)'")" \
  "$(ok 'a click on Power fans out Lock, Sleep, Restart and Shut down' "$QL | grep -q 'taylor-dock: splay power \[lock sleep restart shutdown\]' && hyprctl layers | grep -q taylor-dock-splay")" \
  "$QL | grep -E 'splay power' | tail -1"
# Lock is the first of the four: -60 degrees, 100 px
LX=$(python3 -c "import math; print(round($PX + math.sin(math.radians(-60)) * 100 * $S))")
LY=$(python3 -c "import math; print(round($DY + math.cos(math.radians(-60)) * 100 * $S))")
$V click "$LX" "$LY" "$SW" "$SH"
sleep 8
shot taskbar-11-locked
vm taskbar-lock \
  "$(ok 'Lock in the Power fan locks the PC' "$QL | grep -q 'taylor-dock: power: lock' && [ \"\$($LH)\" = yes ]")" \
  "$(ok 'the dock with Power loaded with no QML errors' "! $QL | grep -iE 'Dock.qml' | grep -qiE 'error|TypeError|ReferenceError|not defined'")"
$V type 'taylortest'
sleep 0.5
$V type '\n'
sleep 9
vm taskbar-unlock \
  "$(ok 'her password opens it again after Lock' "[ \"\$($LH)\" = no ]")"

# Gaming mode (her pick S4, 2026-11-22): a full-screen game (here a window that says it is Steam game 123) turns it on;
# closing the game turns everything back
GW='journalctl --user -u taylor-gamewatch --no-pager -o cat'
vm taskbar-game-on \
  "$(ok 'the gaming-mode watcher runs in her desktop' "systemctl --user is-active --quiet taylor-gamewatch.service")" \
  "tuned-adm active; hyprctl eval 'hl.exec_cmd(\"kitty --class steam_app_123 --start-as fullscreen sleep 60\")'; sleep 8; hyprctl clients | grep -E 'class:|fullscreen:' | tail -6" \
  "$(ok 'a full-screen game turns gaming mode on (the desktop holds still, the PC runs at full power)' "$GW | grep -q 'on for steam_app_123' && quickshell ipc call gaming state | grep -qx on && tuned-adm active | grep -q throughput-performance-bazzite")" \
  "$GW | tail -3"
shot taskbar-12-game
vm taskbar-game-off \
  "pkill -f 'kitty --class steam_app_123'; sleep 16" \
  "$(ok 'closing the game turns everything back' "$GW | grep -q 'off (no game full screen)' && quickshell ipc call gaming state | grep -qx off && ! tuned-adm active | grep -q throughput-performance-bazzite")" \
  "$GW | tail -3; tuned-adm active"
