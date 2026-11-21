# Phases 6 and 7 (her build brief): the lock screen and unlock, the backup lock screen if hers dies, the timeout to
# lock (and its cancel), and the goodnight before the PC powers off. Run LAST: the shutdown check turns the PC off.
. .github/vm/checks/lib.sh
expect lock 32

# her login session's LockedHint (yes / no), the lock screen's process, and its log
LH='s=$(loginctl list-sessions --no-legend | awk '"'"'$3=="tester"{print $1}'"'"' | while read s; do [ "$(loginctl show-session $s -p Seat --value)" = seat0 ] && echo $s; done | head -1); loginctl show-session $s -p LockedHint --value'
LQS="pgrep -u tester -f 'quickshell -p /usr/share/taylor-os/lock'"
LLOG='/run/user/1000/taylor-lock.log'
STATE='cat /run/user/1000/taylor-lock.state'
DLOG='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'

vm lock-0 "$WH" \
  "$(ok 'the lock screen is installed' "test -x /usr/libexec/taylor-lock && test -f /usr/share/taylor-os/lock/shell.qml && test -f /usr/share/taylor-os/lock/hyprlock.conf")" \
  "$(ok 'hypridle runs with the TAYLOR settings (locks only before sleep)' "pgrep -u tester -af hypridle | grep -q /usr/share/taylor-os/hypridle.conf")" \
  "$(ok 'the power key waits for her goodnight while her desktop runs' "systemd-inhibit --list --no-legend 2>/dev/null | grep -q handle-power-key")" \
  "hyprctl -j getoption misc:allow_session_lock_restore" \
  "$(ok 'her desktop is not locked to begin with' "[ \"\$($LH)\" = no ]")"
read SW SH < <(screen lock-0); SW=${SW:-1280}; SH=${SH:-800}

# ---- Windows key + L: her lock screen ----
$V key meta_l-l
sleep 5
shot lock-1-locked
vm lock-1 \
  "$(ok 'Windows key + L starts her lock screen' "$LQS >/dev/null")" \
  "$(ok 'the session is locked (LockedHint yes)' "[ \"\$($LH)\" = yes ]")" \
  "$(ok 'her lock screen covers every screen' "grep -q 'every screen covered: true' $LLOG")" \
  "$(ok 'her lock screen loaded with no QML errors' "! grep -qiE 'ReferenceError|TypeError|is not defined|error:' $LLOG")" \
  "grep -v qmlscanner $LLOG | tail -15"

# ---- a wrong password: the dial shakes, the dots scatter, still locked ----
$V type 'wrongpass'
sleep 1
shot lock-2-typed
$V type '\n'
sleep 1.2
shot lock-3-wrong
sleep 4
vm lock-2 \
  "$(ok 'a wrong password is turned down' "grep -q 'not unlocked (wrong password)' $LLOG")" \
  "$(ok 'after a wrong password she is still locked' "$LQS >/dev/null && [ \"\$($LH)\" = yes ]")"

# ---- her password: Welcome back, the unlock, then her desktop's arrival ----
$V type 'taylortest'
sleep 0.5
$V type '\n'
sleep 2.5
shot lock-4-welcome
sleep 3.5
shot lock-5-stars
sleep 2
shot lock-6-arrival
sleep 6
shot lock-7-desktop
vm lock-3 \
  "$(ok 'her password unlocks (LockedHint no)' "[ \"\$($LH)\" = no ]")" \
  "$(ok 'the lock screen is gone after the unlock' "! $LQS >/dev/null")" \
  "$(ok 'the lock screen says it unlocked' "[ \"\$($STATE)\" = unlocked ] && grep -q 'taylor-lock: unlocked' $LLOG")" \
  "$(ok 'her desktop played its arrival after the unlock' "$DLOG | grep -q 'unlocked (lock screen); her arrival'")" \
  "$(ok 'her desktop is still running' "pgrep -u tester -x quickshell >/dev/null")" \
  "grep -v qmlscanner $LLOG | tail -12; journalctl --user -t taylor-lock --no-pager | tail -8"

# ---- the backup: her lock screen dies while locked, hyprlock takes over, her password still works ----
$V key meta_l-l
sleep 5
vm lock-4 \
  "$(ok 'locked again for the backup test' "$LQS >/dev/null && [ \"\$($LH)\" = yes ]")" \
  "pkill -KILL -u tester -f 'quickshell -p /usr/share/taylor-os/lock'; sleep 5" \
  "$(ok 'when her lock screen dies, hyprlock takes over' "pgrep -u tester -x hyprlock >/dev/null")" \
  "$(ok 'the session stays locked meanwhile' "[ \"\$($LH)\" = yes ]")" \
  "$(ok 'taylor-lock wrote down that it fell back' "[ \"\$($STATE)\" = fallback ]")" \
  "journalctl --user -t taylor-lock --no-pager | tail -5; cat /run/user/1000/taylor-lock-hyprlock.log | tail -5"
shot lock-8-hyprlock
$V type 'taylortest'
sleep 0.5
$V type '\n'
sleep 6
shot lock-9-after-hyprlock
vm lock-5 \
  "$(ok 'her password unlocks through hyprlock' "! pgrep -u tester -x hyprlock >/dev/null && [ \"\$($STATE)\" = unlocked ] && [ \"\$($LH)\" = no ]")" \
  "$(ok 'her desktop is told after the backup unlock too' "[ \$($DLOG | grep -c 'unlocked (lock screen)') -ge 2 ]")"

# ---- the timeout: dimming, STILL THERE?, the glide, and moving the mouse brings everything back ----
SET='~/.config/taylor-os/settings.json'
vm lock-6 \
  "WAYLAND_DISPLAY=\$(ls /run/user/1000 | grep -E '^wayland-[0-9]+\$' | head -1) setsid -f kitty >/dev/null 2>&1; sleep 4" \
  "sed -i -E 's/\"idleMinutes\": *[0-9.]+/\"idleMinutes\": 0.25/; s/\"waitMinutes\": *[0-9.]+/\"waitMinutes\": 0.2/' $SET; grep -E 'idle|wait' $SET" \
  "sleep 2; \$Q call lock state" \
  "for i in \$(seq 1 60); do \$Q call lock state | grep -q '^out' && break; sleep 0.5; done; \$Q call lock state"
sleep 0.4
shot lock-10-dimming
sleep 2.6
shot lock-11-still-there
sleep 2.5
shot lock-12-middle
$V move 200 200 "$SW" "$SH"
sleep 1
shot lock-13-coming-back
sleep 3
shot lock-14-back
vm lock-7 \
  "$(ok 'the timeout started after the idle time' "$DLOG | grep -q 'taylor-away: dimming (idle'")" \
  "$(ok 'moving the mouse during the wait cancels it' "$DLOG | grep -q 'she is back; everything returns'")" \
  "$(ok 'everything is back and nothing locked' "\$Q call lock state | grep -q '^off' && [ \"\$($LH)\" = no ] && ! $LQS >/dev/null")"

# ---- the timeout again, left alone: the burst into the lock screen ----
vm lock-8 \
  "for i in \$(seq 1 200); do \$Q call lock state | grep -qE '^(locking|locked)' && break; sleep 0.25; done; \$Q call lock state"
sleep 0.6
shot lock-15-burst
sleep 1.6
shot lock-16-specks
sleep 3
shot lock-17-lock-drawing-in
sleep 3
shot lock-18-lock-screen
vm lock-9 \
  "$(ok 'left alone, the timeout ends in her lock screen' "$LQS >/dev/null && [ \"\$($LH)\" = yes ] && grep -q 'taylor-lock: burst' $LLOG")" \
  "$(ok 'the burst lock screen loaded with no QML errors' "! grep -qiE 'ReferenceError|TypeError|is not defined|error:' $LLOG")"
$V type 'taylortest'
sleep 0.5
$V type '\n'
sleep 9
shot lock-19-back-after-timeout
vm lock-10 \
  "$(ok 'her password unlocks after the timeout' "[ \"\$($LH)\" = no ] && ! $LQS >/dev/null")" \
  "$(ok 'the timeout cover is gone after the unlock' "\$Q call lock state | grep -q '^off'")" \
  "sed -i -E 's/\"idleMinutes\": *[0-9.]+/\"idleMinutes\": 3/; s/\"waitMinutes\": *[0-9.]+/\"waitMinutes\": 2/' $SET" \
  "$(ok 'her timeout minutes are back to 3 and 2' "grep -qE '\"idleMinutes\": *3' $SET && grep -qE '\"waitMinutes\": *2' $SET")"

# ---- the goodnight, then the PC powers off (last) ----
vm lock-11 \
  "$(ok 'the power command is there' "\$Q call power state | grep -q idle")" \
  "\$Q call power shutdown" \
  "$(ok 'her goodnight started' "\$Q call power state | grep -q poweroff")"
sleep 0.5
shot lock-20-goodnight-1s
sleep 2
shot lock-21-goodnight-3s
sleep 2
shot lock-22-goodnight-5s
off=FAIL
for i in $(seq 1 120); do
  if [ ! -f /tmp/vm.pid ] || ! kill -0 "$(cat /tmp/vm.pid)" 2>/dev/null; then off=PASS; break; fi
  sleep 1
done
echo "$off after the goodnight the PC powers off (QEMU ended after ${i} s)" | tee out/lock-poweroff.txt
