// The mixer, under the clock (mockup: 380 x 360, radius 22, panel #171918).
// Each strip is a real PipeWire volume:
//   SYS / GAME / VOICE / MUSIC  the TAYLOR channels made by /etc/pipewire/pipewire.conf.d/taylor-mixer.conf
//   MIC                          the default microphone
//   MAIN                         the default output (speakers or the GameDAC)
// A channel that is not there (yet) is drawn dimmed and does nothing.
// Speakers / Headphones picks the default output: Headphones = the SteelSeries GameDAC / base station.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    anchors { top: true; left: true }
    margins { top: 40 + 84 + 14; left: 40 }
    implicitWidth: 380
    implicitHeight: 360
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "taylor-mixer"

    function findSink(key) {
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.isSink && !n.isStream && n.name === key)
                return n;
        }
        return null;
    }
    // Hardware outputs only (never one of the TAYLOR channels).
    function outputs() {
        return Pipewire.nodes.values.filter(n => n && n.isSink && !n.isStream && !n.name.startsWith("taylor_"));
    }
    function isHeadset(n) {
        const s = ((n.description || "") + " " + (n.name || "")).toLowerCase();
        return s.includes("arctis") || s.includes("steelseries") || s.includes("gamedac") || s.includes("nova");
    }
    readonly property var headset: outputs().find(n => isHeadset(n)) || null
    readonly property var speakers: outputs().find(n => !isHeadset(n)) || null
    readonly property bool onHeadset: Pipewire.defaultAudioSink !== null && isHeadset(Pipewire.defaultAudioSink)

    readonly property var strips: [
        { label: "SYS", node: findSink("taylor_sys") },
        { label: "GAME", node: findSink("taylor_game") },
        { label: "VOICE", node: findSink("taylor_voice") },
        { label: "MUSIC", node: findSink("taylor_music") },
        { label: "MIC", node: Pipewire.defaultAudioSource },
        { label: "MAIN", node: Pipewire.defaultAudioSink, main: true }
    ]

    // Audio properties are only live for objects a tracker holds.
    PwObjectTracker { objects: win.strips.map(s => s.node).filter(n => n) }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: win.theme.panel
        border.color: win.theme.line
        border.width: 1

        Text {
            x: 20; y: 24
            text: "MIXER"
            font.family: win.theme.mono
            font.pixelSize: 12
            font.letterSpacing: 2.9
            color: win.theme.muted
        }

        Rectangle {
            id: picker
            anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 16 }
            radius: 10
            color: win.theme.chip
            width: row.width + 6
            height: 32
            Row {
                id: row
                anchors.centerIn: parent
                Repeater {
                    model: [{ label: "Speakers", head: false }, { label: "Headphones", head: true }]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: modelData.head === win.onHeadset
                        width: t.implicitWidth + 20
                        height: 26
                        radius: 8
                        color: on ? win.theme.accent : "transparent"
                        Text {
                            id: t
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: win.theme.sans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: parent.on ? win.theme.onAccent : win.theme.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const target = modelData.head ? win.headset : win.speakers;
                                if (target) Pipewire.preferredDefaultAudioSink = target;
                            }
                        }
                    }
                }
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; bottom: parent.bottom; bottomMargin: 20 }
            height: 270
            spacing: (width - 6 * 46) / 5
            Repeater {
                model: win.strips
                delegate: Strip {
                    required property var modelData
                    theme: win.theme
                    label: modelData.label
                    node: modelData.node
                    main: modelData.main === true
                }
            }
        }
    }
}
