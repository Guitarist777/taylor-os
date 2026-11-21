// A channel's sound shaping in the Mixer window (her brief: Equalizer, Compressor, Noise gate on Chat and Mic,
// Spatial audio on Game, Media and Aux). Step one of the mixer (channels and routing) ends here; the equalizer is step two.
import QtQuick

Item {
    id: sh
    property string k
    Text {
        x: 4; y: 2
        text: MixerCore.names[sh.k] || ""
        font.family: Theme.sans; font.pixelSize: 15; font.weight: Font.Medium
        color: Theme.text
    }
    Text {
        x: 4; y: 34
        text: "Sound shaping for this channel comes in the next step."
        font.family: Theme.sans; font.pixelSize: 12
        color: Theme.muted
    }
}
