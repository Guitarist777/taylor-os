# The TAYLOR look on her KDE backup session (her build brief, "Alternate look: TAYLOR on KDE", 2026-11-21).
# From her signed-in TAYLOR desktop: sign out, F2 on her login screen, sign in to KDE; the first KDE start puts the
# TAYLOR look on (colours, Plasma theme, title bars, Slot-Dark-Icons, the sky, a bottom panel). A Dolphin window is
# looked at, then KDE is ended and her own login screen must come back, and her TAYLOR desktop must still open.
. .github/vm/checks/lib.sh
SESSION="s=\$(loginctl list-sessions --no-legend | awk '\$3==\"tester\" && \$4==\"seat0\" {print \$1}' | head -1)"
KENV='export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-0 XDG_CURRENT_DESKTOP=KDE QT_QPA_PLATFORM=wayland'
expect kde 14
# the panel check, sent to the VM as one line
PANELPY=$(base64 -w0 <<'PY'
import configparser, os, sys
c = configparser.RawConfigParser(strict=False, interpolation=None); c.optionxform = str
c.read(os.path.expanduser('~/.config/plasma-org.kde.plasma.desktop-appletsrc'))
panels = [s for s in c.sections() if s.startswith('Containments][') and s.count('][') == 1 and c.get(s, 'plugin', fallback='') == 'org.kde.panel']
need = {'org.kde.plasma.kickoff', 'org.kde.plasma.icontasks', 'org.kde.plasma.systemtray', 'org.kde.plasma.digitalclock'}
ok = False
for p in panels:
    apps = {c.get(s, 'plugin', fallback='') for s in c.sections() if s.startswith(p + '][Applets][') and s.count('][') == 3}
    print('PANEL', p, 'location', c.get(p, 'location', fallback='?'), ' '.join(sorted(apps)))
    ok = ok or (c.get(p, 'location', fallback='') == '4' and need <= apps)
sys.exit(0 if ok and len(panels) == 1 else 1)
PY
)

vm kde-0 \
  "$(ok 'the KDE look did not run in her TAYLOR desktop' "pgrep -x -u tester Hyprland >/dev/null && ! test -e ~/.local/state/taylor-os/kde-look.log")" \
  "$SESSION; echo session \$s; echo taylortest | sudo -S loginctl terminate-session \$s"
sleep 40
$V key f2
sleep 3
shot kde-1-f2
$V type 'taylortest'
sleep 1
$V type '\n'
sleep 120
shot kde-2-desktop

vm kde-1 \
  "$(ok 'F2 on her login screen picks the KDE backup' "echo taylortest | sudo -S grep -q 'next sign-in opens the KDE backup' /tmp/taylor-greeter-scene.log")" \
  "$(ok 'KDE Plasma runs (plasmashell, no Hyprland)' "pgrep -u tester -x plasmashell >/dev/null && ! pgrep -u tester -x Hyprland >/dev/null")" \
  "$(ok 'the TAYLOR look was put on once and marked done' "test -e ~/.local/state/taylor-os/kde-look-applied && grep -q 'global theme TAYLOR applied' ~/.local/state/taylor-os/kde-look.log")" \
  "$(ok 'the colour scheme is TAYLOR' "[ \"\$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)\" = TAYLOR ]")" \
  "$(ok 'the icon theme is Slot-Dark-Icons and it is installed' "[ \"\$(kreadconfig6 --file kdeglobals --group Icons --key Theme)\" = Slot-Dark-Icons ] && grep -q '^Name=Slot-Dark-Icons' /usr/share/icons/Slot-Dark-Icons/index.theme && test -f /usr/share/icons/Slot-Dark-Icons/LICENSE")" \
  "$(ok 'the Plasma theme is TAYLOR' "[ \"\$(kreadconfig6 --file plasmarc --group Theme --key name)\" = TAYLOR ]")" \
  "$(ok 'the window title bars are TAYLOR' "[ \"\$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme)\" = __aurorae__svg__TAYLOR ]")" \
  "$(ok 'the wallpaper is the TAYLOR sky' "grep -q 'TAYLOR-Sky' ~/.config/plasma-org.kde.plasma.desktop-appletsrc")" \
  "$(ok 'one bottom panel with the menu, apps, tray and clock' "echo $PANELPY | base64 -d | python3")" \
  "cat ~/.local/state/taylor-os/kde-look.log" \
  "grep -n -A3 'Wallpaper' ~/.config/plasma-org.kde.plasma.desktop-appletsrc | head -20"

vm kde-2 \
  "$KENV; (setsid -f dolphin --new-window /usr/share >/tmp/dolphin.log 2>&1 &); sleep 10" \
  "$(ok 'a Dolphin window opens in KDE' "pgrep -u tester -x dolphin >/dev/null")"
shot kde-3-dolphin

vm kde-3 \
  "pkill -u tester -x dolphin; $SESSION; echo session \$s; echo taylortest | sudo -S loginctl terminate-session \$s"
sleep 40
shot kde-4-back
vm kde-4 \
  "$(ok 'her login screen comes back after KDE' "pgrep -u greetd -f '^(/usr/bin/)?quickshell -p /usr/share/taylor-os/greeter' >/dev/null")"

# Her TAYLOR desktop is untouched by the KDE look: it opens again from her login screen.
$V type 'taylortest'
sleep 1
$V type '\n'
sleep 80
shot kde-5-taylor-again
vm kde-5 \
  "$(ok 'her TAYLOR desktop opens again after KDE' "pgrep -x -u tester Hyprland >/dev/null && pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'the KDE look did not run again in her TAYLOR desktop' "[ \$(grep -c '^taylor-kde-look: start' ~/.local/state/taylor-os/kde-look.log) = 1 ]")"
