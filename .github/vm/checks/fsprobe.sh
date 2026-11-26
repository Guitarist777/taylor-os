# A look (not a test): what a terminal and a full-screen game do to each other when she switches between them, and what
# the pointer at the top edge does over a full-screen game (her report 2026-11-26: the top bar is "touchy" over
# Deadlock, and a terminal over a full-screen game is "super hard to get it to go away"). Prints state; passes nothing.
. .github/vm/checks/lib.sh
expect fsprobe 0
W=1280; HH=800
ST="hyprctl -j clients | python3 -c 'import json,sys
for c in json.load(sys.stdin): print(\"WIN\", c[\"class\"], \"fs\", c[\"fullscreen\"], \"float\", c[\"floating\"], \"at\", c[\"at\"], \"size\", c[\"size\"], \"focus\", c[\"focusHistoryID\"])'; hyprctl -j activewindow | python3 -c 'import json,sys; a=json.load(sys.stdin); print(\"ACTIVE\", a.get(\"class\"), a.get(\"fullscreen\"))'; \$Q call windows state"

vm fsprobe-0 "$WH" \
  "hyprctl eval 'hl.exec_cmd(\"kitty --class probe_term\")'; sleep 4" \
  "hyprctl eval 'hl.exec_cmd(\"kitty --class steam_app_999 --start-as fullscreen sleep 900\")'; sleep 10" \
  "$ST"
s=$(screen fsprobe-0); [ -n "$s" ] && { W=${s% *}; HH=${s#* }; }
shot fsprobe-0-game
# the switcher (Alt + Tab) to the terminal
vm fsprobe-1 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
shot fsprobe-1-to-terminal
$V move $((W/2)) $((HH/2)) $W $HH; sleep 0.3; $V move $((W/2+40)) $((HH/2+30)) $W $HH; sleep 2
vm fsprobe-2 "$ST"
shot fsprobe-2-mouse-moved
vm fsprobe-3 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
shot fsprobe-3-back-to-game
vm fsprobe-4 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
shot fsprobe-4-terminal-again
# the terminal squared (maximised), as hers was
vm fsprobe-5 "hyprctl dispatch fullscreen 1 2>/dev/null || hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\" }))'; sleep 2" "$ST"
shot fsprobe-5-terminal-squared
vm fsprobe-6 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
shot fsprobe-6-back-to-game
$V move $((W/2)) $((HH/2)) $W $HH; sleep 2
vm fsprobe-7 "$ST"
vm fsprobe-8 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
shot fsprobe-8-terminal-again
# back to the game, then the pointer brushes the top edge for a moment
vm fsprobe-9 "\$Q call switcher next; sleep 0.4; \$Q call switcher commit; sleep 2" "$ST"
$V move $((W/2)) 0 $W $HH; sleep 0.15; $V move $((W/2)) 300 $W $HH; sleep 1
vm fsprobe-10 "$ST" "timeout 8 quickshell log --pid \$(pgrep -u tester -x quickshell | head -1) 2>&1 | grep -E 'taylor-windows: dock|taylor-switcher' | tail -20"
$V run tester taylortest out/fsprobe-end.txt "$H" "pkill -f 'class steam_app_999'; pkill -f 'class probe_term'"
