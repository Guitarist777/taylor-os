# Phase 8, boot animation and first login (2026-11-21): her boot screen is her dark with nothing on it, her opening
# plays on the login screen with the lost dot ending and hands over to the login with no cut, black or text in between,
# her "Boot animation" and "Reduce motion" choices reach the login screen (and a bad file can't break it), the sign-in
# goes to her desktop with no text on the way, and a disk password would still be asked on the boot screen.
# Screenshots: out/boot-NNN.png (a restart, every ~0.7 s), out/boot-signin-NN.png, out/boot-still-*.png, out/boot-off-*.png.
. .github/vm/checks/lib.sh
expect boot 40
pip install --quiet pillow >/dev/null 2>&1 || true
gsudo() { printf "echo taylortest | sudo -S sh -c '%s'" "$1"; }

# ---- before the restart: what the image carries
vm boot-1 \
  "$(ok 'the boot screen theme is TAYLOR' "[ \"\$(plymouth-set-default-theme)\" = taylor ]")" \
  "$(ok 'the initramfs carries her boot screen' "echo taylortest | sudo -S lsinitrd /usr/lib/modules/\$(uname -r)/initramfs.img 2>/dev/null | grep -q 'plymouth/themes/taylor/taylor.script'")" \
  "$(ok 'the image carries her boot kernel options' "grep -q 'vt.default_red=11,' /usr/lib/bootc/kargs.d/10-taylor-boot.toml && grep -q rhgb /usr/lib/bootc/kargs.d/10-taylor-boot.toml")" \
  "$(ok 'her login screen motion file holds just two true/false values' "python3 -c 'import json,sys; j=json.load(open(\"/var/lib/taylor-os/greeter.json\")); sys.exit(0 if sorted(j)==[\"bootAnimation\",\"reduceMotion\"] and all(type(v) is bool for v in j.values()) else 1)'")" \
  "$(ok 'the motion file is root-owned and only readable by others' "[ \"\$(stat -c %U:%a /var/lib/taylor-os/greeter.json)\" = root:644 ]")" \
  "$(ok 'her settings are watched for the login screen' "systemctl list-units --no-legend --state=active 'taylor-greeter-prefs@*.path' | grep -q path")" \
  "$(ok 'the boot menu stays hidden (Shift shows it): TAYLOR OS put its setting in place' "echo taylortest | sudo -S head -1 /boot/grub2/custom.cfg 2>/dev/null | grep -q TAYLOR-OS-BOOT-MENU")" \
  "$(ok 'GRUB has its settings file for the start-up bookkeeping (so a failed start still shows the menu)' "echo taylortest | sudo -S test -s /boot/grub2/grubenv")" \
  "cat /proc/cmdline; plymouth-set-default-theme; cat /sys/module/vt/parameters/default_red; cat /var/lib/taylor-os/greeter.json; systemctl status --no-pager taylor-console.service taylor-greeter-prefs.service 'taylor-greeter-prefs@*.path' 2>&1 | head -40" \
  "$(gsudo 'cat /tmp/taylor-greeter-scene.log; journalctl -b -u taylor-greeter-prefs --no-pager | tail -5')"

# ---- her two choices travel to the login screen (and a broken settings file gives the defaults)
SET="python3 -c 'import json,sys; p=\"/home/tester/.config/taylor-os/settings.json\"; j=json.load(open(p)); j[sys.argv[1]]=sys.argv[2]==\"true\"; open(p,\"w\").write(json.dumps(j, indent=4))'"
vm boot-2 \
  "cp ~/.config/taylor-os/settings.json /tmp/settings.keep" \
  "$SET reduceMotion true; sleep 4" \
  "$(ok 'turning Reduce motion on reaches the login screen' "grep -q '\"reduceMotion\": true' /var/lib/taylor-os/greeter.json")" \
  "$SET reduceMotion false; $SET bootAnimation false; sleep 4" \
  "$(ok 'turning the boot animation off reaches the login screen' "grep -q '\"bootAnimation\": false' /var/lib/taylor-os/greeter.json && grep -q '\"reduceMotion\": false' /var/lib/taylor-os/greeter.json")" \
  "printf '{\"bootAnimation\": \"yes\", \"reduceMotion\": [1], \"x\": \"\$(head -c 3000 /dev/urandom | base64 -w0)\"' > ~/.config/taylor-os/settings.json; sleep 4" \
  "$(ok 'a broken settings file gives the login screen its defaults' "grep -qx '{\"bootAnimation\": true, \"reduceMotion\": false}' /var/lib/taylor-os/greeter.json")" \
  "cp /tmp/settings.keep ~/.config/taylor-os/settings.json; sleep 4; cat /var/lib/taylor-os/greeter.json"

# The test PC is installed by a kickstart that sets its own kernel options (a serial console, no rhgb or quiet) and
# does not read the image's kargs.d (bootc adds them on her PC at install and update). Give it hers, as her PC has them,
# and tell its boot screen to ignore the serial console (her PC has none; with one, Plymouth shows plain text instead).
KARGS=$(python3 -c 'import tomllib; print(" ".join("--append-if-missing=" + k for k in tomllib.load(open("files/system/usr/lib/bootc/kargs.d/10-taylor-boot.toml", "rb"))["kargs"]))')
vm boot-kargs "grep -q vt.default_red=11, /proc/cmdline && echo the test PC has her kernel options from the image || echo the test PC did not get her kernel options at install, adding them for this test" "echo taylortest | sudo -S rpm-ostree kargs $KARGS --append-if-missing=plymouth.ignore-serial-consoles; true"

# ---- a cold-ish start: restart the PC and watch firmware -> her dark -> her opening -> the hand-off -> login
vm boot-restart "echo taylortest | sudo -S systemd-run --on-active=4 --timer-property=AccuracySec=100ms systemctl reboot"
start=$(date +%s)
i=0
while [ $(( $(date +%s) - start )) -lt 150 ]; do
  i=$((i + 1))
  $V shot "$PWD/out/boot-$(printf %03d $i).png" >/dev/null 2>&1
  sleep 0.5
done
python3 .github/vm/frames.py boot $(ls out/boot-[0-9][0-9][0-9].png) > out/boot-frames.txt 2>&1; cat out/boot-frames.txt
$V wait-login 600
sleep 20
vm boot-3 \
  "$(ok 'her login screen is up after the restart' "pgrep -u greetd -f '^(/usr/bin/)?quickshell -p /usr/share/taylor-os/greeter' >/dev/null && ! pgrep -u greetd tuigreet >/dev/null")" \
  "$(ok 'the login screen account has its home folder (no error line on the screen at start-up)' "test -d /var/lib/greetd && ! journalctl -b -u greetd --no-pager 2>/dev/null | grep -q 'unable to set working directory'")" \
  "$(ok 'the login screen starts with no error lines from the shell' "! journalctl -b --no-pager 2>/dev/null | grep -q 'brew.sh.*Permission denied'")" \
  "$(ok 'her opening played in full' "$(gsudo 'grep -q "opening full" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'the lost dot is fetched by its friend' "$(gsudo 'grep -q "the friend goes to fetch the lost dot" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'the lost dot hops and the friend hops lower' "$(gsudo 'grep -q "the lost dot hops, the friend hops lower" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'the opening hands over to the login' "$(gsudo 'grep -qE "the hand-off begins at 14[.][67] s" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'no QML errors on her login screen' "$(gsudo '! grep -qiE "ReferenceError|TypeError|is not defined|Cannot assign" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'the boot screen is switched on (rhgb)' "grep -qw rhgb /proc/cmdline")" \
  "$(ok 'the text screen black is her dark after a restart' "[ \"\$(cut -d, -f1 /sys/module/vt/parameters/default_red)\" = 11 ]")" \
  "$(gsudo 'cat /tmp/taylor-greeter-scene.log; head -c 2000 /tmp/taylor-greeter-hyprland.log; journalctl -b -u greetd -u taylor-console -u taylor-greeter-prefs --no-pager | tail -30; systemd-analyze blame | head -15; cat /proc/cmdline')" \
  "journalctl -b -o short-monotonic --no-pager | grep -E 'plymouth|greetd|taylor-console|Started|Reached target' | grep -iE 'plymouth|greetd|taylor|graphical' | head -40"

# ---- the first sign-in after a start: her login -> "Welcome back" -> her desktop, no text or black on the way
$V type 'taylortest'
sleep 1
$V type '\n'
for n in $(seq -w 1 40); do $V shot "$PWD/out/boot-signin-$n.png" >/dev/null 2>&1; sleep 0.5; done
sleep 40
shot boot-signin-desktop
python3 .github/vm/frames.py signin $(ls out/boot-signin-[0-9][0-9].png) > out/boot-signin-frames.txt 2>&1; cat out/boot-signin-frames.txt
vm boot-4 \
  "$(ok 'the first sign-in after a start opens her TAYLOR desktop' "pgrep -x -u tester Hyprland >/dev/null && pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'her sign-in starts uwsm with its start-up lines kept quiet' "for p in \$(pgrep -u tester); do tr '\\0' '\\n' < /proc/\$p/environ 2>/dev/null | grep -qx UWSM_SILENT_START=1 && echo yes; done | grep -q yes")" \
  "journalctl -b --no-pager | grep -i uwsm | tail -10"

# ---- Reduce motion and opening off, on the login screen itself (sign out between; the count of broken starts is kept at none)
signout="s=\$(loginctl list-sessions --no-legend | awk '\$3==\"tester\" && \$4==\"seat0\" {print \$1}' | head -1); echo session \$s; echo taylortest | sudo -S loginctl terminate-session \$s"
vm boot-5 "$SET reduceMotion true; sleep 4; cat /var/lib/taylor-os/greeter.json" "$signout"
for n in 1 2 3 4 5 6 7 8; do sleep 1.5; shot "boot-still-$n"; done
sleep 10
vm boot-6 \
  "$(ok 'with Reduce motion her login screen plays the still opening' "$(gsudo 'grep -q "opening still (reduced motion)" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'with Reduce motion her login screen still comes up' "pgrep -u greetd -f '^(/usr/bin/)?quickshell -p /usr/share/taylor-os/greeter' >/dev/null && ! pgrep -u greetd tuigreet >/dev/null")" \
  "$(gsudo 'cat /tmp/taylor-greeter-scene.log')"
$V type 'taylortest'; sleep 1; $V type '\n'; sleep 60
vm boot-7 "$SET reduceMotion false; $SET bootAnimation false; sleep 4; cat /var/lib/taylor-os/greeter.json" "$signout"
for n in 1 2 3 4 5 6; do sleep 1.5; shot "boot-off-$n"; done
sleep 10
vm boot-8 \
  "$(ok 'with the boot animation off her login screen starts at the hand-off' "$(gsudo 'grep -q "opening skipped, from the hand-off" /tmp/taylor-greeter-scene.log')")" \
  "$(ok 'with the boot animation off her login screen comes up' "pgrep -u greetd -f '^(/usr/bin/)?quickshell -p /usr/share/taylor-os/greeter' >/dev/null && ! pgrep -u greetd tuigreet >/dev/null")" \
  "$(gsudo 'cat /tmp/taylor-greeter-scene.log')"
# ---- a sign-in greetd lost (2026-11-24): the scene leaves its mark and ends, as answerWatch does; a fresh one takes over
vm boot-8b "echo taylortest | sudo -S sh -c 'sudo -u greetd touch /tmp/taylor-greeter-reconnect; pkill -u greetd -f \"^(/usr/bin/)?quickshell -p /usr/share/taylor-os/greeter\"'; sleep 8"
shot boot-reconnected
vm boot-8c \
  "$(ok 'a lost sign-in brings a fresh login scene that asks again' "$(gsudo 'grep -q "a fresh login scene after a lost sign-in" /tmp/taylor-greeter-scene-1.log && grep -q "fresh login scene 1" /tmp/taylor-greeter-times.log')")" \
  "$(ok 'the fresh login scene starts at the hand-off' "$(gsudo 'grep -q "opening skipped, from the hand-off" /tmp/taylor-greeter-scene-1.log')")" \
  "$(ok 'the fresh login scene has no QML errors' "$(gsudo '! grep -qiE "ReferenceError|TypeError|is not defined|Cannot assign" /tmp/taylor-greeter-scene-1.log')")" \
  "$(gsudo 'cat /tmp/taylor-greeter-scene-1.log; tail -5 /tmp/taylor-greeter-times.log')"
$V type 'taylortest'; sleep 1; $V type '\n'; sleep 60
vm boot-9 \
  "$(ok 'signing in still works after both choices' "pgrep -x -u tester Hyprland >/dev/null")" \
  "cp /tmp/settings.keep ~/.config/taylor-os/settings.json; sleep 4; cat /var/lib/taylor-os/greeter.json"

# ---- a disk password would still be asked on her boot screen: run her boot screen on another text screen and ask
vm boot-10 \
  "$(gsudo 'chvt 8; sleep 1; plymouthd --tty=tty8 --mode=boot --kernel-command-line="rhgb quiet splash plymouth.ignore-serial-consoles"; sleep 1; plymouth show-splash; sleep 2')"
shot boot-plymouth-dark
vm boot-11 "$(gsudo '(plymouth ask-for-password --prompt="Unlock disk" > /tmp/pw.out 2>&1 &) ; sleep 2')"
$V type 'abc'
sleep 1
shot boot-plymouth-ask
$V type '\n'
sleep 2
vm boot-12 \
  "$(ok 'her boot screen asks for a disk password and takes it' "$(gsudo 'grep -qx abc /tmp/pw.out')")" \
  "$(gsudo 'plymouth quit; sleep 1; chvt 1; sleep 3; rm -f /tmp/pw.out')" \
  "$(ok 'her desktop is still there after the boot screen test' "pgrep -x -u tester Hyprland >/dev/null")"
shot boot-after-plymouth
python3 .github/vm/frames.py dark out/boot-plymouth-dark.png > out/boot-plymouth.txt 2>&1; cat out/boot-plymouth.txt
