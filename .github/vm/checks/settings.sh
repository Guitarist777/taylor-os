# Her Settings window and the volume and brightness ring (2026-11-21). Real clicks on the real window: where each control
# is comes from Settings' own log ("taylor-settings: place NAME x y", window pixels) plus where Hyprland put the window.
. .github/vm/checks/lib.sh
expect settings 42
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
  "\$Q call settings open; sleep 4" \
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
  "$(ok 'brightness hides itself when no monitor answers' "[ \"\$(\$Q call brightness get)\" = -1 ] && $L | grep -q 'no monitor answers DDC/CI'")" \
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
  "\$Q call settings section Appearance; sleep 3" "$AT" "$PLACES"

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
    "\$Q call settings close; sleep 3"
  shot "scheme-$s-desktop"
  vm "scheme-$s-open" "\$Q call settings section Appearance; sleep 3" "$AT" "$PLACES"
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
vm lock-open "\$Q call settings section Lock-and-timeout; sleep 3" "$AT" "$PLACES"
tap lock-open idle -25; sleep 2     # left of the middle: about 10 minutes
tap lock-open wait -30; sleep 2     # about 3 minutes
shot lock-changed
vm lock \
  "t=\$($L | grep -oE 'lock total=[0-9.]+ idle=[0-9.]+ wait=[0-9.]+' | tail -1); echo \"LINE \$t\"; python3 -c 'import json,os,sys; p=json.load(open(os.path.expanduser(\"~/.config/taylor-os/settings.json\"))); kv=dict(x.split(\"=\") for x in sys.argv[1].split()[1:]); i,w=p[\"idleMinutes\"],p[\"waitMinutes\"]; sys.exit(0 if kv and float(kv[\"total\"])==i+w and float(kv[\"idle\"])==i and float(kv[\"wait\"])==w and (i,w)!=(3,2) else 1)' \"\$t\" && echo 'PASS the two timeout times are written and the total adds them up' || echo 'FAIL the two timeout times are written and the total adds them up'" \
  "grep -E 'idleMinutes|waitMinutes' ~/.config/taylor-os/settings.json"

# 6. The volume and brightness ring, from the real volume keys, while Settings is the window in use
vm osd-before \
  "\$Q call settings section Appearance; sleep 3" \
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
vm display-open "\$Q call settings section Display; sleep 3" "$AT" "$PLACES"
shot display
tap display-open warm; sleep 4
vm warm \
  "$(ok 'warmer colours at night starts hyprsunset' "grep -q '\"warmNight\": *true' ~/.config/taylor-os/settings.json && pgrep -u tester -x hyprsunset >/dev/null")" \
  "$L | grep -E 'taylor-warm|warmer' | tail -4; hyprsunset --help 2>&1 | head -5"
shot display-warm
tap display-open warm; sleep 3
vm warm-off \
  "$(ok 'switching it off stops hyprsunset' "grep -q '\"warmNight\": *false' ~/.config/taylor-os/settings.json && ! pgrep -u tester -x hyprsunset >/dev/null")" \
  "\$Q call settings section TAYLOR; sleep 3" "$AT" "$PLACES"
tap warm-off statusline; sleep 3
shot taylor-status-off
vm status-off \
  "$(ok 'the status line switch writes her setting' "grep -q '\"statusLine\": *false' ~/.config/taylor-os/settings.json")"
tap warm-off statusline; sleep 2
# 8. The mixer in Settings (her ask 2026-11-23): its quick view on the desktop turns off and on (real clicks), and
#    "Open the mixer" opens the Mixer window
vm sound-open "\$Q call settings section Sound; sleep 3" "$AT" "$PLACES"
shot settings-sound-mixer
tap sound-open mixerwidget; sleep 3
vm mixerwidget-off \
  "$(ok 'switching the mixer on the desktop off writes her setting' "grep -q '\"mixerWidget\": *false' ~/.config/taylor-os/settings.json")" \
  "$(ok 'with it off the mixer is not on the desktop' "! hyprctl layers | grep -q taylor-mixer")"
tap sound-open mixerwidget; sleep 3
vm mixerwidget-on \
  "$(ok 'switching it back on brings the mixer back to the desktop' "grep -q '\"mixerWidget\": *true' ~/.config/taylor-os/settings.json && hyprctl layers | grep -q taylor-mixer")"
tap sound-open openmixer; sleep 3
shot settings-open-mixer
vm mixer-from-settings \
  "$(ok 'Open the mixer in Settings opens the Mixer window' "hyprctl clients | grep -q 'title: Mixer' && $L | grep -q 'taylor-settings: open the mixer'")" \
  "\$Q call mixer close; sleep 1"

# 9. Her screen (her ask 2026-11-25: Windows' Display page): a scale is tried at once and asks "Keep these display
#    settings?"; Keep writes it; a change not kept goes back by itself after 15 s; the kept one is there again after
#    Hyprland reads its settings again (display.lua); Use HDR is asked of Hyprland and Go back undoes it. (The virtual
#    screen has one mode and no HDR, so the refresh rate and HDR are checked as asked, not as shown.) At 125% the
#    clicks are given in the screen's logical size, 1024 x 640.
SCALE="hyprctl -j monitors | python3 -c 'import json,sys; print(\"SCALE\", json.load(sys.stdin)[0][\"scale\"])'"
RELOOK="\$Q call settings section Display; sleep 2"
vm screen-open "$RELOOK; sleep 2" "$AT" "$PLACES" "$SCALE" \
  "$(ok 'Display shows refresh rate, scale, HDR and variable refresh rate' "$L | grep -q 'place scale:1.25 ' && $L | grep -q 'place hdr ' && $L | grep -q 'place vrr:2 ' && $L | grep -qE 'place rate:[0-9]+ '")" \
  "$L | grep -E 'taylor-settings: screen' | tail -2"
shot settings-display
tap screen-open scale:1.25; sleep 4
WHB="1024 640"
vm screen-try "$RELOOK" "$SCALE" "$AT" "$PLACES" \
  "$(ok 'a scale picked is tried at once and asks to keep it' "$SCALE | grep -q 'SCALE 1.25' && $L | grep -q 'place keep '")"
shot settings-display-keep
tap screen-try keep; sleep 3
vm screen-kept "$(ok 'Keep writes the scale to her settings' "grep -qE '\"displayScale\": *1.25' ~/.config/taylor-os/settings.json")" "$RELOOK" "$AT" "$PLACES"
tap screen-kept scale:1; sleep 3
WHB="1280 800"
vm screen-wait "sleep 17" "$SCALE"
WHB="1024 640"
vm screen-back \
  "$(ok 'a change not kept goes back by itself after 15 s' "$SCALE | grep -q 'SCALE 1.25' && grep -qE '\"displayScale\": *1.25' ~/.config/taylor-os/settings.json && $L | grep -q 'display back to'")" \
  "hyprctl plugin list | head -2" "hyprctl reload; sleep 4" "hyprctl plugin list | head -2; hyprctl -j configerrors" \
  "$(ok 'her kept scale is there again after Hyprland reads its settings again' "$SCALE | grep -q 'SCALE 1.25'")" \
  "$RELOOK" "$AT" "$PLACES"
tap screen-back scale:0; sleep 4
WHB="1280 800"
vm screen-auto "$RELOOK" "$AT" "$PLACES" "$SCALE"
tap screen-auto keep; sleep 3
CM="hyprctl -j monitors | python3 -c 'import json,sys; print(\"CM\", json.load(sys.stdin)[0][\"colorManagementPreset\"])'"
vm screen-end "$(ok 'the scale goes back to automatic and is kept' "grep -qE '\"displayScale\": *0' ~/.config/taylor-os/settings.json")" "$SCALE" "$CM" "$RELOOK" "$AT" "$PLACES"
tap screen-end hdr; sleep 4
shot settings-display-hdr
vm screen-hdr "$CM" "$RELOOK" "$AT" "$PLACES" "$L | grep -E 'taylor-settings: display' | tail -3"
tap screen-hdr revert; sleep 4
vm screen-hdr-back \
  "$(ok 'Use HDR is asked of Hyprland and Go back undoes it' "$L | grep 'taylor-settings: display {' | grep -q '\"hdr\":true' && $L | grep -q 'taylor-settings: display back to' && grep -qE '\"hdr\": *false' ~/.config/taylor-os/settings.json && $CM | grep -q 'CM srgb'")" \
  "$CM" "$L | grep -E 'taylor-settings: display' | tail -4"

vm settings-end \
  "$(ok 'the status line comes back on' "grep -q '\"statusLine\": *true' ~/.config/taylor-os/settings.json")" \
  "$(ok 'the shell is still running after all of it' "pgrep -u tester -x quickshell >/dev/null")" \
  "$(ok 'Settings left no QML errors' "! $L | grep -iE 'Settings.qml|Osd.qml|Brightness.qml|Warm.qml' | grep -qiE 'error|TypeError|ReferenceError|is not defined|Unable to assign'")" \
  "$L | grep -iE 'warn|error' | grep -iE 'Settings|Osd|Brightness|Warm' | tail -20" \
  "\$Q call settings close"
shot settings-closed

# brightness as she drags (2026-11-21): the live helper is in the image and says plainly when it can't reach a screen
# (the virtual PC's screen doesn't speak DDC/CI, so here Brightness stays hidden and no helper runs; her real monitor
# was tried on her PC: 25-28 ms a change)
vm settings-ddc \
  "$(ok 'the live brightness helper is in the image and refuses a screen it cannot reach' "test -x /usr/libexec/taylor-ddc && echo 50 | /usr/libexec/taylor-ddc 99 | grep -q '^error: bus 99'")" \
  "$(ok 'with no monitor answering DDC/CI no live helper runs' "! pgrep -u tester -f /usr/libexec/taylor-ddc >/dev/null")"
