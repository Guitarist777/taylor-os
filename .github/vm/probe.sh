#!/bin/bash
# What a TAYLOR login screen would need, read from the built image.
echo "=== packages installed"
rpm -q greetd tuigreet greetd-tuigreet cage quickshell hyprland uwsm plasma-login-manager kwallet-pam pam-kwallet gnome-keyring-pam 2>&1
echo "=== packages available"
dnf -q repoquery --available greetd tuigreet greetd-tuigreet greetd-agreety cage 2>&1 | head -20
dnf -q info greetd 2>&1 | head -12
echo "=== quickshell modules"
ls /usr/lib64/qt6/qml/Quickshell/Services/ 2>&1
ls /usr/lib64/qt6/qml/Quickshell/ 2>&1
find / -path /proc -prune -o -type d -iname "*greetd*" -print 2>/dev/null | head
echo "=== quickshell version"
quickshell --version 2>&1 | head -3
echo "=== login screen PAM and units"
for f in /etc/pam.d/plasmalogin /usr/lib/pam.d/plasmalogin /etc/pam.d/sddm /etc/pam.d/greetd; do echo "--- $f"; cat "$f" 2>&1; done
systemctl get-default 2>&1
ls -l /etc/systemd/system/display-manager.service 2>&1
systemctl cat plasmalogin.service 2>&1 | head -30
echo "=== sessions"
ls /usr/share/wayland-sessions 2>&1
cat /usr/share/wayland-sessions/hyprland-uwsm.desktop 2>&1
echo "=== users"
getent passwd greeter greetd plasmalogin 2>&1
