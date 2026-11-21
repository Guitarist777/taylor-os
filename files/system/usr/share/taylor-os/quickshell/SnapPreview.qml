// Her dotted outline while dragging a window (her design tour, part 6): where the window will go when she lets go
// (a half, a quarter, or the whole screen), a faint green wash with a dotted green line, 5 px in from the zone's
// edges, rounded 10 px. Hyprland's windows.lua says which zone (Covers.qml); this only draws it. It is on the screen
// only while a drag is over a zone, takes no clicks, and is drawn above the windows (a layer cannot sit between two
// windows, so it shows over the one being dragged as well; the wash is faint enough to see through).
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    property var scr: null            // this screen (shell.qml hands it over; reading win.screen here made a binding loop)
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "taylor-snap"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // the zone, in this screen's own coordinates (Hyprland gives it in layout coordinates)
    readonly property bool here: Covers.zone !== "" && scr !== null
        && Covers.zoneRect.x >= scr.x - 1 && Covers.zoneRect.x < scr.x + scr.width
        && Covers.zoneRect.y >= scr.y - 1 && Covers.zoneRect.y < scr.y + scr.height
    property real shown: here ? 1 : 0
    Behavior on shown { NumberAnimation { duration: win.theme.ms(140); easing.type: Easing.OutCubic } }
    visible: here || shown > 0.001
    property rect r: Qt.rect(0, 0, 0, 0)
    onHereChanged: if (here) win.r = Qt.rect(Covers.zoneRect.x - scr.x, Covers.zoneRect.y - scr.y, Covers.zoneRect.width, Covers.zoneRect.height)
    Connections {
        target: Covers
        function onZoneRectChanged() { if (win.here) win.r = Qt.rect(Covers.zoneRect.x - scr.x, Covers.zoneRect.y - scr.y, Covers.zoneRect.width, Covers.zoneRect.height); }
    }

    Canvas {
        id: cv
        anchors.fill: parent
        opacity: win.shown
        property rect r: win.r
        property color acc: win.theme.accent
        onRChanged: requestPaint()
        onAccChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            if (r.width < 4 || r.height < 4) return;
            const rad = 10;
            function rr(x, y, w, h, q) {
                q = Math.max(0, Math.min(q, w / 2, h / 2));
                g.beginPath();
                g.moveTo(x + q, y);
                g.arcTo(x + w, y, x + w, y + h, q); g.arcTo(x + w, y + h, x, y + h, q);
                g.arcTo(x, y + h, x, y, q); g.arcTo(x, y, x + w, y, q);
                g.closePath();
            }
            // the wash (her tour: accent at 7 %)
            g.globalAlpha = 0.07; g.fillStyle = acc;
            rr(r.x, r.y, r.width, r.height, rad); g.fill();
            // the dotted line (her tour: dashes of 2 with gaps of 6, round ends, 1.5 px, accent at 75 %, 5 px in): drawn as
            // round 3 px dots every 8 px along the rounded outline, a little bolder than the tour so it reads on a full-size screen
            const ins = 5, x = r.x + ins, y = r.y + ins, w = r.width - 2 * ins, h = r.height - 2 * ins;
            const q = Math.max(0, Math.min(rad, w / 2, h / 2));
            const segs = [];
            const straight = (x1, y1, x2, y2) => segs.push({ k: 0, x1: x1, y1: y1, x2: x2, y2: y2, len: Math.hypot(x2 - x1, y2 - y1) });
            const corner = (cx, cy, a0) => segs.push({ k: 1, cx: cx, cy: cy, a0: a0, len: Math.PI / 2 * q });
            straight(x + q, y, x + w - q, y);         corner(x + w - q, y + q, -Math.PI / 2);
            straight(x + w, y + q, x + w, y + h - q); corner(x + w - q, y + h - q, 0);
            straight(x + w - q, y + h, x + q, y + h); corner(x + q, y + h - q, Math.PI / 2);
            straight(x, y + h - q, x, y + q);         corner(x + q, y + q, Math.PI);
            g.globalAlpha = 0.85; g.fillStyle = acc;
            const step = 8;
            let carry = 0;
            for (const s of segs) {
                for (let d = carry; d <= s.len; d += step) {
                    let px, py;
                    if (s.k === 0) { const t = s.len > 0 ? d / s.len : 0; px = s.x1 + (s.x2 - s.x1) * t; py = s.y1 + (s.y2 - s.y1) * t; }
                    else { const a = s.a0 + (q > 0 ? d / q : 0); px = s.cx + Math.cos(a) * q; py = s.cy + Math.sin(a) * q; }
                    g.beginPath(); g.arc(px, py, 1.5, 0, 2 * Math.PI); g.fill();
                }
                carry = ((carry - s.len) % step + step) % step;
            }
        }
    }
}
