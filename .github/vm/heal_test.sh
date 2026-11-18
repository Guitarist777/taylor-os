#!/usr/bin/bash
# Test taylor-heal inside the TAYLOR OS image (run in a throwaway container, repo mounted at /repo):
#   t1 = her PC's state on 2026-11-18 (Hyprland's example hyprland.lua), t2 = an account with its own edited file,
#   t3 = an account with no Hyprland settings at all. Then a second run must change nothing, real Hyprland must find no
#   errors in the desktop file, and the login screen's setting must name a desktop session that exists.
set -u
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }

cp /repo/files/system/etc/skel/.config/hypr/hyprland.lua /etc/skel/.config/hypr/hyprland.lua
rm -rf /usr/share/taylor-os/quickshell; mkdir -p /usr/share/taylor-os; cp -a /repo/files/system/usr/share/taylor-os/quickshell /usr/share/taylor-os/quickshell
useradd -m t1; useradd -m t2; useradd -M t3; install -d -o t3 -g t3 /home/t3
mkdir -p /home/t1/.config/hypr /home/t2/.config/hypr
printf -- '-- This is an example Hyprland Lua config file.\n' > /home/t1/.config/hypr/hyprland.lua
echo '-- my own settings' > /home/t2/.config/hypr/hyprland.lua
mkdir -p /home/t1/.config/autostart /home/t2/.config/autostart
printf '[Desktop Entry]\nName=Bazzite Portal\nExec=yafti_gtk.py /usr/share/yafti/yafti.yml\nType=Application\nX-GNOME-Autostart-enabled=true' > /home/t1/.config/autostart/bazzite-portal.desktop   # no final newline on purpose
printf '[Desktop Entry]\nName=Something of hers\nExec=my-own-thing\n' > /home/t2/.config/autostart/bazzite-portal.desktop
mkdir -p /home/t1/.config/quickshell /home/t2/.config/quickshell   # t1: the copy TAYLOR OS made at install; t2: desktop files of her own
echo '// TAYLOR OS desktop, from her mockup' > /home/t1/.config/quickshell/shell.qml
echo '// my own shell' > /home/t2/.config/quickshell/shell.qml
chown -R t1:t1 /home/t1; chown -R t2:t2 /home/t2
systemctl set-default multi-user.target >/dev/null 2>&1

bash /repo/files/system/usr/libexec/taylor-heal

check "picture mode is the default again" '[ "$(systemctl get-default)" = graphical.target ]'
check "t1 (her state): TAYLOR desktop in place" 'grep -q TAYLOR-OS-DESKTOP /home/t1/.config/hypr/hyprland.lua'
check "t1: Hyprland's example kept beside it" 'ls /home/t1/.config/hypr/hyprland.lua.example-* >/dev/null 2>&1'
check "t1: the file belongs to t1" '[ "$(stat -c %U /home/t1/.config/hypr/hyprland.lua)" = t1 ]'
check "t2 (own file): untouched" '[ "$(cat /home/t2/.config/hypr/hyprland.lua)" = "-- my own settings" ]'
check "t2: nothing added beside it" '! ls /home/t2/.config/hypr/hyprland.lua.example-* >/dev/null 2>&1'
check "t3 (nothing): TAYLOR desktop in place" 'grep -q TAYLOR-OS-DESKTOP /home/t3/.config/hypr/hyprland.lua'
check "t3: the desktop comes from the system" '[ "$(readlink /home/t3/.config/quickshell)" = /usr/share/taylor-os/quickshell ] && [ -f /home/t3/.config/quickshell/WindowBar.qml ]'
check "t1 (old copy): now points at the system desktop" '[ "$(readlink /home/t1/.config/quickshell)" = /usr/share/taylor-os/quickshell ]'
check "t1: the old copy is kept beside it" 'ls -d /home/t1/.config/quickshell.taylor-old-* >/dev/null 2>&1'
check "t1: the pointer belongs to t1" '[ "$(stat -c %U /home/t1/.config/quickshell)" = t1 ]'
check "t2 (own desktop files): untouched" '[ -d /home/t2/.config/quickshell ] && [ ! -L /home/t2/.config/quickshell ] && grep -q "my own shell" /home/t2/.config/quickshell/shell.qml'
check "t3: owned by t3" '[ "$(stat -c %U /home/t3/.config/hypr/hyprland.lua)" = t3 ]'

check "t1: Bazzite's welcome window kept to KDE" 'grep -qx "NotShowIn=Hyprland;" /home/t1/.config/autostart/bazzite-portal.desktop'
check "t1: the welcome file is still a good file (last line intact)" 'grep -qx "X-GNOME-Autostart-enabled=true" /home/t1/.config/autostart/bazzite-portal.desktop'
check "t2: a file of hers with that name is untouched" '! grep -q NotShowIn /home/t2/.config/autostart/bazzite-portal.desktop'
check "new accounts get the welcome window kept to KDE" 'grep -qx "NotShowIn=Hyprland;" /repo/files/system/etc/skel/.config/autostart/bazzite-portal.desktop'

before=$(find /home \( -type f -o -type l \) | sort; find /home -type f | sort | xargs md5sum)
bash /repo/files/system/usr/libexec/taylor-heal
check "a second run changes nothing" '[ "$before" = "$(find /home \( -type f -o -type l \) | sort; find /home -type f | sort | xargs md5sum)" ]'

conf=/repo/files/system/usr/lib/plasmalogin/plasmalogin.conf.d/10-taylor.conf
sess=$(sed -n 's/^PreselectedSession=//p' "$conf" | tr -d '\r')
check "login screen setting names a session ($sess)" '[ -n "$sess" ]'
check "that session exists in the image" '[ -f "/usr/share/wayland-sessions/$sess" ]'
check "the login screen reads that folder (it exists in the image)" '[ -d /usr/lib/plasmalogin/plasmalogin.conf.d ]'

out=$(setpriv --reuid t1 --regid t1 --init-groups env HOME=/home/t1 XDG_RUNTIME_DIR=/tmp Hyprland --verify-config -c /home/t1/.config/hypr/hyprland.lua 2>&1)
echo "$out" | tail -6
check "real Hyprland finds no errors in her desktop file" 'echo "$out" | grep -qi "config ok"'
exit $fail
