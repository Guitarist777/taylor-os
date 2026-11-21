# TAYLOR's dial, her launcher, notifications, loading, and TAYLOR's real state (phases 3, 4, 5; 2026-11-21).
# Made-up data only: a made-up TAYLOR (.github/vm/fake_taylor.py) with a made-up token, made-up notifications, a
# made-up folder. Nothing of hers.
. .github/vm/checks/lib.sh
expect dial 30
B='export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus'
L='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'
# which layer level each of her pieces is on (0 background, 1 bottom, 2 top, 3 overlay)
LV='hyprctl -j layers | python3 -c "import json,sys; d=json.load(sys.stdin); print(\"LEVELS\", \" \".join(sorted(set(l[\"namespace\"]+\"@\"+k for m in d.values() for k,ls in m[\"levels\"].items() for l in ls))))"'

# ---- setup: nothing in the way, a made-up folder, the made-up TAYLOR's files ----
vm dial-0 "$CLOSEALL" "pkill -x kdialog; pkill -u tester -f -i steam; \$Q call notes clear; sleep 2; echo cleared" \
  "mkdir -p ~/Documents/Zebrafolder && echo made" \
  "$WH" \
  "hyprctl layers | grep taylor-dial | sed -E 's/.*xywh: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+).*/DIALXYWH \\1 \\2 \\3 \\4/'" \
  "$(ok 'her dial is drawn behind every window (the bottom layer)' "$LV | grep -qE 'taylor-dial@[01]( |\$)'")" \
  "$LV"
read -r sw sh < <(screen dial-0)
read -r dx dy dw dh < <(tr -d '\r' < out/dial-0.txt | grep -oE 'DIALXYWH [0-9]+ [0-9]+ [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
cx=$((dx + dw / 2)); cy=$((sh * 390 / 900))
shot dial-1-resting

# ---- her launcher: Windows key + Space, type part of an app's name, Enter ----
$V key meta_l-spc; sleep 3
vm dial-1 "$(ok 'Windows key + Space opens her launcher' "hyprctl layers | grep -q taylor-launcher")"
$V type 'kitt'; sleep 2
shot dial-2-typed-kitt
$V key ret; sleep 1
shot dial-3-opening
sleep 8
vm dial-2 \
  "$(ok 'Enter opens the app she typed' "hyprctl clients | grep -q 'class: kitty'")" \
  "$(ok 'her launcher closes after she picks' "! hyprctl layers | grep -q taylor-launcher")" \
  "$(ok 'her status says what she is doing (OPENING KITTY.)' "$L | grep -q 'taylor-desktop: status OPENING KITTY.'")" \
  "$(ok 'circling dots by the pointer wait for the window' "$L | grep -q 'taylor-loading: waiting for the window'")" \
  "$(ok 'the dots by the pointer go when the window opens' "$L | grep -q 'taylor-loading: the window opened'")" \
  "$L | grep -E 'taylor-(loading|launcher|desktop)' | tail -12" \
  "pkill -x kitty; sleep 2; echo closed"

# ---- a click on the dial opens it too; a folder's name finds the folder; any text adds Ask TAYLOR ----
$V click $cx $cy "$sw" "$sh"; sleep 3
vm dial-3 "$(ok 'a click on her dial opens the launcher' "hyprctl layers | grep -q taylor-launcher")"
$V type 'zebraf'; sleep 3
shot dial-4-folder
vm dial-4 \
  "$(ok 'a folder she types shows as a Folder row' "$L | grep 'taylor-launcher: rows' | tail -1 | grep -q Folder")" \
  "$(ok 'any typed text adds a last row, Ask TAYLOR' "$L | grep 'taylor-launcher: rows' | tail -1 | grep -qE ',?TAYLOR\$'")" \
  "$L | grep 'taylor-launcher: rows' | tail -3"
$V key esc; sleep 2
vm dial-5 "$(ok 'Escape closes her launcher' "! hyprctl layers | grep -q taylor-launcher")"

# ---- TAYLOR herself, made up: her state every 2 seconds, thinking, things waiting, the ask ----
# the made-up TAYLOR goes over in pieces (the console takes short lines)
b64=$(base64 -w0 .github/vm/fake_taylor.py)
parts=(); for ((i = 0; i < ${#b64}; i += 600)); do parts+=("printf %s '${b64:i:600}' >> /tmp/ft.b64"); done
vm dial-6a "rm -f /tmp/ft.b64 /tmp/fake.log /tmp/opened.txt; echo start" "${parts[@]}" \
  "base64 -d /tmp/ft.b64 > /tmp/fake_taylor.py && python3 -m py_compile /tmp/fake_taylor.py && echo FAKE-READY"
vm dial-6 \
  "mkdir -p ~/.config/taylor ~/.local/bin ~/.local/share/applications; printf 'TAYLOR_TOKEN=madeup-vm-token-4821\n' > ~/.config/taylor/taylor.env" \
  "printf '{\"up\": true, \"thinking\": false, \"waiting\": 0, \"since\": 0}' > /tmp/state.json" \
  "printf '#!/bin/sh\necho \"\$1\" >> /tmp/opened.txt\ncurl -s \"\$1\" >/dev/null\n' > ~/.local/bin/fakebrowser; chmod 755 ~/.local/bin/fakebrowser" \
  "printf '[Desktop Entry]\nType=Application\nName=Made-up browser\nExec=%s/.local/bin/fakebrowser %%u\nMimeType=x-scheme-handler/http;\nNoDisplay=true\n' \"\$HOME\" > ~/.local/share/applications/fakebrowser.desktop; xdg-mime default fakebrowser.desktop x-scheme-handler/http; xdg-mime query default x-scheme-handler/http" \
  "setsid nohup python3 /tmp/fake_taylor.py madeup-vm-token-4821 /tmp/state.json /tmp/fake.log >/dev/null 2>&1 < /dev/null & sleep 1; echo started" \
  "for i in \$(seq 1 45); do $L | grep -q 'TAYLOR answering: true' && break; sleep 1; done; echo waited \$i" \
  "$(ok 'the desktop finds TAYLOR and reads her state' "$L | grep -q 'taylor-hook: TAYLOR answering: true'")" \
  "$(ok 'the token is never written to the log' "! $L | grep -q madeup-vm-token")" \
  "printf '{\"up\": true, \"thinking\": true, \"waiting\": 0, \"since\": 0}' > /tmp/state.json; sleep 4.5" \
  "\$Q call taylor state" \
  "$(ok 'TAYLOR thinking shows THINKING. under her dial' "\$Q call taylor state | grep -q 'line=THINKING.' && $L | grep -q 'taylor-dial: status THINKING.'")"
shot dial-5-thinking
vm dial-7 \
  "printf '{\"up\": true, \"thinking\": false, \"waiting\": 2, \"since\": 0}' > /tmp/state.json; sleep 4.5" \
  "\$Q call taylor state" \
  "$(ok 'two things waiting from TAYLOR show 2 NEW.' "\$Q call taylor state | grep -q 'line=2 NEW.'")"
shot dial-6-two-new
vm dial-8 "printf '{\"up\": true, \"thinking\": false, \"waiting\": 0, \"since\": 0}' > /tmp/state.json; sleep 4.5; \$Q call taylor state"

# Ask TAYLOR from her launcher, with the keys she would press
$V key meta_l-spc; sleep 3
$V type 'hello taylor'; sleep 2
shot dial-7-ask-row
$V key ret; sleep 0.8
shot dial-8-asked
sleep 5
vm dial-9 \
  "cat /tmp/fake.log | grep -v STATE; echo; cat /tmp/opened.txt" \
  "$(ok 'Ask TAYLOR sends what she typed to TAYLOR' "grep -q \"ASK text='hello taylor'\" /tmp/fake.log")" \
  "$(ok 'her page opens with the ask nonce TAYLOR gave' "n=\$(grep -oE 'nonce=[0-9a-f]+' /tmp/fake.log | tail -1 | cut -d= -f2); [ -n \"\$n\" ] && grep -q \"PAGE /?ask=\$n\" /tmp/fake.log && grep -q 'taylor-hook: ask sent' <($L)")" \
  "$L | grep -E 'taylor-hook' | tail -8"

# ---- notifications: nothing covers a full-screen window ----
$V key meta_l-ret; sleep 4
$V key meta_l-f; sleep 2
vm dial-10 "$B" \
  "$(ok 'a terminal is full screen' "hyprctl activewindow | grep -qE 'fullscreen: [12]'")" \
  "$(ok 'her desktop is the only notification service' "o=\$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetConnectionUnixProcessID org.freedesktop.Notifications | grep -oE '[0-9]+' | tail -1); [ \"\$(cat /proc/\$o/comm)\" = quickshell ] && ! pgrep -u tester -x 'mako|dunst|swaync|plasmashell' >/dev/null")" \
  "$LV | tr ' ' '\n' | grep -E '@[23]\$' | sort > /tmp/before.txt; cat /tmp/before.txt" \
  "notify-send 'Download finished' 'Game update is ready'; sleep 1.2" \
  "$LV | tr ' ' '\n' | grep -E '@[23]\$' | sort > /tmp/after.txt; cat /tmp/after.txt" \
  "$(ok 'nothing new shows over the full-screen window' "diff -q /tmp/before.txt /tmp/after.txt >/dev/null && hyprctl activewindow | grep -qE 'fullscreen: [12]'")" \
  "$(ok 'the notification becomes a dot by her dial' "$L | grep -q 'taylor-notes: one came in' && [ \"\$(\$Q call notes waiting)\" -ge 1 ]")"
shot dial-9-fullscreen-note
$V key meta_l-f; sleep 1
vm dial-11 "pkill -x kitty; sleep 2; $B; notify-send 'Timer done' '10 minute break is over'; sleep 1; notify-send 'Chat' '3 new messages'; sleep 4" \
  "hyprctl layers | grep taylor-tray | sed -E 's/.*xywh: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+).*/TRAYXYWH \\1 \\2 \\3 \\4/'" \
  "$(ok 'three waiting read 3 NEW.' "\$Q call taylor state | grep -q 'line=3 NEW.'")"
shot dial-10-three-dots
read -r tx ty tw th < <(tr -d '\r' < out/dial-11.txt | grep -oE 'TRAYXYWH( [0-9]+)+' | tail -1 | cut -d' ' -f2-)
$V click $((tx + 16)) $((ty + th / 2)) "$sw" "$sh"; sleep 2
shot dial-11-list
vm dial-12 \
  "$(ok 'the green count by the clock opens her list' "hyprctl layers | grep -q taylor-notes")" \
  "hyprctl layers | grep taylor-notes | sed -E 's/.*xywh: ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+).*/LISTXYWH \\1 \\2 \\3 \\4/'"
read -r lx ly lw lh < <(tr -d '\r' < out/dial-12.txt | grep -oE 'LISTXYWH( [0-9]+)+' | tail -1 | cut -d' ' -f2-)
$V click $((lx + lw - 40)) $((ly + lh - 8 - 17)) "$sw" "$sh"; sleep 0.3
shot dial-12-line-fading
sleep 3
vm dial-13 \
  "$(ok 'a clicked line fades and its dot goes back (2 left)' "[ \"\$(\$Q call notes waiting)\" = 2 ] && $L | grep -q 'taylor-notes: one dismissed from the list'")" \
  "\$Q call notes toggle; \$Q call notes clear; sleep 2; echo cleared"

# ---- progress: the small ring by the clock ----
vm dial-14 "$B"   "$(ok 'her desktop takes the place of KDE job progress (the job tracker names)' "o=\$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetConnectionUnixProcessID org.kde.JobViewServer | grep -oE '[0-9]+' | tail -1); grep -q taylor-jobs /proc/\$o/cmdline")"   "notify-send -p -h int:value:30 'Copying' 'photos' > /tmp/nid; sleep 1.2; echo id \$(cat /tmp/nid)"   "$(ok 'a progress notification shows the ring by the clock, not a dot' "hyprctl layers | grep -q taylor-progress && [ \"\$(\$Q call notes waiting)\" = 0 ]")"
shot dial-13-progress-30
vm dial-15 "$B"   "notify-send -r \$(cat /tmp/nid) -h int:value:100 'Copying' 'photos'; sleep 0.4; echo done"   "$(ok 'the ring ends in a pulse when the job is done' "$L | grep -q 'taylor-progress: a job finished'")"
shot dial-14-progress-done
sleep 3
vm dial-16 "$B"   "gdbus call --session --dest org.kde.JobViewServer --object-path /JobViewServer --method org.kde.JobViewServerV2.requestView org.kde.dolphin 3 '{}' | grep -oE '/JobViewServer/JobView_[0-9]+' > /tmp/jp; cat /tmp/jp"   "gdbus call --session --dest org.kde.JobViewServer --object-path \$(cat /tmp/jp) --method org.kde.JobViewV3.update \"{'title': <'Copying'>, 'percent': <uint32 40>, 'totalFiles': <uint64 24>, 'processedFiles': <uint64 9>}\"; sleep 1.5"
shot dial-15-dolphin-style-job
vm dial-17 "$B"   "gdbus call --session --dest org.kde.JobViewServer --object-path \$(cat /tmp/jp) --method org.kde.JobViewV3.terminate 0 '' '{}'; sleep 1"   "$(ok 'a job reported the way Dolphin reports a copy fills the ring and ends' "[ \$($L | grep -c 'taylor-progress: a job started') -ge 2 ] && [ \$($L | grep -c 'taylor-progress: a job finished') -ge 2 ]")"   "$L | grep -E 'taylor-progress' | tail -10"
vm dial-19 "pkill -f fake_taylor.py; echo tidied" \
  "$(ok 'the desktop shell is still running at the end' "pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'no QML errors from the dial, launcher, list, loading or TAYLOR' "! $L | grep -iE 'TypeError|ReferenceError|is not defined|Cannot read' | grep -iE 'Dial|Launcher|NoteList|Loading|Progress|Taylor|shell.qml'")" \
  "$L | grep -iE 'warn|error' | tail -20"
shot dial-17-end
