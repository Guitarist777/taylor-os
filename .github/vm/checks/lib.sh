# Shared helpers for the phase checks (sourced by each .github/vm/checks/NAME.sh; run on the test runner, not in the VM).
#   vm NAME CMD...    run the commands as her test account on the VM's console; saves out/NAME.txt and prints it
#   expect NAME N     this check must produce N PASS lines (counted by the verdict)
#   shot NAME         a screenshot, out/NAME.png
#   ok "what" "test"  a VM command line that prints PASS what / FAIL what
# Inside VM commands: $H sets Hyprland's instance (put it first), $Q is "quickshell ipc --pid <her desktop>".
V="python3 .github/vm/vmctl.py"
H='export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1); Q="quickshell ipc --pid $(pgrep -u tester -x quickshell | head -1)"'
vm() { local n="$1"; shift; $V run tester taylortest "out/$n.txt" "$H" "$@"; cat "out/$n.txt"; }
expect() { echo "EXPECT $2" > "out/$1-expect.txt"; }
shot() { $V shot "$PWD/out/$1.png"; }
ok() { printf "%s && echo 'PASS %s' || echo 'FAIL %s'" "$2" "$1" "$1"; }
screen() { tr -d '\r' < "out/$1.txt" | grep -oE 'SCREENWH [0-9]+ [0-9]+' | tail -1 | cut -d' ' -f2-; }
WH="hyprctl -j monitors | python3 -c 'import json,sys; m=json.load(sys.stdin)[0]; print(\"SCREENWH\", m[\"width\"], m[\"height\"])'"
# close every window left open by an earlier check (her dial sits behind windows, so a window over it takes the click; Firefox's first-run box refuses a plain close)
CLOSEALL='for a in $(hyprctl -j clients | python3 -c "import json,sys; print(\" \".join(c[\"address\"] for c in json.load(sys.stdin)))"); do hyprctl dispatch closewindow address:$a >/dev/null; done; sleep 3; pkill -u tester -f -i firefox; pkill -u tester -x kitty; pkill -u tester -x dolphin; sleep 2; hyprctl clients | grep -c "^Window" || true'
# START-CLEAN: each check starts with no windows left over from an earlier one (run as each check sources this file)
if [ -z "${NO_CLOSEALL:-}" ]; then $V run tester taylortest "out/closeall-$(date +%s%N).txt" "$H" "$CLOSEALL" "$Q call mixer close 2>/dev/null; $Q call settings close 2>/dev/null; true" >/dev/null 2>&1 || true; fi
