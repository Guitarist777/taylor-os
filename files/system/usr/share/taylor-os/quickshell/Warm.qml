// Warmer colours at night (Settings > Display), with hyprsunset: from 20:00 to 07:00 the screen is warmer (4500 K),
// by day it is left as it is. On while her Settings switch is on; switching it off stops hyprsunset, which gives the
// screen its own colours back. The times are in ~/.config/hypr/hyprsunset.conf, made from TaylorOS's copy the first
// time (a file of her own there is used as it is).
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    Process {
        running: Prefs.warmNight
        command: ["sh", "-c", "command -v hyprsunset >/dev/null || { echo 'taylor-warm: hyprsunset is not installed'; exit 3; }; " +
            "c=\"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprsunset.conf\"; [ -f \"$c\" ] || { mkdir -p \"$(dirname \"$c\")\" && cp /usr/share/taylor-os/hyprsunset.conf \"$c\"; }; " +
            "echo 'taylor-warm: on'; exec hyprsunset"]
        stdout: SplitParser { onRead: (l) => { if (l.startsWith("taylor-warm")) console.info(l); } }
        onRunningChanged: if (!running) console.info("taylor-warm: " + (Prefs.warmNight ? "hyprsunset stopped" : "off"))
    }
}
