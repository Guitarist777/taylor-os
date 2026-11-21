#!/bin/bash
# Helper for the mixer check (.github/vm/checks/mixer.sh), copied into the virtual PC as ~/mx and run as her test account.
#   mx pretend               two silent pretend outputs, "Speakers" and a "SteelSeries Arctis Nova Pro Wireless" (the
#                            virtual PC has no sound card)
#   mx tone NAME FREQ ROLE   a test tone played by an app called NAME (in the background); mx untone NAME stops it
#   mx q FUNCTION [ARGS]     quickshell ipc call mixer FUNCTION ARGS
#   mx t 'PYTHON'            true when the expression holds on the mixer's state (d), e.g. mx t "d['ch']['game']['muted']"
#   mx at SPOT               "AT x y": where a part of the mixer is on the screen (see MixerCore.where)
#   mx node NAME             the PipeWire id of a node
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
QS=$(pgrep -u "$(id -u)" -x quickshell | head -1)
q() { quickshell ipc --pid "$QS" call mixer "$@" 2>&1; }
case "$1" in
  pretend)
    pactl list sinks short | grep -q pretend_speakers || pactl load-module module-null-sink sink_name=pretend_speakers "sink_properties=device.description=Speakers priority.session=1500" >/dev/null
    pactl list sinks short | grep -q pretend_arctis || pactl load-module module-null-sink sink_name=pretend_arctis "sink_properties=device.description=\"SteelSeries Arctis Nova Pro Wireless\" priority.session=1400" >/dev/null
    pactl set-default-sink pretend_speakers ;;
  tone)
    cat > "/tmp/tone-$2.py" <<EOF
import math,struct,sys
f=$3;r=48000;a=8000
one=b"".join(struct.pack("<hh",int(a*math.sin(2*math.pi*f*i/r)),int(a*math.sin(2*math.pi*f*i/r))) for i in range(r))
try:
    while True: sys.stdout.buffer.write(one)
except BrokenPipeError: pass
EOF
    setsid -f bash -c "python3 /tmp/tone-$2.py | pw-play -a --format s16 --rate 48000 --channels 2 --media-role $4 -P '{ application.name = \"$2\" }' - " >/dev/null 2>&1 ;;
  untone) pkill -f "tone-$2.py"; sleep 0.5 ;;
  q) shift; q "$@" ;;
  t) q state | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($2) else 1)" ;;
  at)
    w=$(q where "$2"); [ -z "$w" ] && { echo "AT none"; exit 1; }
    set -- "$2" $w
    case "$1" in
      w:*) echo "AT $(( $2 + 40 )) $(( $3 + 138 ))" ;;     # the desktop mixer's own window: 40 from the left, 138 from the top
      *) hyprctl -j clients | python3 -c "
import json,sys
c=[c for c in json.load(sys.stdin) if c.get('title')=='Mixer']
print('AT', c[0]['at'][0]+$2, c[0]['at'][1]+$3) if c else print('AT none')" ;;
    esac ;;
  fxcheck)   # mx fxcheck CHANNEL BAND: the running filter's values for that band match what the window shows
    q state > /tmp/mx-state.json
    pw-dump > /tmp/mx-dump.json
    python3 - "$2" "$3" <<'PY'
import json, sys
k, i = sys.argv[1], int(sys.argv[2])
b = json.load(open("/tmp/mx-state.json"))["fx"][k]["b"][i - 1]
d = json.load(open("/tmp/mx-dump.json"))
n = [o for o in d if o.get("info", {}).get("props", {}).get("node.name") == "taylor_%s_fx" % k][0]
p = [x["params"] for x in n["info"]["params"]["Props"] if "params" in x and str(x["params"][0]).startswith("b1:")][0]
m = dict(zip(p[0::2], p[1::2]))
f, g, q = m["b%d:Freq" % i], m["b%d:Gain" % i], m["b%d:Q" % i]
print("FILTER", f, g, q, "SHOWN", b)
sys.exit(0 if abs(f - b[0]) < 2 and abs(g - b[1]) < 0.2 and abs(q - b[2]) < 0.02 else 1)
PY
    ;;
  node) pw-dump | python3 -c "import json,sys; print(next((o['id'] for o in json.load(sys.stdin) if o['type'].endswith(':Node') and o.get('info',{}).get('props',{}).get('node.name')=='$2'), ''))" ;;
esac
