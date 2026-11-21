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
    // Lock and timeout (minutes)
    property alias idleMinutes: a.idleMinutes       // before the dimming starts (default 3)
    property alias waitMinutes: a.waitMinutes       // TAYLOR waits in the middle (default 2)
    property alias stayAwakeForMedia: a.stayAwakeForMedia
    property alias lockOnSleep: a.lockOnSleep
    // TAYLOR
    property alias showTaylor: a.showTaylor
    property alias statusLine: a.statusLine
    property alias askTaylor: a.askTaylor
    // Display
    property alias brightness: a.brightness
    property alias warmNight: a.warmNight           // warmer colours at night (hyprsunset, Warm.qml)
    // About: the last "Check now" (uptodate | staged | newer | offline | unknown, and when, in ms)
    property alias updateState: a.updateState
    property alias updateCheckedAt: a.updateCheckedAt
    // the last app picked in each dock group slot (an app id, e.g. "firefox", "steam"; "" = the first)
    property alias lastBrowser: a.lastBrowser
    property alias lastGames: a.lastGames

    function save() { fv.writeAdapter(); }

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
            property real idleMinutes: 3
            property real waitMinutes: 2
            property bool stayAwakeForMedia: true
            property bool lockOnSleep: true
            property bool showTaylor: true
            property bool statusLine: true
            property bool askTaylor: true
            property real brightness: 80
            property bool warmNight: false
            property string updateState: ""
            property real updateCheckedAt: 0
            property string lastBrowser: ""
            property string lastGames: ""
        }
    }
}
