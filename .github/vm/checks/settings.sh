# Her Settings window and the volume and brightness ring (2026-11-21). Real clicks on the real window: where each control
# is comes from Settings' own log ("taylor-settings: place NAME x y", window pixels) plus where Hyprland put the window.
. .github/vm/checks/lib.sh
expect settings 29
L='timeout 8 quickshell log --pid $(pgrep -u tester -x quickshell | head -1) 2>&1'
AT="hyprctl -j clients | python3 -c 'import json,sys; c=[w for w in json.load(sys.stdin) if w[\"title\"]==\"Settings\"]; print(\"SETAT\", *(c[0][\"at\"] + c[0][\"size\"] + [int(c[0][\"floating\"])]) if c else (\"none\",))'"
PLACES="$L | grep -oE 'place [^ ]+ [0-9]+ [0-9]+' | tail -60"
BORDER="{ hyprctl getoption general:col.active_border; hyprctl getoption general.col.active_border; } 2>&1"
WHB="1280 800"
# tap FILE NAME [DX]: click the control NAME, using the window position and places listed in out/FILE.txt
tap() {
    local f="out/$1.txt" name="$2" dx="${3:-0}" at p
    at=$(tr -d '\r' < "$f" | grep -oE 'SETAT [0-9-]+ [0-9-]+' | tail -1 | cut -d' ' -f2-)
    p=$(tr -d '\r' < "$f" | grep -oE "place $name [0-9]+ [0-9]+" | tail -1 | cut -d' ' -f3-)
    if [ -z "$at" ] || [ -z "$p" ]; then echo "no place for $name in $f"; return 1; fi
    set -- $at $p
    echo "tap $name: $(( $1 + $3 + dx )) $(( $2 + $4 ))"
    $V click $(( $1 + $3 + dx )) $(( $2 + $4 )) $WHB
}

# 1. It opens as one normal window: floating, centred, not full screen
vm settings \
  "\$Q settings open; sleep 4" \
  "$AT" \
  "$(ok 'Settings opens as a window' "hyprctl clients | grep -q 'title: Settings'")" \
  "$(ok 'Settings floats at its own size, centred' "hyprctl -j clients | python3 -c 'import json,sys,subprocess; c=[w for w in json.load(sys.stdin) if w[\"title\"]==\"Settings\"][0]; mon=json.loads(subprocess.check_output([\"hyprctl\",\"-j\",\"monitors\"]))[0]; cx=c[\"at\"][0]+c[\"size\"][0]/2; sys.exit(0 if c[\"floating\"] and c[\"size\"]==[760,560] and abs(cx-mon[\"width\"]/2)<40 and not c[\"fullscreen\"] else 1)'")" \
  "$(ok 'the window outline is TAYLOR green to start' "$BORDER | grep -qi 4fb386")" \
  "$BORDER" \
  "$PLACES"
shot settings-appearance

# 2. Each section, chosen with a real click on the left
for s in Lock-and-timeout TAYLOR Sound Display Network About; do
  tap settings "nav:$s"; sleep 3
  shot "settings-$(echo "$s" | tr 'A-Z' 'a-z')"
done
vm settings-sections \
  "$(ok 'a click on the left changes the section' "$L | grep -q 'taylor-settings: open at About'")" \
  "$(ok 'About reads the processor' "$L | grep -E 'taylor-settings: about ' | tail -1 | grep -qE 'cpu=[A-Za-z0-9]'")" \
  "$(ok 'Network reads the wired connection' "$L | grep -E 'taylor-settings: network ' | tail -1 | grep -q 'wired=connected'")" \
  "$(ok 'brightness hides itself when no monitor answers' "[ \"\$(\$Q brightness get)\" = -1 ] && $L | grep -q 'no monitor answers DDC/CI'")" \
  "$L | grep -E 'taylor-settings: (about|network)|taylor-brightness' | tail -5" \
  "rpm-ostree status --json | python3 -c 'import json,sys; d=json.load(sys.stdin)[\"deployments\"][0]; print(\"DEPKEYS\", sorted(d.keys())); print(\"REF\", d.get(\"container-image-reference\"), d.get(\"version\"))'" \
  "/usr/libexec/taylor-update-check --local" \
  "$AT" "$PLACES"

# 3. Check now gives an answer (a real click)
shot settings-about-before
tap settings-sections checknow; sleep 45
shot settings-checked
vm settings-check \
  "$(ok 'Check now gives an answer' "$L | grep -qE 'taylor-settings: update check TAYLOR-UPDATE state=(uptodate|staged|newer)'")" \
  "$L | grep -E 'taylor-settings: (update|checking)' | tail -3" \
  "\$Q settings section Appearance; sleep 3" "$AT" "$PLACES"

# 4. All four schemes, with real clicks: Settings, the desktop and Hyprland's window outline each time
prev=settings-check
for s in quiet night slate taylor; do
  case $s in taylor) hex=4fb386 ;; quiet) hex=3f6152 ;; *) hex=8fb5a1 ;; esac
  tap $prev "scheme:$s"; sleep 4
  shot "scheme-$s-settings"
  vm "scheme-$s" \
    "$(ok "the $s scheme is picked and written" "grep -q '\"scheme\": *\"$s\"' ~/.config/taylor-os/settings.json && $L | grep -q 'taylor-theme: $s'")" \
    "$(ok "the window outline takes the $s colour" "$BORDER | grep -qi $hex")" \
    "$BORDER; hyprctl -j configerrors" \
    "\$Q settings close; sleep 3"
  shot "scheme-$s-desktop"
  vm "scheme-$s-open" "\$Q settings section Appearance; sleep 3" "$AT" "$PLACES"
  prev="scheme-$s-open"
  if [ $s = slate ]; then
    # Slate's background slider: a click near its right end
    tap scheme-slate-open slate 45; sleep 3
    shot scheme-slate-light
    vm scheme-slate-slider \
      "$(ok 'Slate shows its brightness slider and it writes the setting' "$L | grep -q 'taylor-settings: slate level' && python3 -c 'import json,os,sys; sys.exit(0 if json.load(open(os.path.expanduser(\"~/.config/taylor-os/settings.json\")))[\"slateLevel\"] > 0.7 else 1)'")" \
      "grep slateLevel ~/.config/taylor-os/settings.json"
  fi
done

# 5. Lock and timeout: both sliders (real clicks), and the total line
vm lock-open "\$Q settings section Lock-and-timeout; sleep 3" "$AT" "$PLACES"
tap lock-open idle -25; sleep 2     # left of the middle: about 10 minutes
tap lock-open wait -30; sleep 2     # about 3 minutes
shot lock-changed
vm lock \
  "t=\$($L | grep -oE 'lock total=[0-9.]+ idle=[0-9.]+ wait=[0-9.]+' | tail -1); echo \"LINE \$t\"; python3 -c 'import json,os,sys; p=json.load(open(os.path.expanduser(\"~/.config/taylor-os/settings.json\"))); kv=dict(x.split(\"=\") for x in sys.argv[1].split()[1:]); i,w=p[\"idleMinutes\"],p[\"waitMinutes\"]; sys.exit(0 if kv and float(kv[\"total\"])==i+w and float(kv[\"idle\"])==i and float(kv[\"wait\"])==w and (i,w)!=(3,2) else 1)' \"\$t\" && echo 'PASS the two timeout times are written and the total adds them up' || echo 'FAIL the two timeout times are written and the total adds them up'" \
  "grep -E 'idleMinutes|waitMinutes' ~/.config/taylor-os/settings.json"

# 6. The volume and brightness ring, from the real volume keys, while Settings is the window in use
vm osd-before \
  "\$Q settings section Appearance; sleep 3" \
  "$(ok 'the ring is on the overlay layer' "hyprctl layers | grep -q taylor-osd")" \
  "hyprctl layers | grep -B3 -A3 taylor-osd; wpctl status | sed -n '/Sinks/,/Sources/p' | head -12; wpctl get-volume @DEFAULT_AUDIO_SINK@"
$V key volumeup; sleep 0.25; $V key volumeup; sleep 0.4
shot osd-volume-up
sleep 2.6
shot osd-gone
$V key volumedown; sleep 0.5
shot osd-volume-down
sleep 2.6
$V key audiomute; sleep 0.5
shot osd-muted
sleep 3
vm osd \
  "$(ok 'the volume keys show the ring' "$L | grep -qE 'taylor-osd: volume [0-9]+'")" \
  "$(ok 'mute shows the ring as Muted' "$L | grep -q 'taylor-osd: muted'")" \
  "$(ok 'the ring fades on its own' "$L | grep -q 'taylor-osd: gone'")" \
  "$(ok 'the ring never takes the keyboard from the window in use' "hyprctl activewindow | grep -q 'title: Settings'")" \
  "$L | grep -E 'taylor-osd' | tail -6" \
  "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0"

# 7. Warmer colours at night and the TAYLOR switches (real clicks), then everything back
vm display-open "\$Q settings section Display; sleep 3" "$AT" "$PLACES"
shot display
tap display-open warm; sleep 4
vm warm \
  "$(ok 'warmer colours at night starts hyprsunset' "grep -q '\"warmNight\": *true' ~/.config/taylor-os/settings.json && pgrep -u tester -x hyprsunset >/dev/null")" \
  "$L | grep -E 'taylor-warm|warmer' | tail -4; hyprsunset --help 2>&1 | head -5"
shot display-warm
tap display-open warm; sleep 3
vm warm-off \
  "$(ok 'switching it off stops hyprsunset' "grep -q '\"warmNight\": *false' ~/.config/taylor-os/settings.json && ! pgrep -u tester -x hyprsunset >/dev/null")" \
  "\$Q settings section TAYLOR; sleep 3" "$AT" "$PLACES"
tap warm-off statusline; sleep 3
shot taylor-status-off
vm status-off \
  "$(ok 'the status line switch writes her setting' "grep -q '\"statusLine\": *false' ~/.config/taylor-os/settings.json")"
tap warm-off statusline; sleep 2
vm settings-end \
  "$(ok 'the status line comes back on' "grep -q '\"statusLine\": *true' ~/.config/taylor-os/settings.json")" \
  "$(ok 'the shell is still running after all of it' "pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'Settings left no QML errors' "! $L | grep -iE 'Settings.qml|Osd.qml|Brightness.qml|Warm.qml' | grep -qiE 'error|TypeError|ReferenceError|is not defined|Unable to assign'")" \
  "$L | grep -iE 'warn|error' | grep -iE 'Settings|Osd|Brightness|Warm' | tail -20" \
  "\$Q settings close"
shot settings-closed
