pragma Singleton
// Her settings (the Settings window writes them; every piece of the desktop reads them), kept in
// ~/.config/taylor-os/settings.json. A missing or broken file means the defaults below (her build brief's numbers).
// Only options that do something live here (her brief: build only options that actually do something).
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: p
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/taylor-os"
    readonly property string path: dir + "/settings.json"

    // Appearance
    property alias scheme: a.scheme                 // taylor | quiet | night | slate
    property alias slateLevel: a.slateLevel         // Slate's background, 0 black .. 1 white
    property alias skyDeeper: a.skyDeeper           // the deeper daytime sky (her brief: an option, off by default)
    property alias skyFollowsTime: a.skyFollowsTime
    property alias bootAnimation: a.bootAnimation
    property alias reduceMotion: a.reduceMotion
    property alias cursor: a.cursor                 // white (Windows-style, the default) | black (Mac-style)
    // Lock and timeout (minutes)
    property alias idleMinutes: a.idleMinutes       // before the dimming starts (default 3)
    property alias waitMinutes: a.waitMinutes       // TAYLOR waits in the middle (default 2)
    property alias stayAwakeForMedia: a.stayAwakeForMedia
    property alias lockOnSleep: a.lockOnSleep
    // TAYLOR
    property alias showTaylor: a.showTaylor
    property alias statusLine: a.statusLine
    property alias askTaylor: a.askTaylor
    // Sound: the mixer's quick view on the desktop (her ask 2026-11-23: turn it on and off in Settings)
    property alias mixerWidget: a.mixerWidget
    // Display
    property alias brightness: a.brightness
    property alias warmNight: a.warmNight           // warmer colours at night (hyprsunset, Warm.qml)
    // her screen (2026-11-25; Hyprland reads these through /usr/share/taylor-os/hypr/display.lua)
    property alias displayMode: a.displayMode       // "" = the highest refresh rate at full size, else "2560x1440@240"
    property alias displayScale: a.displayScale     // 0 = automatic, else 1 .. 2
    property alias hdr: a.hdr
    property alias sdrBrightness: a.sdrBrightness   // ordinary things while HDR is on: 0.5 .. 2, 1 = as is
    property alias vrr: a.vrr                       // variable refresh rate: 0 off, 1 on, 2 games (a full-screen window)
    // About: the last "Check now" (uptodate | staged | newer | offline | unknown, and when, in ms)
    property alias updateState: a.updateState
    property alias updateCheckedAt: a.updateCheckedAt
    // the last app picked in each dock group slot (an app id, e.g. "firefox", "steam"; "" = the first)
    property alias lastBrowser: a.lastBrowser
    property alias lastGames: a.lastGames

    function save() { fv.writeAdapter(); }

    // The file's watch is lost when the file is swapped for a new one (an editor's or a script's save writes a new file
    // and renames it over: the virtual PC test of 2026-11-21 changed her idle minutes that way and the desktop never
    // saw it). So every 4 seconds a tiny look at the file's identity and time; when they change, it is read again.
    property string stamp: ""
    Process {
        id: look
        command: ["stat", "-c", "%i %Y %s", p.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                if (s && p.stamp && s !== p.stamp) { console.info("taylor-prefs: her settings file changed; read again"); fv.reload(); }
                if (s) p.stamp = s;
            }
        }
    }
    Timer { interval: 4000; repeat: true; running: true; onTriggered: look.running = true }

    FileView {
        id: fv
        path: p.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: (err) => { if (err === FileViewError.FileNotFound) { Quickshell.execDetached(["mkdir", "-p", p.dir]); writeAdapter(); } }
        JsonAdapter {
            id: a
            property string scheme: "taylor"
            property real slateLevel: 0.19
            property bool skyDeeper: false
            property bool skyFollowsTime: true
            property bool bootAnimation: true
            property bool reduceMotion: false
            property string cursor: "white"
            property real idleMinutes: 3
            property real waitMinutes: 2
            property bool stayAwakeForMedia: true
            property bool lockOnSleep: true
            property bool showTaylor: true
            property bool statusLine: true
            property bool askTaylor: true
            property bool mixerWidget: true
            property real brightness: 80
            property bool warmNight: false
            property string displayMode: ""
            property real displayScale: 0
            property bool hdr: false
            property real sdrBrightness: 1
            property int vrr: 0
            property string updateState: ""
            property real updateCheckedAt: 0
            property string lastBrowser: ""
            property string lastGames: ""
        }
    }
}
