// Spatial audio for Game, Media and Aux (her design tour): on or off, for headphones or speakers, pinpoint to
// immersive, and distance, drawn as seven virtual speakers around her.
// Headphones: each virtual speaker is placed around her with a measured head (the MIT KEMAR HRTF that comes with
// libmysofa, through PipeWire's SOFA spatializer). Speakers: the seven are panned between her two speakers (no HRTF:
// that only works in headphones). Pinpoint keeps the sound in front; immersive gives the sides and back more; distance
// pushes the front back and puts more time between the front and the back.
import QtQuick

Item {
    id: spv
    property string k
    readonly property var p: MixerFx.get(k).sp
    function set(key, v) { MixerFx.setPart(k, "sp", key, v); }
    Row {
        spacing: 14
        MxWord { text: "Headphones"; size: 12; chosen: spv.p.mode === 1; onClicked: spv.set("mode", 1) }
        MxWord { text: "Speakers"; size: 12; chosen: spv.p.mode === 0; onClicked: spv.set("mode", 0) }
    }
    MxSwitch { id: onoff; anchors.right: parent.right; text: "Spatial audio"; on: spv.p.on; onToggled: spv.set("on", !spv.p.on); Component.onCompleted: MixerCore.spot("sp:onoff", onoff) }
    Canvas {
        id: ring
        y: 30
        width: 170; height: 170
        property var dep: [spv.p.on, spv.p.imm, spv.p.dist, Theme.scheme]
        onDepChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            c.strokeStyle = Theme.alpha(Theme.accent, 0.35); c.lineWidth = 1;
            c.beginPath(); c.arc(85, 85, 74, 0, 2 * Math.PI); c.stroke();
            c.strokeStyle = Theme.alpha(Theme.text, 0.07);
            c.beginPath(); c.arc(85, 85, 46, 0, 2 * Math.PI); c.stroke();
            c.fillStyle = Theme.text; c.beginPath(); c.arc(85, 85, 5, 0, 2 * Math.PI); c.fill();
            const R = 24 + spv.p.dist * 48;
            for (const a of [0, -30, 30, -90, 90, -150, 150]) {
                const r = a * Math.PI / 180;
                c.globalAlpha = 0.55 + 0.45 * (1 - spv.p.imm);
                c.fillStyle = spv.p.on ? Theme.accent : Theme.mix(Theme.track, Theme.muted, 0.45);
                c.beginPath(); c.arc(85 + Math.sin(r) * R, 85 - Math.cos(r) * R, 3 + spv.p.imm * 2.5, 0, 2 * Math.PI); c.fill();
            }
            c.globalAlpha = 1;
        }
    }
    Column {
        x: 190; y: 40
        width: parent.width - 190
        MxRow { label: "Performance"; from: 0; to: 1; value: spv.p.imm; lineWidth: 150; shown: spv.p.imm < 0.34 ? "Pinpoint" : (spv.p.imm > 0.66 ? "Immersive" : "Balanced"); onMoved: (v) => spv.set("imm", v) }
        MxRow { label: "Distance"; from: 0; to: 1; value: spv.p.dist; lineWidth: 150; shown: Math.round(spv.p.dist * 100); onMoved: (v) => spv.set("dist", v) }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: "Left is sharper direction for competitive games. Right is a bigger room for story games and movies."
            font.family: Theme.sans; font.pixelSize: 11; color: Theme.muted; opacity: 0.75
        }
    }
}
