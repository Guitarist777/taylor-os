// The noise gate of Chat and Mic (her design tour): silences the channel when its sound drops below the threshold;
// the threshold by hand or set for her (from the channel's own quiet level). Sound: the swh gate (LADSPA, GPL), keyed
// on the voice band (80 Hz to 8 kHz). Mic also has background noise reduction: WebRTC's noise suppression (PipeWire's
// echo-cancel module, which also takes what plays on her main output out of the microphone).
import QtQuick

Item {
    id: gv
    property string k
    readonly property var p: MixerFx.get(k).gate
    function set(key, v) { MixerFx.setPart(k, "gate", key, v); }
    Text { y: 2; text: "Silences the channel when the sound drops below the threshold."; font.family: Theme.sans; font.pixelSize: 11; color: Theme.muted; opacity: 0.75 }
    MxSwitch { id: onoff; anchors.right: parent.right; text: "Noise gate"; on: gv.p.on; onToggled: gv.set("on", !gv.p.on); Component.onCompleted: MixerCore.spot("gate:onoff", onoff) }
    MxSwitch { y: 34; text: "Set the threshold for me"; on: gv.p.auto; onToggled: gv.set("auto", !gv.p.auto) }
    MxRow {
        y: 64
        label: "Threshold"; from: -70; to: -20
        value: gv.p.auto ? MixerFx.gateDb(gv.k) : gv.p.th
        active: !gv.p.auto
        opacity: gv.p.auto ? 0.45 : 1
        shown: (gv.p.auto ? MixerFx.gateDb(gv.k) : gv.p.th).toFixed(1) + " dB"
        onMoved: (v) => gv.set("th", v)
    }
    MxSwitch {
        id: ns
        visible: gv.k === "mic"
        y: 104
        text: "Background noise reduction"
        on: !!MixerFx.get("mic").ns
        onToggled: MixerFx.setNs(!MixerFx.get("mic").ns)
        Component.onCompleted: MixerCore.spot("mic:ns", ns)
    }
}
