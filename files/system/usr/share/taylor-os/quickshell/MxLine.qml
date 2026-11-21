// A thin line that is a slider (her design tour, the mixer): a 2 px track, the filled part in green, a small white
// dot at the value; press or drag anywhere along it. Horizontal, or upright (vertical: true, a fader).
// centred: true fills from the middle (a balance). Arrow keys step it when it has the focus.
import QtQuick

Item {
    id: l
    property real from: 0
    property real to: 1
    property real value: 0
    property bool vertical: false
    property bool centred: false
    property bool grey: false            // muted: the filled part turns grey
    property bool active: true
    property real step: (to - from) / 20
    signal moved(real v)
    implicitWidth: vertical ? 18 : 120
    implicitHeight: vertical ? 132 : 16
    activeFocusOnTab: true

    readonly property real u: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property real len: vertical ? height : width

    Rectangle {      // the track
        x: l.vertical ? (l.width - 2) / 2 : 0
        y: l.vertical ? 0 : 7
        width: l.vertical ? 2 : l.width
        height: l.vertical ? l.height : 2
        radius: 1
        color: Theme.track
    }
    Rectangle {      // the filled part
        readonly property real a: l.centred ? Math.min(l.u, 0.5) : 0
        readonly property real b: l.centred ? Math.max(l.u, 0.5) : l.u
        x: l.vertical ? (l.width - 2) / 2 : a * l.width
        y: l.vertical ? (1 - b) * l.height : 7
        width: l.vertical ? 2 : (b - a) * l.width
        height: l.vertical ? (b - a) * l.height : 2
        radius: 1
        color: l.grey ? Theme.mix(Theme.track, Theme.muted, 0.45) : Theme.accent
    }
    Rectangle {      // the dot
        width: 8; height: 8; radius: 4
        x: l.vertical ? (l.width - 8) / 2 : l.u * l.width - 4
        y: l.vertical ? (1 - l.u) * l.height - 4 : 4
        color: Theme.text
        opacity: l.active ? 1 : 0.5
    }
    Rectangle {      // keyboard focus: a thin green ring
        visible: l.activeFocus
        anchors.fill: parent; anchors.margins: -3
        color: "transparent"; radius: 4
        border.color: Theme.accent; border.width: 1
    }
    function setAt(px) {
        if (!active) return;
        let u = vertical ? 1 - px / height : px / width;
        u = Math.max(0, Math.min(1, u));
        let v = from + u * (to - from);
        if (centred && Math.abs(u - 0.5) < 0.02) v = from + 0.5 * (to - from);
        moved(v);
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: l.vertical ? -4 : -3
        cursorShape: l.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: (e) => { l.forceActiveFocus(); l.setAt(l.vertical ? e.y - 4 : e.x - 3); }
        onPositionChanged: (e) => { if (pressed) l.setAt(l.vertical ? e.y - 4 : e.x - 3); }
        onWheel: (w) => { if (l.active) l.moved(Math.max(l.from, Math.min(l.to, l.value + (w.angleDelta.y > 0 ? 1 : -1) * l.step * 0.5))); }
    }
    Keys.onPressed: (e) => {
        const up = e.key === Qt.Key_Right || e.key === Qt.Key_Up, dn = e.key === Qt.Key_Left || e.key === Qt.Key_Down;
        if (up || dn) { e.accepted = true; moved(Math.max(from, Math.min(to, value + (up ? step : -step)))); }
    }
}
