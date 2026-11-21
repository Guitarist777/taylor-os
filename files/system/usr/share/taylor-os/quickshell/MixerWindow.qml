// The Mixer window (her design tour, "Mixer window"): her replacement for SteelSeries Sonar, in the TaylorOS look.
// Tabs along the top as plain words: Mixer, Game, Chat, Media, Aux, Mic. The Mixer tab: six channels (Master and the
// five) with upright faders, a column of level dots, a number and the green mute dot; under Game, Chat, Media and Aux
// the apps playing into it: drag an app's name onto another channel to move it there (remembered for that app), or
// click it to move it along. The word under a channel's name is its output (speakers or headset): click to change it.
// The balance line between Game and Chat sits at the bottom (ChatMix on her headset turns the same balance).
// A channel's name or tab opens its sound shaping.
//
// Opens from the dock's Mixer slot, the launcher, the desktop mixer's "Mixer", or: quickshell ipc call mixer toggle
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: mw
    property bool open: false
    property string tab: "Mixer"
    function toggle() { open = !open; }
    onOpenChanged: { MixerCore.windowOpen = open; console.info("taylor-mixer: window", open ? "open" : "shut"); }

    IpcHandler {
        target: "mixer"
        function open(): void { mw.open = true; }
        function close(): void { mw.open = false; }
        function toggle(): void { mw.open = !mw.open; }
        function tab(name: string): void { mw.tab = name; mw.open = true; }
        function state(): string { return MixerCore.report(); }
        function move(app: string, channel: string): void { MixerCore.moveApp(app, channel); }
        function channelOf(app: string): string { return MixerCore.channelOfApp(app); }
        function remembered(app: string): string { return MixerCore.rememberedRoute(app); }
        // for the checks: where an app's name / a channel's parts are in the window ("x y", window pixels)
        function where(what: string): string { return MixerCore.where(what); }
        function output(channel: string): void { if (channel === "main") MixerCore.toggleMain(); else MixerCore.toggleOut(channel); }
        function balance(b: real): void { MixerCore.setBalance(b); }
        // the equalizer (for the checks): one band's frequency, gain and width; its type; a preset
        function eq(channel: string, band: int, freq: real, gain: real, q: real): void { MixerFx.setBand(channel, band - 1, freq, gain, q); }
        function eqType(channel: string, band: int): void { MixerFx.cycleType(channel, band - 1); }
        function preset(channel: string, name: string): void { MixerFx.usePreset(channel, name); }
        function follow(on: bool): void { MixerFx.setFollow("game", on); }
        // the compressor, gate and spatial audio (for the checks): part comp | gate | sp, a value of it
        function part(channel: string, part: string, key: string, value: string): void {
            MixerFx.setPart(channel, part, key, value === "true" ? true : value === "false" ? false : Number(value));
        }
        function noise(on: bool): void { MixerFx.setNs(on); }
        function sub(name: string): void { MixerCore.shapingSub = name; }
        function curveAt(channel: string, freq: real): real { return MixerFx.responseDb(channel, freq); }
    }

    FloatingWindow {
        id: win
        visible: mw.open
        title: "Mixer"
        implicitWidth: 700
        implicitHeight: 486
        minimumSize: Qt.size(700, 486)
        maximumSize: Qt.size(700, 486)        // a fixed size: Hyprland floats it even without its window rule
        color: Theme.window
        onVisibleChanged: if (!visible) mw.open = false

        Item {
            id: content
            anchors.fill: parent

            Text {
                x: 14; y: 9
                text: "Mixer"
                font.family: Theme.sans; font.pixelSize: 12
                color: Theme.muted
            }
            Rectangle { y: 33; width: parent.width; height: 1; color: Theme.line }

            Row {
                id: tabs
                x: 16; y: 46
                spacing: 18
                Repeater {
                    model: ["Mixer", "Game", "Chat", "Media", "Aux", "Mic"]
                    delegate: MxWord {
                        id: tw
                        required property string modelData
                        Component.onCompleted: MixerCore.spot("tab:" + modelData, tw)
                        text: modelData
                        size: 13
                        chosen: mw.tab === modelData
                        onClicked: mw.tab = modelData
                    }
                }
            }

            Item {
                id: view
                x: 12; y: 80
                width: parent.width - 24
                height: parent.height - y - 16

                // ---- the Mixer tab ----
                Item {
                    id: mixerTab
                    anchors.fill: parent
                    visible: mw.tab === "Mixer"
                    property int over: -1          // the strip an app is being dragged over

                    Row {
                        id: strips
                        width: parent.width
                        height: 318
                        Repeater {
                            model: MixerCore.keys
                            delegate: Strip {
                                required property string modelData
                                required property int index
                                k: modelData
                                idx: index
                                width: strips.width / 6
                                height: strips.height
                            }
                        }
                    }

                    // the Game / Chat balance
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: strips.height + 14
                        spacing: 10
                        Text { text: "Game"; font.family: Theme.sans; font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        MxLine {
                            id: bal
                            Component.onCompleted: MixerCore.spot("balance", bal)
                            width: 260
                            from: -1; to: 1
                            centred: true
                            value: MixerCore.balance
                            onMoved: (v) => MixerCore.setBalance(v)
                        }
                        Text { text: "Chat"; font.family: Theme.sans; font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // the app name being dragged
                    Text {
                        id: ghost
                        visible: false
                        z: 10
                        font.family: Theme.sans; font.pixelSize: 12
                        color: Theme.soft
                    }
                }

                // ---- a channel's sound shaping ----
                Shaping {
                    anchors.fill: parent
                    visible: mw.tab !== "Mixer"
                    k: mw.tab.toLowerCase()
                }
            }
        }
    }

    // one channel on the Mixer tab
    component Strip: Item {
        id: s
        property string k
        property int idx
        readonly property bool appCh: MixerCore.appChannels.indexOf(k) >= 0
        readonly property bool isMuted: MixerCore.muted(k)
        Rectangle { visible: s.idx > 0; width: 1; height: parent.height; color: Theme.line }
        Rectangle { anchors.fill: parent; color: Theme.sel; visible: mixerTab.over === s.idx && s.appCh }
        Column {
            x: 8; y: 6
            width: parent.width - 16
            spacing: 6
            MxWord {
                anchors.horizontalCenter: parent.horizontalCenter
                text: MixerCore.names[s.k]
                size: 13
                tint: Theme.text
                clickable: s.k !== "master"
                onClicked: mw.tab = MixerCore.names[s.k]
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: ow.implicitWidth; height: 16
                MxWord {
                    id: ow
                    Component.onCompleted: MixerCore.spot("out:" + s.k, ow)
                    text: MixerCore.outWord(s.k)
                    size: 11
                    tint: Theme.muted
                    clickable: s.appCh
                    onClicked: MixerCore.toggleOut(s.k)
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 132
                spacing: 9
                MxLine {
                    id: fader
                    Component.onCompleted: MixerCore.spot("fader:" + s.k, fader)
                    vertical: true
                    width: 18; height: 132
                    value: MixerCore.vol(s.k)
                    grey: s.isMuted
                    active: MixerCore.live(s.k)
                    onMoved: (v) => MixerCore.setVol(s.k, v)
                }
                MxDots { vertical: true; count: 14; height: 132; level: MixerCore.levels[s.k] || 0 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(MixerCore.vol(s.k) * 100)
                font.family: Theme.sans; font.pixelSize: 12; font.features: { "tnum": 1 }
                color: Theme.muted
            }
            MxMute {
                id: mdot
                Component.onCompleted: MixerCore.spot("mute:" + s.k, mdot)
                anchors.horizontalCenter: parent.horizontalCenter
                muted: s.isMuted
                onClicked: MixerCore.toggleMute(s.k)
            }
            // the apps playing into it
            Item {
                visible: s.appCh
                width: parent.width; height: appCol.height + 8
                Rectangle { width: parent.width; height: 1; color: Theme.line }
                Column {
                    id: appCol
                    y: 7
                    width: parent.width
                    spacing: 3
                    readonly property var list: s.appCh ? MixerCore.apps(s.k) : []
                    Text {
                        visible: appCol.list.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "no apps"
                        font.family: Theme.sans; font.pixelSize: 11
                        color: Theme.muted; opacity: 0.75
                    }
                    Repeater {
                        model: appCol.list
                        delegate: Text {
                            id: an
                            required property var modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, appCol.width)
                            elide: Text.ElideRight
                            text: modelData.label
                            font.family: Theme.sans; font.pixelSize: 12
                            color: Theme.soft
                            Component.onCompleted: MixerCore.spot("app:" + modelData.key, an)
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                preventStealing: true
                                property point start
                                property bool dragging: false
                                function target(e) {
                                    const p = mapToItem(strips, e.x, e.y);
                                    if (p.y < -20 || p.y > strips.height + 30) return -1;
                                    const i = Math.floor(p.x / (strips.width / 6));
                                    return (i >= 1 && i <= 4) ? i : -1;
                                }
                                onPressed: (e) => { start = Qt.point(e.x, e.y); dragging = false; }
                                onPositionChanged: (e) => {
                                    if (!dragging && Math.abs(e.x - start.x) + Math.abs(e.y - start.y) > 6) dragging = true;
                                    if (!dragging) return;
                                    const p = mapToItem(mixerTab, e.x, e.y);
                                    ghost.text = an.modelData.label;
                                    ghost.x = p.x - ghost.implicitWidth / 2; ghost.y = p.y - 10;
                                    ghost.visible = true;
                                    mixerTab.over = target(e);
                                }
                                onReleased: (e) => {
                                    ghost.visible = false;
                                    const i = dragging ? target(e) : -1;
                                    mixerTab.over = -1;
                                    if (dragging) {
                                        if (i > 0 && MixerCore.keys[i] !== s.k) MixerCore.moveApp(an.modelData.key, MixerCore.keys[i]);
                                    } else {
                                        // a click moves it along to the next channel (Game > Chat > Media > Aux > Game)
                                        const n = MixerCore.appChannels[(MixerCore.appChannels.indexOf(s.k) + 1) % 4];
                                        MixerCore.moveApp(an.modelData.key, n);
                                    }
                                    dragging = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
