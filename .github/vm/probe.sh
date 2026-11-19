#!/bin/bash
echo "=== greetd qml"
ls -la /usr/lib64/qt6/qml/Quickshell/Services/Greetd/
cat /usr/lib64/qt6/qml/Quickshell/Services/Greetd/qmldir
for f in /usr/lib64/qt6/qml/Quickshell/Services/Greetd/*.qmltypes; do grep -nE "Signal|Method|Property|name:|Enum|values" "$f" | head -80; done
echo "=== io"
grep -lE "StdioCollector" /usr/lib64/qt6/qml/Quickshell/Io/*.qmltypes && grep -nE "name: \"(Process|StdioCollector)\"" -A3 /usr/lib64/qt6/qml/Quickshell/Io/*.qmltypes | head
echo "=== greetd package"
dnf -y -q install greetd tuigreet >/dev/null 2>&1; rpm -ql greetd | head -30; cat /etc/greetd/config.toml; getent passwd greeter greetd; cat /etc/pam.d/greetd 2>&1; ls /usr/lib/sysusers.d | grep -i greet; cat /usr/lib/sysusers.d/*greet* 2>&1
systemctl cat greetd.service 2>&1 | head -30
