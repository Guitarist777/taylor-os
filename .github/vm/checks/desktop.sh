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

# the gap after her password (2026-11-21): her PC had 5 s of black between the login scene finishing and its Hyprland
# going. The login screen now closes its Hyprland the moment greetd has her desktop's start in hand, and writes the
# times to /tmp/taylor-greeter-times.log (seconds since boot).
vm desktop-login-gap \
  "cat /tmp/taylor-greeter-times.log" \
  "$(ok 'the login screen logs where the time after her password goes' "grep -q 'launched; closing the login screen' /tmp/taylor-greeter-times.log && grep -q 'Hyprland ended' /tmp/taylor-greeter-times.log")" \
  "$(ok 'the login screen is gone within 2 s of greetd taking her desktop' "awk '/launched; closing/ {a=\$1} /Hyprland ended/ {b=\$1} END {exit !(a && b && b - a < 2)}' /tmp/taylor-greeter-times.log")"
