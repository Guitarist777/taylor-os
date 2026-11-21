# Her mixer (2026-11-21; her brief's "Mixer on the desktop", "Mixer window" and her headset), step 1: the six channels,
# per-app routing that is remembered, mute from the desktop mixer, each channel's own output.
# The virtual PC has no sound card: two silent pretend outputs stand in for her speakers and her headset, and two test
# tones play as two "apps" (Game1, a game; Music1, music).
. .github/vm/checks/lib.sh

# copy the helper in (in pieces: the console takes short lines)
b64=$(base64 -w0 .github/vm/checks/mixer-helper.sh)
parts=()
for ((i = 0; i < ${#b64}; i += 900)); do parts+=("printf %s '${b64:i:900}' >> ~/mx.b64"); done
vm mixer-setup "rm -f ~/mx.b64" "${parts[@]}" "base64 -d ~/mx.b64 > ~/mx && chmod +x ~/mx && echo helper-in" \
  "~/mx pretend; sleep 2" "~/mx tone Game1 440 Game; ~/mx tone Music1 660 Music; sleep 4" "$WH"
SW=$(screen mixer-setup | cut -d' ' -f1); SH=$(screen mixer-setup | cut -d' ' -f2)
SW=${SW:-1280}; SH=${SH:-800}
# wake the virtual PC's pointer (an absolute tablet: its first events can be lost) and log where Hyprland has it
for p in "300 600" "320 620" "640 700"; do $V move $p $SW $SH; sleep 0.7; done
vm mixer-pointer "hyprctl cursorpos"

expect mixer 31
vm mixer-channels \
  "$(ok 'the mixer channels Game, Chat, Media and Aux exist in PipeWire' "test \$(pw-cli ls Node | grep -cE 'node.name = \"taylor_(game|chat|media|aux)(\\.out)?\"') -eq 8")" \
  "$(ok 'the desktop mixer is on her screen' "hyprctl layers | grep -q taylor-mixer")" \
  "$(ok 'a game sound lands in Game and a music sound in Media' "~/mx t \"'Game1' in d['ch']['game']['apps'] and 'Music1' in d['ch']['media']['apps']\"")" \
  "$(ok 'the desktop mixer shows live level dots for Game and Media' "~/mx t \"d['ch']['game']['dots'] > 3 and d['ch']['media']['dots'] > 3 and d['ch']['chat']['dots'] == 0\"")" \
  "$(ok 'channels with nothing playing are marked quiet' "~/mx t \"d['ch']['game']['playing'] and not d['ch']['aux']['playing']\"")" \
  "~/mx q state" "~/mx at w:mute:game" "pw-link -l | grep -A2 '^taylor_' | head -40"
shot mixer-widget

# mute Game from the desktop mixer (its green dot), and back
at=$(tr -d '\r' < out/mixer-channels.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$at" ]; then $V click $at $SW $SH; sleep 1; fi
vm mixer-mute \
  "$(ok 'a click on the green dot mutes Game' "wpctl get-volume \$(~/mx node taylor_game) | grep -q MUTED")" "hyprctl cursorpos"
shot mixer-widget-muted
if [ -n "$at" ]; then $V click $at $SW $SH; sleep 1; fi
vm mixer-unmute "$(ok 'a second click plays Game again' "! wpctl get-volume \$(~/mx node taylor_game) | grep -q MUTED")"

# the Mixer window: drag Music1 from Media onto Chat
vm mixer-open "~/mx q open; sleep 3" \
  "$(ok 'the Mixer window opens from the mixer ipc' "hyprctl -j clients | grep -q '\"title\": \"Mixer\"'")" \
  "$(ok 'the Mixer window floats' "hyprctl -j clients | python3 -c \"import json,sys; c=[c for c in json.load(sys.stdin) if c['title']=='Mixer']; sys.exit(0 if c and c[0]['floating'] else 1)\"")" \
  "~/mx at app:Music1" "~/mx at fader:chat"
shot mixer-window
from=$(tr -d '\r' < out/mixer-open.txt | grep -oE 'AT [0-9]+ [0-9]+' | sed -n 1p | cut -d' ' -f2-)
to=$(tr -d '\r' < out/mixer-open.txt | grep -oE 'AT [0-9]+ [0-9]+' | sed -n 2p | cut -d' ' -f2-)
if [ -n "$from" ] && [ -n "$to" ]; then $V drag $from $to $SW $SH; sleep 2; fi
shot mixer-window-moved
vm mixer-moved \
  "$(ok 'dragging Music1 onto Chat moves its sound there' "~/mx t \"'Music1' in d['ch']['chat']['apps']\" && pw-link -l | grep -A3 '^taylor_chat:playback_FL' | grep -q pw-play")" \
  "hyprctl cursorpos"
# (if the drag did not land, the move is made by the mixer's ipc so the rest is still checked; the report says so)
vm mixer-moved-rest "~/mx ensure moved" \
  "$(ok 'PipeWire has the new target for Music1' "pw-metadata | grep -q \"target.object' value:'taylor_chat'\"")" \
  "$(ok 'the move is remembered for Music1' "grep -q '\"Music1\": *\"chat\"' ~/.config/taylor-os/mixer.json")" \
  "~/mx untone Music1; sleep 1; ~/mx tone Music1 660 Music; sleep 4" \
  "$(ok 'Music1 goes back to Chat when its sound starts again' "~/mx t \"'Music1' in d['ch']['chat']['apps'] and 'Music1' not in d['ch']['media']['apps']\"")" \
  "~/mx q state; cat ~/.config/taylor-os/mixer.json"

# each channel's own output: the word under Game's name
vm mixer-outword "~/mx at out:game"
ow=$(tr -d '\r' < out/mixer-outword.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$ow" ]; then $V click $ow $SW $SH; sleep 3; fi
vm mixer-output \
  "$(ok 'clicking the word under Game sends Game to the headset' "~/mx t \"d['ch']['game']['out'] == 'Headset' and d['ch']['game']['to'] == 'pretend_arctis' and d['ch']['media']['to'] == 'pretend_speakers'\"")" \
  "$(ok 'the desktop shell loaded the mixer with no QML errors' "! timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -iE 'error|ReferenceError|TypeError|is not defined' | grep -qiE 'mixer|Mx'")" \
  "~/mx q state" "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -iE 'taylor-mixer|mixer|Mx' | tail -30"
shot mixer-window-output

# ---- step 2: the equalizer (Game) ----
vm mixer-eqtab "~/mx at tab:Game"
tg=$(tr -d '\r' < out/mixer-eqtab.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$tg" ]; then $V click $tg $SW $SH; sleep 2; fi
vm mixer-eqband "~/mx ensure tab Game; sleep 1" "~/mx at eq:band:7" "~/mx q state | python3 -c \"import json,sys; print('BAND7', json.load(sys.stdin)['fx']['game']['b'][6])\""
shot mixer-eq-flat
b7=$(tr -d '\r' < out/mixer-eqband.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$b7" ]; then
  set -- $b7
  $V drag $1 $2 $(( $1 + 50 )) $(( $2 - 40 )) $SW $SH; sleep 4
fi
vm mixer-eqdrag \
  "$(ok 'dragging an equalizer dot moves the band sideways and up' "~/mx t \"d['fx']['game']['b'][6][0] > 2300 and d['fx']['game']['b'][6][1] > 3\"")" \
  "hyprctl cursorpos"
vm mixer-eqrest "~/mx ensure eq" \
  "$(ok 'the Game channel now plays through its own sound-shaping filter' "~/mx t \"d['fx']['game']['node']\" && pw-link -l | grep -A1 '^taylor_game.out:output_FL' | grep -q taylor_game_fx")" \
  "$(ok 'the running filter has the band values that were dragged' "~/mx fxcheck game 7")" \
  "~/mx at eq:band:7"
shot mixer-eq-dragged
b7=$(tr -d '\r' < out/mixer-eqrest.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$b7" ]; then set -- $b7; $V scroll $1 $2 $SW $SH 3; sleep 2; $V scroll $1 $(( $2 + 60 )) $SW $SH 3; sleep 2; fi
vm mixer-eqscroll \
  "$(ok 'scrolling over a band dot narrows it and scrolling elsewhere does nothing' "~/mx t \"abs(d['fx']['game']['b'][6][2] - 1.4*1.12**3) < 0.05\"")" \
  "~/mx q state | python3 -c \"import json,sys; print('BAND7', json.load(sys.stdin)['fx']['game']['b'][6])\""
vm mixer-eqpreset "~/mx q preset game Footsteps; sleep 2" \
  "$(ok 'a game preset changes the curve and the running filter' "~/mx t \"d['fx']['game']['pre'] == 'Footsteps' and d['fx']['game']['b'][7][1] == 7\" && ~/mx fxcheck game 8")"
shot mixer-eq-preset
# Follow the game: a full-screen window of a game with a preset (Deadlock's Steam id) picks Game's preset
vm mixer-follow "WAYLAND_DISPLAY=\$(basename \$(ls /run/user/1000/wayland-* | grep -v lock | head -1)) setsid -f kitty --class steam_app_1422450 --start-as=fullscreen >/dev/null 2>&1; sleep 7" \
  "hyprctl -j activewindow | grep -E 'class|fullscreen'" \
  "$(ok 'Follow the game switches Game to the game preset of the full-screen game' "~/mx t \"d['fx']['game']['pre'] == 'Deadlock'\"")" \
  "pkill -f 'class steam_app_1422450'; sleep 2"

# ---- step 3: compressor, noise gate, background noise reduction, spatial audio ----
vm mixer-comp-open "~/mx q sub Compressor; sleep 1" "~/mx at comp:onoff"
cs=$(tr -d '\r' < out/mixer-comp-open.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$cs" ]; then $V click $cs $SW $SH; sleep 5; fi
vm mixer-comp \
  "$(ok 'the Compressor switch puts a compressor in the Game filter' "~/mx t \"d['fx']['game']['comp']['on'] and d['fx']['game']['node']\" && ~/mx param taylor_game_fx 'comp:Ratio (1:n)' 3")" \
  "hyprctl cursorpos; ~/mx ensure comp" \
  "~/mx q part game comp th -24; sleep 2" \
  "$(ok 'moving the compressor threshold changes the running filter' "~/mx param taylor_game_fx 'comp:Threshold level (dB)' -24")"
shot mixer-compressor
vm mixer-sp-open "~/mx q sub 'Spatial audio'; sleep 1" "~/mx at sp:onoff"
ss=$(tr -d '\r' < out/mixer-sp-open.txt | grep -oE 'AT [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-)
if [ -n "$ss" ]; then $V click $ss $SW $SH; sleep 6; fi
vm mixer-spatial \
  "$(ok 'the Spatial audio switch turns it on' "~/mx t \"d['fx']['game']['sp']['on']\"")" \
  "hyprctl cursorpos; ~/mx ensure sp" \
  "$(ok 'Spatial audio on places seven virtual speakers with the head measurements' "test \$(grep -c 'label = spatializer' ~/.config/taylor-os/mixer-fx/game.conf) -eq 7 && ~/mx t \"d['fx']['game']['sp']['on'] and d['fx']['game']['node']\" && pw-link -l | grep -A1 '^taylor_game.out:output_FL' | grep -q taylor_game_fx")" \
  "~/mx q part game sp imm 1; sleep 2" \
  "$(ok 'the immersive end gives the back speakers more' "~/mx param taylor_game_fx 'sp_ol:Gain 6' 0.5")" \
  "journalctl --user -u taylor-mixer-fx@game -n 20 --no-pager | tail -8"
shot mixer-spatial
vm mixer-gate "~/mx q tab Chat; sleep 1; ~/mx q sub 'Noise gate'; ~/mx q part chat gate auto false; ~/mx q part chat gate th -40; ~/mx q part chat gate on true; sleep 6" \
  "$(ok 'the Chat noise gate runs with her threshold' "~/mx param taylor_chat_fx 'gate_l:Threshold (dB)' -40")"
shot mixer-gate
vm mixer-noise "~/mx q tab Mic; sleep 1; ~/mx q noise true; sleep 7" \
  "$(ok 'background noise reduction makes a cleaner microphone that apps record from' "pw-cli ls Node | grep -q 'node.name = \"taylor_mic_ns\"' && wpctl inspect @DEFAULT_AUDIO_SOURCE@ | grep -q 'node.name = \"taylor_mic_fx\"'")" \
  "$(ok 'no QML errors after the sound shaping' "! timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -iE 'error|ReferenceError|TypeError|is not defined' | grep -qiE 'mixer|Mx|pipewire'")" \
  "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -iE 'error|warn' | tail -15" \
  "systemctl --user list-units 'taylor-mixer-fx@*' --no-pager | head"
shot mixer-noise

# live equalizer (2026-11-21, her "react in real time"): opening a flat channel's page starts its filter, so the first
# drag is a live change and not a filter start; closing the Mixer stops it again (flat channels: no filter)
vm mixer-warm "~/mx q open; sleep 1; ~/mx q tab Aux; sleep 6" \
  "$(ok 'opening a flat channel page starts its filter so the first drag is live' "systemctl --user is-active --quiet taylor-mixer-fx@aux && timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -q 'aux page open'")" \
  "~/mx q close; sleep 5" \
  "$(ok 'closing the Mixer stops the filter of a flat channel' "! systemctl --user is-active --quiet taylor-mixer-fx@aux")" \
  "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -E 'page open|window shut|aux' | tail -6"
