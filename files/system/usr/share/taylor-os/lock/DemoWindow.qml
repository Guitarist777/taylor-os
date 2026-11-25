// The lock screen without a session lock: a plain full-screen window, for the local preview only (TAYLOR_LOCK_DEMO=1).
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property string mode: "now"
    property string who: ""
    property real fade: 0
    readonly property alias scene: sceneItem
    signal keyTyped(string text)
    signal keyErase()
    signal keyEnter()
    signal keyEscape()
    signal keyNote(string s)
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#0B0D0C"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-lock-demo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    LockScene {
        id: sceneItem
        anchors.fill: parent
        primary: true
        mode: win.mode
        who: win.who
        fade: win.fade
        onKeyTyped: (t) => win.keyTyped(t)
        onKeyErase: win.keyErase()
        onKeyEnter: win.keyEnter()
        onKeyEscape: win.keyEscape()
        onKeyNote: (s) => win.keyNote(s)
    }
}
