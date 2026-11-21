# The desktop in general (the foundation, 2026-11-21): her pieces are on the main screen, her settings file is made,
# Hyprland has no settings errors, and a colour scheme picked in her settings recolours the desktop at once.
. .github/vm/checks/lib.sh
expect desktop 6
vm desktop \
  "$(ok 'Hyprland reports no settings errors' "hyprctl -j configerrors | tr -d ' \t\n' | grep -qxE '\[(\"\")?\]'")" \
  "$(ok 'the dock, dial and clock are on her screen' "hyprctl layers | grep -q taylor-dock && hyprctl layers | grep -q taylor-dial && hyprctl layers | grep -q taylor-clock")" \
  "$(ok 'her settings file is made with the defaults' "grep -q '\"scheme\": *\"taylor\"' ~/.config/taylor-os/settings.json")" \
  "$(ok 'the desktop shell loaded with no QML errors' "! timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -qiE 'error|ReferenceError|TypeError|is not defined'")" \
  "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -iE 'warn|error' | tail -30" \
  "hyprctl -j configerrors"
shot desktop-taylor
vm desktop-scheme \
  "sed -i 's/\"scheme\": *\"taylor\"/\"scheme\": \"night\"/' ~/.config/taylor-os/settings.json; sleep 3" \
  "$(ok 'the shell is still running after a scheme change' "pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'the scheme change is read' "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -q 'taylor-theme: night'")"
shot desktop-night
vm desktop-scheme-back "sed -i 's/\"scheme\": *\"night\"/\"scheme\": \"taylor\"/' ~/.config/taylor-os/settings.json; sleep 2" \
  "$(ok 'the scheme goes back to TAYLOR' "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -q 'taylor-theme: taylor'")"
