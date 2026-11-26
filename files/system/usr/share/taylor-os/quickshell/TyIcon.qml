// The mic and read-aloud buttons in TAYLOR's panel: placeholders until voice comes to TaylorOS (her brief), so they look
// quiet and do nothing.
import QtQuick

Item {
    id: i
    property real s: 1
    property QtObject theme
    property string kind: "mic"
    width: 32 * s; height: 32 * s
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Canvas {
        anchors.fill: parent
        onPaint: {
            const x = getContext("2d"); x.reset();
            const k = width / 32, c = width / 2;
            x.strokeStyle = i.theme.text2; x.globalAlpha = 0.55; x.lineWidth = 1.4 * k; x.lineCap = "round"; x.lineJoin = "round";
            if (i.kind === "mic") {
                x.beginPath(); x.moveTo(c - 3 * k, c - 2 * k); x.lineTo(c - 3 * k, c - 5 * k); x.arc(c, c - 5 * k, 3 * k, Math.PI, 0); x.lineTo(c + 3 * k, c - 2 * k); x.arc(c, c - 2 * k, 3 * k, 0, Math.PI); x.stroke();
                x.beginPath(); x.arc(c, c - 2 * k, 6 * k, 0.15, Math.PI - 0.15); x.stroke();
                x.beginPath(); x.moveTo(c, c + 4 * k); x.lineTo(c, c + 7 * k); x.stroke();
            } else {
                x.beginPath(); x.moveTo(c - 7 * k, c - 2.5 * k); x.lineTo(c - 4 * k, c - 2.5 * k); x.lineTo(c, c - 6 * k); x.lineTo(c, c + 6 * k); x.lineTo(c - 4 * k, c + 2.5 * k); x.lineTo(c - 7 * k, c + 2.5 * k); x.closePath(); x.stroke();
                x.beginPath(); x.arc(c + 1 * k, c, 4 * k, -0.8, 0.8); x.stroke();
                x.beginPath(); x.arc(c + 1 * k, c, 7 * k, -0.8, 0.8); x.stroke();
            }
        }
    }
}
