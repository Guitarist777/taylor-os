// A channel's sound shaping in the Mixer window (her brief: sub-sections as plain words: Equalizer and Compressor on
// every channel, Noise gate on Chat and Mic, Spatial audio on Game, Media and Aux).
import QtQuick

Item {
    id: sh
    property string k
    property string sub: "Equalizer"
    readonly property var subs: {
        const l = ["Equalizer", "Compressor"];
        if (k === "chat" || k === "mic") l.push("Noise gate");
        else l.push("Spatial audio");
        return l;
    }
    onKChanged: if (subs.indexOf(sub) < 0) sub = "Equalizer"

    Text {
        x: 4; y: 0
        text: MixerCore.names[sh.k] || ""
        font.family: Theme.sans; font.pixelSize: 15; font.weight: Font.Medium
        color: Theme.text
    }
    Row {
        x: 4; y: 26
        spacing: 16
        Repeater {
            model: sh.subs
            delegate: MxWord {
                id: sw
                required property string modelData
                Component.onCompleted: MixerCore.spot("sub:" + modelData, sw)
                text: modelData
                size: 12
                chosen: sh.sub === modelData
                onClicked: sh.sub = modelData
            }
        }
    }
    Item {
        x: 4; y: 56
        width: parent.width - 8
        height: parent.height - y
        EqView { anchors.fill: parent; k: sh.k; visible: sh.sub === "Equalizer" }
        Text {
            visible: sh.sub !== "Equalizer"
            text: "The " + sh.sub.toLowerCase() + " comes in the next step."
            font.family: Theme.sans; font.pixelSize: 12
            color: Theme.muted
        }
    }
}
