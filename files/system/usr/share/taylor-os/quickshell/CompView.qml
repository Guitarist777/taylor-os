// The compressor of one channel (her design tour): threshold, ratio, attack, release, makeup gain, and a small curve
// of what goes in against what comes out. Sound: the SC4 compressor (Steve Harris' swh LADSPA plugins, GPL), one for
// both sides of a stereo channel; its threshold reaches down to -30 dB (the plugin's own limit).
import QtQuick

Item {
    id: cv
    property string k
    readonly property var p: MixerFx.get(k).comp
    function set(key, v) { MixerFx.setPart(k, "comp", key, v); }
    Text { y: 2; text: "Evens out loud and quiet moments."; font.family: Theme.sans; font.pixelSize: 11; color: Theme.muted; opacity: 0.75 }
    MxSwitch { id: onoff; anchors.right: parent.right; text: "Compressor"; on: cv.p.on; onToggled: cv.set("on", !cv.p.on); Component.onCompleted: MixerCore.spot("comp:onoff", onoff) }
    Column {
        y: 34
        MxRow { label: "Threshold"; from: -30; to: 0; value: cv.p.th; shown: cv.p.th.toFixed(1) + " dB"; onMoved: (v) => cv.set("th", v) }
        MxRow { label: "Ratio"; from: 1; to: 20; value: cv.p.ra; shown: cv.p.ra.toFixed(1) + " : 1"; onMoved: (v) => cv.set("ra", v) }
        MxRow { label: "Attack"; from: Math.log(1.5) / Math.LN10; to: Math.log(400) / Math.LN10; value: Math.log(cv.p.at) / Math.LN10; shown: cv.p.at.toFixed(1) + " ms"; onMoved: (v) => cv.set("at", Math.pow(10, v)) }
        MxRow { label: "Release"; from: 1; to: Math.log(800) / Math.LN10; value: Math.log(cv.p.re) / Math.LN10; shown: Math.round(cv.p.re) + " ms"; onMoved: (v) => cv.set("re", Math.pow(10, v)) }
        MxRow { label: "Makeup gain"; from: 0; to: 24; value: cv.p.mk; shown: "+" + cv.p.mk.toFixed(1) + " dB"; onMoved: (v) => cv.set("mk", v) }
    }
    Canvas {
        id: curve
        x: parent.width - 160; y: 34
        width: 150; height: 150
        property var dep: [cv.p.th, cv.p.ra, cv.p.mk, cv.p.on, Theme.scheme]
        onDepChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const m = v => 10 + (v + 60) / 60 * 130, y = v => 140 - (v + 60) / 60 * 130, cl = v => Math.max(-60, Math.min(0, v));
            c.strokeStyle = Theme.line; c.lineWidth = 1;
            c.strokeRect(10.5, 10.5, 130, 130);
            c.beginPath(); c.moveTo(10, 140); c.lineTo(140, 10); c.stroke();
            const th = cv.p.th, out0 = th + (0 - th) / cv.p.ra, mk = cv.p.mk;
            c.strokeStyle = cv.p.on ? Theme.text : Theme.mix(Theme.track, Theme.muted, 0.45); c.lineWidth = 1.5;
            c.beginPath(); c.moveTo(m(-60), y(cl(-60 + mk))); c.lineTo(m(th), y(cl(th + mk))); c.lineTo(m(0), y(cl(out0 + mk))); c.stroke();
            c.fillStyle = cv.p.on ? Theme.accent : Theme.mix(Theme.track, Theme.muted, 0.45);
            c.beginPath(); c.arc(m(th), y(cl(th + mk)), 4, 0, 2 * Math.PI); c.fill();
        }
    }
}
