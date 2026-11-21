// The equalizer of one channel (her design tour, "Mixer window", Equalizer): full parametric, ten bands. Drag a band's
// dot in any direction (frequency sideways, gain up and down); its width (Q) by the Width line, or by scrolling while
// pointing at that band's dot (scrolling anywhere else on the graph does nothing); its type steps through Bell,
// Low shelf, High shelf, Low cut, High cut when its type word is clicked. The curve is the real combined response
// (MixerFx.responseDb: PipeWire's own biquad formulas). Presets open as a searchable list organised by game; Game has
// "Follow the game". The Bass, Voice and Treble lines move broad regions.
import QtQuick

Item {
    id: eq
    property string k
    readonly property var s: MixerFx.get(k)
    property int sel: 6
    property bool presetsOpen: false
    readonly property var cols: [Theme.accent, Theme.mix(Theme.accent, Theme.soft, 0.5), Theme.soft, Theme.mix(Theme.accent, Theme.bg, 0.25)]

    // ---- the top line: preset, follow the game, the equalizer on or off ----
    Row {
        id: top
        width: parent.width
        spacing: 14
        MxWord {
            id: pw
            Component.onCompleted: MixerCore.spot("eq:preset", pw)
            text: "Preset: " + (eq.s.pre || "Custom")
            chosen: true
            onClicked: eq.presetsOpen = !eq.presetsOpen
        }
        MxSwitch {
            visible: eq.k === "game"
            text: "Follow the game"
            on: !!eq.s.follow
            onToggled: MixerFx.setFollow(eq.k, !eq.s.follow)
        }
    }
    MxSwitch {
        id: eqSwitch
        Component.onCompleted: MixerCore.spot("eq:onoff", eqSwitch)
        anchors.right: parent.right
        text: "Equalizer"
        on: eq.s.eqOn
        onToggled: MixerFx.setEq(eq.k, !eq.s.eqOn)
    }

    // ---- the graph ----
    Item {
        id: graph
        y: 28
        width: parent.width
        height: 206
        readonly property real x0: 40
        readonly property real x1: width - 8
        readonly property real y0: 92                 // 0 dB
        readonly property real px: 6.6                // pixels per dB
        function fx(f) { return x0 + (Math.log(f / 20) / Math.LN10) / 3 * (x1 - x0); }
        function xf(x) { return 20 * Math.pow(10, 3 * (x - x0) / (x1 - x0)); }
        function gy(g) { return y0 - g * px; }

        Canvas {
            id: cv
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            property int rev: MixerFx.rev
            onRevChanged: requestPaint()
            Connections { target: Theme; function onSchemeChanged() { cv.requestPaint(); } }
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.font = "10px \"" + Theme.sans + "\", sans-serif";
                // grid: gain lines and their numbers
                for (const d of [12, 6, 0, -6, -12]) {
                    const y = graph.gy(d) + 0.5;
                    c.strokeStyle = Theme.alpha(Theme.text, d === 0 ? 0.18 : 0.07);
                    c.beginPath(); c.moveTo(graph.x0, y); c.lineTo(graph.x1, y); c.stroke();
                    c.fillStyle = Theme.muted; c.textAlign = "right";
                    c.fillText((d > 0 ? "+" : "") + d, graph.x0 - 8, y + 3);
                }
                // frequency lines
                for (const f of [[20, "20"], [50, "50"], [100, "100"], [200, "200"], [500, "500"], [1000, "1k"], [2000, "2k"], [5000, "5k"], [10000, "10k"], [20000, "20k"]]) {
                    const x = Math.round(graph.fx(f[0])) + 0.5;
                    c.strokeStyle = Theme.alpha(Theme.text, 0.05);
                    c.beginPath(); c.moveTo(x, 8); c.lineTo(x, graph.height - 22); c.stroke();
                    c.fillStyle = Theme.muted; c.textAlign = "center";
                    c.fillText(f[1], x, graph.height - 6);
                }
                // the real combined response
                c.strokeStyle = eq.s.eqOn ? Theme.text : Theme.mix(Theme.track, Theme.muted, 0.45);
                c.lineWidth = 1.5;
                c.beginPath();
                for (let x = graph.x0; x <= graph.x1; x += 3) {
                    const y = graph.gy(Math.max(-13.5, Math.min(13.5, MixerFx.responseDb(eq.k, graph.xf(x)))));
                    if (x === graph.x0) c.moveTo(x, y); else c.lineTo(x, y);
                }
                c.stroke();
                // the ten band dots
                eq.s.bands.forEach((b, i) => {
                    const x = graph.fx(b.f), y = b.t >= 3 ? graph.y0 : graph.gy(b.g);
                    c.beginPath();
                    c.arc(x, y, i === eq.sel ? 5.5 : 4.5, 0, 2 * Math.PI);
                    c.fillStyle = eq.s.eqOn ? eq.cols[i % 4] : Theme.mix(Theme.track, Theme.muted, 0.45);
                    c.fill();
                    if (i === eq.sel && eq.s.eqOn) { c.lineWidth = 1.5; c.strokeStyle = Theme.text; c.stroke(); }
                });
            }
        }
        // a band's dot under the pointer (within 13 px), or -1
        function hit(mx, my) {
            let best = -1, bd = 13 * 13;
            eq.s.bands.forEach((b, i) => {
                const dx = graph.fx(b.f) - mx, dy = (b.t >= 3 ? graph.y0 : graph.gy(b.g)) - my;
                if (dx * dx + dy * dy <= bd) { bd = dx * dx + dy * dy; best = i; }
            });
            return best;
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            property int drag: -1
            cursorShape: drag >= 0 || graph.hit(mouseX, mouseY) >= 0 ? Qt.SizeAllCursor : Qt.ArrowCursor
            onPressed: (e) => {
                const i = graph.hit(e.x, e.y);
                if (i < 0 || !eq.s.eqOn) { e.accepted = true; return; }
                drag = i; eq.sel = i;
                MixerFx.rev++;
            }
            onPositionChanged: (e) => {
                if (drag < 0 || !pressed) return;
                const b = eq.s.bands[drag];
                const f = Math.max(20, Math.min(20000, graph.xf(Math.max(graph.x0, Math.min(graph.x1, e.x)))));
                const g = b.t >= 3 ? null : Math.max(-12, Math.min(12, (graph.y0 - e.y) / graph.px));
                MixerFx.setBand(eq.k, drag, f, g, null);
            }
            onReleased: drag = -1
            onWheel: (w) => {
                w.accepted = true;                         // never scrolls anything else
                const i = graph.hit(w.x, w.y);
                if (i < 0 || !eq.s.eqOn) return;           // only over a band's dot
                eq.sel = i;
                const b = eq.s.bands[i];
                MixerFx.setBand(eq.k, i, null, null, b.q * (w.angleDelta.y > 0 ? 1.12 : 0.89));
            }
        }
        Component.onCompleted: MixerCore.spot("eq:graph", graph)
        // where band i's dot is (for the checks)
        function bandPos(i) { const b = eq.s.bands[i]; return Qt.point(fx(b.f), b.t >= 3 ? y0 : gy(b.g)); }
    }

    // ---- the chosen band ----
    Row {
        id: det
        y: graph.y + graph.height + 6
        width: parent.width
        spacing: 12
        readonly property var b: eq.s.bands[eq.sel]
        Small { text: "Band " + (eq.sel + 1); width: 52 }
        MxWord {
            id: typeWord
            Component.onCompleted: MixerCore.spot("eq:type", typeWord)
            text: MixerFx.types[det.b.t]
            size: 12
            chosen: true
            onClicked: MixerFx.cycleType(eq.k, eq.sel)
        }
        Small { text: det.b.f < 1000 ? Math.round(det.b.f) + " Hz" : (det.b.f / 1000).toFixed(det.b.f < 10000 ? 2 : 1) + " kHz"; color: Theme.soft; width: 64 }
        Small { text: det.b.t >= 3 ? "" : (det.b.g > 0 ? "+" : "") + det.b.g.toFixed(1) + " dB"; color: Theme.soft; width: 58 }
        Small { text: "Width" }
        MxLine {
            id: widthLine
            Component.onCompleted: MixerCore.spot("eq:width", widthLine)
            width: 150
            anchors.verticalCenter: parent.verticalCenter
            from: -0.52; to: 0.9
            value: Math.log(det.b.q) / Math.LN10
            active: eq.s.eqOn
            onMoved: (v) => MixerFx.setBand(eq.k, eq.sel, null, null, Math.pow(10, v))
        }
        Small { text: "Q " + det.b.q.toFixed(2); color: Theme.soft }
    }

    // ---- Bass, Voice, Treble ----
    Row {
        y: det.y + 34
        width: parent.width
        spacing: 18
        Repeater {
            model: ["Bass", "Voice", "Treble"]
            delegate: Row {
                required property string modelData
                required property int index
                spacing: 10
                Small { text: modelData; width: 40 }
                MxLine {
                    width: 96
                    anchors.verticalCenter: parent.verticalCenter
                    from: -12; to: 12
                    centred: true
                    value: eq.s.tone[index]
                    onMoved: (v) => MixerFx.setTone(eq.k, index, Math.abs(v) < 0.3 ? 0 : v)
                }
                Small { text: (eq.s.tone[index] > 0 ? "+" : "") + Number(eq.s.tone[index]).toFixed(1) + " dB"; color: Theme.soft; width: 54 }
            }
        }
    }

    // ---- the presets: a searchable list, by game ----
    Rectangle {
        visible: eq.presetsOpen
        y: 24
        width: parent.width
        height: plist.height + 18
        color: Theme.window
        border.width: 0
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Theme.line }
        MouseArea { anchors.fill: parent; onWheel: (w) => { w.accepted = true; } }
        Column {
            id: plist
            x: 4; y: 9
            width: parent.width - 8
            spacing: 8
            Item {
                width: 220; height: 22
                TextInput {
                    id: search
                    width: parent.width
                    font.family: Theme.sans; font.pixelSize: 13
                    color: Theme.text
                    focus: eq.presetsOpen
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    Text { visible: !search.text; text: "Search games and presets"; font: search.font; color: Theme.muted }
                }
                Rectangle { y: 20; width: parent.width; height: 1; color: Theme.line }
            }
            Repeater {
                model: MixerFx.presetGroups()
                delegate: Row {
                    id: grp
                    required property var modelData
                    readonly property var shown: modelData.items.filter(p => p.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0 || modelData.group.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                    visible: shown.length > 0
                    spacing: 16
                    Small { text: grp.modelData.group; width: 70 }
                    Repeater {
                        model: grp.shown
                        delegate: MxWord {
                            required property var modelData
                            text: modelData.name
                            size: 12
                            chosen: eq.s.pre === modelData.name
                            onClicked: { MixerFx.usePreset(eq.k, modelData.name); eq.presetsOpen = false; }
                        }
                    }
                }
            }
            Small {
                visible: !MixerFx.presetGroups().some(g => g.items.some(p => p.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0 || g.group.toLowerCase().indexOf(search.text.toLowerCase()) >= 0))
                text: "Nothing by that name yet"
            }
            Small { text: MixerFx.madeUp; opacity: 0.75 }
        }
    }

    component Small: Text {
        font.family: Theme.sans; font.pixelSize: 12
        color: Theme.muted
    }
}
