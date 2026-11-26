# Full-screen games and other windows (her report 2026-11-26, Deadlock): switching between a full-screen game and a
# terminal gives each back what it had (the game its full screen, a squared terminal its full size), and a brush of the
# top edge over the game does not bring the dock down.
. .github/vm/checks/lib.sh
expect fsgame 7
W=1280; HH=800
FQ=$(gzip -9c .github/vm/checks/fsgame_helper.py | base64 -w0)
SWITCH="\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2.5"

vm fsgame-0 "echo $FQ | base64 -d | gunzip > /tmp/fq.py && echo helper-ok" "$WH" \
  "hyprctl eval 'hl.exec_cmd(\"kitty --class probe_term\")'; sleep 4" \
  "hyprctl eval 'hl.exec_cmd(\"kitty --class steam_app_999 --start-as fullscreen sleep 900\")'; sleep 10" \
  "$(ok 'the game starts in true full screen' "python3 /tmp/fq.py active=steam_app_999 steam_app_999=2")"
s=$(screen fsgame-0); [ -n "$s" ] && { W=${s% *}; HH=${s#* }; }
vm fsgame-1 "$SWITCH" \
  "$(ok 'switching to a terminal shows it over the game, which stays full screen' "python3 /tmp/fq.py active=probe_term steam_app_999=2")"
shot fsgame-1-terminal-over-game
vm fsgame-3 "hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\" }))'; sleep 2" \
  "$(ok 'the terminal squared to full size' "python3 /tmp/fq.py active=probe_term probe_term=1")"
vm fsgame-4 "$SWITCH" \
  "$(ok 'back to the game: it has its full screen back' "python3 /tmp/fq.py active=steam_app_999 steam_app_999=2")" \
  "hyprctl repl 'taylor.tail()' | tail -6"
shot fsgame-4-game-back
vm fsgame-5 "$SWITCH" \
  "$(ok 'back to the terminal: it has its full size back' "python3 /tmp/fq.py active=probe_term probe_term=1")"
shot fsgame-5-terminal-back
vm fsgame-6 "$SWITCH" \
  "$(ok 'and the game full screen again' "python3 /tmp/fq.py active=steam_app_999 steam_app_999=2")"
shot fsgame-6-game-again
# a brush of the top edge over the game
$V move $((W/2)) $((HH/2)) $W $HH; sleep 1
$V move $((W/2)) 0 $W $HH; sleep 0.15; $V move $((W/2)) $((HH/2)) $W $HH; sleep 1.5
vm fsgame-7 \
  "$(ok 'a brush of the top edge over the game leaves the dock away' "\$Q call windows state | grep -q '\"dock\":0,'")" \
  "\$Q call windows state"
$V run tester taylortest out/fsgame-end.txt "$H" "pkill -f 'class steam_app_999'; pkill -f 'class probe_term'"
