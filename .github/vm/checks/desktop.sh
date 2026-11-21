# The desktop in general (the foundation, 2026-11-21): her pieces are on the main screen, her settings file is made,
# Hyprland has no settings errors, and a colour scheme picked in her settings recolours the desktop at once.
. .github/vm/checks/lib.sh
expect desktop 10
QSLOG='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'
vm desktop \
  "$(ok 'Hyprland reports no settings errors' "hyprctl -j configerrors | tr -d ' \t\n' | grep -qxE '\[(\"\")?\]'")" \
  "$(ok 'the dock, dial and clock are on her screen' "hyprctl layers | grep -q taylor-dock && hyprctl layers | grep -q taylor-dial && hyprctl layers | grep -q taylor-clock")" \
  "$(ok 'her settings file is made with the defaults' "grep -q '\"scheme\": *\"taylor\"' ~/.config/taylor-os/settings.json")" \
  "$(ok 'the desktop shell loaded with no script errors' "! $QSLOG | grep -qE 'ReferenceError|TypeError|SyntaxError|is not defined|Cannot assign|Type error'")" \
  "$QSLOG | grep -iE 'error|is not defined|cannot' | sort | uniq -c | sort -rn | head -30" \
  "$(ok 'her fonts Manrope and Share Tech Mono are installed' "fc-list | grep -q Manrope && fc-list | grep -q 'Share Tech Mono'")"   "fc-list | grep -i -E 'manrope|share tech' ; fc-match Manrope"
shot desktop-taylor
vm desktop-scheme \
  "\$Q call theme scheme night; sleep 3" \
  "$(ok 'a scheme picked is written to her settings file' "grep -q '\"scheme\": *\"night\"' ~/.config/taylor-os/settings.json")" \
  "$(ok 'the desktop recolours to Quiet Night' "$QSLOG | grep -q 'taylor-theme: night'")" \
  "$(ok 'the shell is still running after a scheme change' "pgrep -u tester -x quickshell >/dev/null")"
shot desktop-night
vm desktop-scheme-back "\$Q call theme scheme taylor; sleep 2" \
  "$(ok 'the scheme goes back to TAYLOR' "grep -q '\"scheme\": *\"taylor\"' ~/.config/taylor-os/settings.json && $QSLOG | grep 'taylor-theme:' | tail -1 | grep -q 'taylor-theme: taylor'")"

# the gap after her password (2026-11-21): her PC had 5 s of black between the login scene finishing and her desktop
# starting. The login screen now closes its Hyprland the moment greetd has her desktop's start in hand, and writes the
# times to /tmp/taylor-greeter-times.log (seconds since boot). Her desktop's start is logind's: the wayland session's
# TimestampMonotonic (greetd ends the login screen's script before it could log that itself).
GAP='a=$(awk "/launched; closing/ {a=\$1} END {print a}" /tmp/taylor-greeter-times.log); b=$(for s in $(loginctl show-user tester -p Sessions --value); do [ "$(loginctl show-session $s -p Type --value)" = wayland ] && loginctl show-session $s -p TimestampMonotonic --value; done | sort -n | head -1); echo "LAUNCHED $a SESSION $b"; awk -v a="$a" -v b="$b" "BEGIN {g = b/1000000 - a; print \"GAP\", g; exit !(a > 0 && b > 0 && g < 2 && g > -1)}"'
vm desktop-login-gap \
  "cat /tmp/taylor-greeter-times.log" \
  "$(ok 'the login screen logs where the time after her password goes' "grep -q 'password accepted' /tmp/taylor-greeter-times.log && grep -q 'launched; closing the login screen' /tmp/taylor-greeter-times.log")" \
  "$(ok 'her desktop starts within 2 s of greetd taking it' "$GAP")"
