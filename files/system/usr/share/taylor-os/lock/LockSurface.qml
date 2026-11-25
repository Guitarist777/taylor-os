// Her lock screen on one screen, while the session is locked (Quickshell's WlSessionLock gives one per screen).
import Quickshell
import Quickshell.Wayland
import QtQuick

WlSessionLockSurface {
    id: surf
    property string mode: "now"
    property string who: ""
    property real fade: 0
    property bool primary: false
    readonly property alias scene: sceneItem
    signal keyTyped(string text)
    signal keyErase()
    signal keyEnter()
    signal keyEscape()
    signal keyNote(string s)
    color: "#0B0D0C"

    LockScene {
        id: sceneItem
        anchors.fill: parent
        primary: surf.primary
        mode: surf.mode
        who: surf.who
        fade: surf.fade
        onKeyTyped: (t) => surf.keyTyped(t)
        onKeyErase: surf.keyErase()
        onKeyEnter: surf.keyEnter()
        onKeyEscape: surf.keyEscape()
        onKeyNote: (s) => surf.keyNote(s)
    }
}
