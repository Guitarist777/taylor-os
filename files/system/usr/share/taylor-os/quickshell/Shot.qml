// A screenshot's little picture in the bottom right (her ask 2026-11-27, the Mac's): it slides in just above the tray
// and stays about 6 s (longer while the pointer is on it).
//   * Drag it into an app (Claude, a message, a folder) and it goes there and is NOT saved to her PC.
//   * Leave it and it is saved to Pictures/Screenshots when it goes.
//   * Click it: saved, and it opens.        * The x on it (on hover): thrown away, not saved.
// Until then the picture lives only in her session's memory folder ($XDG_RUNTIME_DIR/taylor-shots, gone at sign-out;
// taylor-screenshot clears anything older than 30 minutes). taylor-screenshot captures, then calls pop(path) here (ipc: "shot pop"); a
// new screenshot first calls away(), so this picture is kept and never lands in the next one.
// It never takes the keyboard; it is on the Overlay layer so it shows over a full-screen window too.
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property string path: ""             // the picture now showing ("" = none)
    property bool out: false             // sliding away
    property string grabbed: ""          // the small picture the pointer carries while dragging

    readonly property int pad: 12
    readonly property real ratio: img.implicitWidth > 0 ? img.implicitHeight / img.implicitWidth : 0.5625
    readonly property real cw: Math.round(Math.min(260, 300 / Math.max(0.05, ratio)))
    readonly property real ch: Math.round(cw * ratio)

    anchors { bottom: true; right: true }
    margins { bottom: 66; right: 2 }      // the tray is 52 high, 14 up: this sits just above it
    implicitWidth: cw + 2 * pad
    implicitHeight: ch + 2 * pad
    visible: path !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "taylor-shot"

    function run(what, p, then) {
        Quickshell.execDetached(["sh", "-c", "/usr/libexec/taylor-screenshot " + what + " \"$1\"" + (then || ""), "sh", p]);
    }
    // keep = saved to Pictures/Screenshots; open = saved, then opened; forget = thrown away
    function finish(how) {
        if (!win.path) return;
        const p = win.path;
        console.info("taylor-shot: " + how);
        if (how === "keep") run("keep", p);
        else if (how === "open") run("keep", p, " | xargs -r -d '\\n' xdg-open");
        else if (how === "forget") run("forget", p);
        // "dropped": it went into an app; the file stays in the memory folder for the app to read
        win.path = ""; win.grabbed = ""; win.out = false;
        life.stop();
    }
    function show(p) {
        if (win.path) finish("keep");
        win.out = false; win.grabbed = "";
        win.path = p;
        if (win.theme && win.theme.still) slide.x = 0; else slideIn.restart();
        life.restart();
        console.info("taylor-shot: showing");
    }
    function away() { if (win.path) finish("keep"); }

    Timer {
        id: life
        interval: 6000
        running: false
        onTriggered: if (ma.containsMouse || xm.containsMouse || ma.drag.active) restart(); else win.out = true
    }
    Timer { id: gone; interval: 260; running: win.out; onTriggered: win.finish("keep") }

    Item {
        id: slide
        x: 0
        width: win.cw + 2 * win.pad; height: win.ch + 2 * win.pad
        opacity: win.out ? 0 : 1
        NumberAnimation on x { id: slideIn; running: false; from: win.cw + win.pad; to: 0; duration: 260; easing.type: Easing.OutCubic }
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Rectangle {              // a soft shadow
            x: win.pad - 2; y: win.pad + 1; width: win.cw + 4; height: win.ch + 4; radius: 12
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        ClippingRectangle {      // rounds the picture itself (a plain Rectangle's clip is square)
            id: card
            x: win.pad; y: win.pad; width: win.cw; height: win.ch; radius: 10
            color: win.theme ? win.theme.panel : "#161a18"
            Image {
                id: img
                anchors.fill: parent
                source: win.path ? "file://" + win.path : ""
                sourceSize.width: 520
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                onStatusChanged: if (status === Image.Ready) card.grabToImage(r => win.grabbed = r.url, Qt.size(win.cw * 0.6, win.ch * 0.6))
            }
            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.28) }
            scale: ma.pressed && !ma.drag.active ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }

        // what the drag carries: the file itself (text/uri-list is what apps and Files take as a dropped file)
        Item {
            id: carry
            width: card.width; height: card.height
            Drag.active: ma.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.proposedAction: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(win.path) + "\r\n" })
            Drag.imageSource: win.grabbed
            Drag.hotSpot.x: card.width * 0.3; Drag.hotSpot.y: card.height * 0.3
            Drag.onDragStarted: console.info("taylor-shot: drag started")
            Drag.onDragFinished: (action) => {
                carry.x = 0; carry.y = 0;
                if (action !== Qt.IgnoreAction) win.finish("dropped");
                else { console.info("taylor-shot: drag let go nowhere"); life.restart(); }
            }
        }
        MouseArea {
            id: ma
            x: win.pad; y: win.pad; width: win.cw; height: win.ch
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: carry
            drag.threshold: 6
            onClicked: win.finish("open")
        }
        // the x, on hover: throw it away
        Rectangle {
            id: xBtn
            objectName: "shotx"
            x: win.pad + 6; y: win.pad + 6; width: 24; height: 24; radius: 12
            color: xm.containsMouse ? Qt.rgba(0, 0, 0, 0.85) : Qt.rgba(0, 0, 0, 0.6)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
            opacity: ma.containsMouse || xm.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: "×"; color: "#EDEFEE"; font.pixelSize: 17; font.family: win.theme ? win.theme.sans : "" }
            MouseArea { id: xm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: win.finish("forget") }
        }
    }
}
