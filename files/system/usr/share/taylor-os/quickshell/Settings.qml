// Her Settings window (her build brief, "Settings"; her design tour, part 11). One normal window, not full screen
// (Hyprland floats it, centred: the TAYLOR-OS-SETTINGS block in hyprland.lua). Sections down the left, each with a
// small dot that turns green when chosen; thin rows on the right. A switch is the word On or Off with a small dot
// (filled green when on, a hollow grey ring when off); a choice is plain words with a thin green underline. No pills,
// no boxes, no chunky switches.
//
// Only options that really do something on this PC are here (her brief). Every one reads and writes her settings file
// (Prefs.qml), or the real thing it controls (PipeWire for sound, the monitor for brightness, NetworkManager for the
// network). Choosing a colour scheme recolours everything at once (Theme.qml), this window too, and asks Hyprland to
// read its settings again so the window outline takes the new colour.
//
// Opened with "quickshell ipc call settings open" (or toggle / close; "show NAME" opens one section).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

FloatingWindow {
    id: win
    title: "Settings"
    visible: false
    implicitWidth: 760
    implicitHeight: 560
    color: Theme.window

    // "Open the mixer" in Sound: shell.qml opens the Mixer window (the same one the dock's Mixer slot opens)
    signal openMixer()
    property string page: "Appearance"
    readonly property var pages: ["Appearance", "Lock and timeout", "TAYLOR", "Sound", "Display", "Network", "About"]
    function show(p) {
        p = String(p).replace(/-/g, " ");
        if (pages.indexOf(p) >= 0) page = p;
        visible = true;
        console.info("taylor-settings: open at " + page);
        placesT.restart();
    }
    onVisibleChanged: if (!visible) console.info("taylor-settings: closed")
    IpcHandler {
        target: "settings"
        function open(): void { win.show(win.page); }
        function close(): void { win.visible = false; }
        function toggle(): void { if (win.visible) win.visible = false; else win.show(win.page); }
        function section(name: string): void { win.show(name); }
        function page(): string { return win.visible ? win.page : ""; }
        function check(): void { win.show("About"); win.checkUpdates(); }
    }

    // where each control is, in window pixels, for the virtual PC's clicks (log only)
    Timer { id: placesT; interval: 600; onTriggered: win.logPlaces(body) }
    function logPlaces(item) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (!c.visible) continue;
            if (c.placeName) {
                const p = c.mapToItem(null, c.width / 2, c.height / 2);
                console.info("taylor-settings: place " + c.placeName + " " + Math.round(p.x) + " " + Math.round(p.y));
            }
            logPlaces(c);
        }
    }

    // ---- the pieces ----
    component Words: Text {
        color: Theme.text
        font.family: Theme.sans
        font.pixelSize: 14
    }
    component Small: Text {
        color: Theme.muted
        font.family: Theme.sans
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    // a switch: the word and a small dot
    component Switch: Item {
        id: sw
        property bool on: false
        property string placeName: ""
        signal flip()
        implicitWidth: Math.max(44, swRow.implicitWidth + 4)
        implicitHeight: 22
        Row {
            id: swRow
            anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
            spacing: 7
            Text {
                text: sw.on ? "On" : "Off"
                color: sw.on ? Theme.text : Theme.muted
                font.family: Theme.sans; font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 9; height: 9; radius: 4.5
                anchors.verticalCenter: parent.verticalCenter
                color: sw.on ? Theme.accent : "transparent"
                border.width: 1.5
                border.color: sw.on ? Theme.accent : Theme.muted
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.flip() }
    }
    // a choice: plain words, a thin green line under the chosen one
    component Choice: Row {
        id: ch
        property var opts: []            // [{k, n}]
        property string value: ""
        property string placePrefix: ""
        signal pick(string k)
        spacing: 14
        Repeater {
            model: ch.opts
            delegate: Item {
                id: opt
                required property var modelData
                readonly property bool chosen: modelData.k === ch.value
                readonly property string placeName: ch.placePrefix ? ch.placePrefix + ":" + modelData.k : ""
                implicitWidth: optT.implicitWidth
                implicitHeight: optT.implicitHeight + 6
                Text {
                    id: optT
                    y: 2
                    text: opt.modelData.n
                    color: opt.chosen ? Theme.text : Theme.muted
                    font.family: Theme.sans; font.pixelSize: 13
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1.5
                    color: opt.chosen ? Theme.accent : "transparent"
                }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: ch.pick(opt.modelData.k) }
            }
        }
    }
    // a slider: a thin line, the part up to the value in green, a small round handle
    component Slider: Item {
        id: sl
        property real from: 0
        property real to: 100
        property real step: 1
        property real value: 0
        property string placeName: ""
        property bool dragging: ma.pressed
        signal moved(real v)
        signal done(real v)
        implicitWidth: 130
        implicitHeight: 20
        readonly property real u: Math.max(0, Math.min(1, (value - from) / (to - from)))
        Rectangle { x: 0; width: parent.width; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.track }
        Rectangle { x: 0; width: Math.max(4, parent.width * sl.u); height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
        Rectangle {
            width: 14; height: 14; radius: 7
            x: (sl.width - 14) * sl.u
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
        }
        function at(px) {
            let v = from + Math.max(0, Math.min(1, px / width)) * (to - from);
            v = Math.round(v / step) * step;
            return Math.max(from, Math.min(to, v));
        }
        MouseArea {
            id: ma
            anchors.fill: parent; anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onPressed: (m) => { const v = sl.at(m.x - 6); if (v !== sl.value) sl.moved(v); }
            onPositionChanged: (m) => { if (pressed) { const v = sl.at(m.x - 6); if (v !== sl.value) sl.moved(v); } }
            onReleased: sl.done(sl.value)
        }
        WheelHandler { onWheel: (ev) => { const v = Math.max(sl.from, Math.min(sl.to, sl.value + (ev.angleDelta.y > 0 ? sl.step : -sl.step))); sl.moved(v); sl.done(v); } }
    }
    component Val: Text {
        width: 62
        horizontalAlignment: Text.AlignRight
        color: Theme.soft
        font.family: Theme.sans; font.pixelSize: 13
        font.features: { "tnum": 1 }
    }
    component Tag: Text {
        color: Theme.muted
        font.family: Theme.sans; font.pixelSize: 13
    }
    component Link: Text {
        id: lk
        property string placeName: ""
        signal hit()
        color: Theme.soft
        font.family: Theme.sans; font.pixelSize: 13
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: lk.hit() }
    }
    // one thin row: words on the left (a smaller line under them if any), the control on the right
    component SRow: Item {
        id: sr
        property string label: ""
        property string small: ""
        property bool clickable: false
        signal hit()
        default property alias content: right.data
        width: parent ? parent.width : 300
        implicitHeight: Math.max(left.implicitHeight, right.childrenRect.height) + 20
        MouseArea { anchors.fill: parent; enabled: sr.clickable; cursorShape: Qt.PointingHandCursor; onClicked: sr.hit() }
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Column {
            id: left
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: parent.width - right.width - 12
            Words { text: sr.label; width: parent.width; elide: Text.ElideRight }
            Small { text: sr.small; width: parent.width; visible: sr.small !== "" }
        }
        Item {
            id: right
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }
    }
    component Head: Column {
        property string title: ""
        property string sub: ""
        width: parent ? parent.width : 300
        bottomPadding: 14
        Text { text: parent.title; color: Theme.text; font.family: Theme.sans; font.pixelSize: 17; font.weight: Font.Medium; bottomPadding: 2 }
        Text { text: parent.sub; color: Theme.muted; font.family: Theme.sans; font.pixelSize: 13; width: parent.width; wrapMode: Text.WordWrap }
    }

    // ---- the window ----
    // the top strip: the word Settings (Hyprland draws no title bar; the window bar at the top right has the X)
    Rectangle {
        id: bar
        width: parent.width; height: 34
        color: "transparent"
        Image {
            id: barIcon
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Quickshell.iconPath("preferences-system", true)   // her icon set (the dock's Settings icon)
            visible: status === Image.Ready
        }
        Text {
            x: barIcon.visible ? 38 : 14; anchors.verticalCenter: parent.verticalCenter
            text: "Settings"; color: Theme.muted; font.family: Theme.sans; font.pixelSize: 12
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
    }

    Item {
        id: body
        anchors { top: bar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

        // sections down the left
        Column {
            id: nav
            x: 8; y: 12
            width: 164 - 16
            spacing: 2
            Repeater {
                model: win.pages
                delegate: Rectangle {
                    id: nv
                    required property string modelData
                    readonly property bool chosen: win.page === modelData
                    readonly property string placeName: "nav:" + modelData.replace(/ /g, "-")
                    width: nav.width; height: 33
                    radius: 8
                    color: chosen ? Theme.sel : "transparent"
                    Rectangle {
                        x: 10; width: 6; height: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: nv.chosen ? Theme.accent : Theme.dim
                    }
                    Text {
                        x: 25; anchors.verticalCenter: parent.verticalCenter
                        text: nv.modelData
                        color: nv.chosen ? Theme.text : Theme.muted
                        font.family: Theme.sans; font.pixelSize: 14
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.show(nv.modelData) }
                }
            }
        }
        Rectangle { x: 164; width: 1; height: parent.height; color: Theme.line }

        Flickable {
            id: flick
            x: 165; width: parent.width - 165; height: parent.height
            contentHeight: main.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: main
                x: 20; y: 18
                width: flick.width - 40

                // ---- Appearance ----
                Column {
                    width: parent.width
                    visible: win.page === "Appearance"
                    Head { title: "Appearance"; sub: "Colors and motion. A new scheme recolors everything at once." }
                    SRow {
                        label: "Color scheme"
                        Choice {
                            placePrefix: "scheme"
                            opts: [{ k: "taylor", n: "TAYLOR" }, { k: "quiet", n: "Quiet" }, { k: "night", n: "Quiet Night" }, { k: "slate", n: "Slate" }]
                            value: Theme.scheme
                            onPick: (k) => win.setScheme(k)
                        }
                    }
                    SRow {
                        visible: Theme.scheme === "slate"
                        label: "Background brightness"
                        small: "From black to white"
                        Row {
                            spacing: 12
                            Slider {
                                placeName: "slate"
                                from: 0; to: 1; step: 0.01
                                value: Prefs.slateLevel
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => { Prefs.slateLevel = v; }
                                onDone: (v) => console.info("taylor-settings: slate level " + v.toFixed(2))
                            }
                            Val { text: Math.round(Prefs.slateLevel * 100) + "%"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        label: "Deeper daytime sky"
                        small: "A deep blue all the way down by day"
                        Switch { placeName: "skydeeper"; on: Prefs.skyDeeper; onFlip: { Prefs.skyDeeper = !Prefs.skyDeeper; console.info("taylor-settings: deeper sky " + Prefs.skyDeeper); } }
                    }
                    SRow {
                        label: "Cursor"
                        small: "White with a green outline, or black with a white outline"
                        Choice {
                            placePrefix: "cursor"
                            opts: [{ k: "white", n: "White" }, { k: "black", n: "Black" }]
                            value: Prefs.cursor
                            onPick: (k) => {
                                Prefs.cursor = k;
                                console.info("taylor-settings: cursor " + k);
                                Quickshell.execDetached(["/usr/libexec/taylor-cursor", k]);
                            }
                        }
                    }
                    SRow {
                        label: "Reduce motion"
                        small: "Swap animations for simple fades"
                        Switch { placeName: "still"; on: Prefs.reduceMotion; onFlip: { Prefs.reduceMotion = !Prefs.reduceMotion; console.info("taylor-settings: reduce motion " + Prefs.reduceMotion); } }
                    }
                }

                // ---- Lock and timeout ----
                Column {
                    id: lockPage
                    width: parent.width
                    visible: win.page === "Lock and timeout"
                    property real idle: Prefs.idleMinutes
                    property real wait: Prefs.waitMinutes
                    readonly property real total: idle + wait
                    function mins(v) { return v === 1 ? "1 minute" : v + " minutes"; }
                    Head { title: "Lock and timeout"; sub: "What happens when you step away." }
                    Flow {
                        width: parent.width
                        spacing: 4
                        topPadding: 4; bottomPadding: 8
                        Repeater {
                            model: 40
                            delegate: Rectangle {
                                required property int index
                                readonly property int a: Math.max(1, Math.round(lockPage.idle / lockPage.total * 40))
                                width: 7; height: 7; radius: 3.5
                                color: index < a ? Theme.accent : Theme.soft
                                opacity: index < a ? 1 : 0.75
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        bottomPadding: 12
                        textFormat: Text.StyledText
                        wrapMode: Text.WordWrap
                        color: Theme.muted
                        font.family: Theme.sans; font.pixelSize: 13
                        text: "Locks about <font color=\"" + Theme.text + "\">" + lockPage.mins(lockPage.total) + "</font> after you stop. The fainter dots are TAYLOR waiting."
                    }
                    SRow {
                        label: "Start dimming after"
                        small: "Windows fade and TAYLOR glides to the middle"
                        Row {
                            spacing: 12
                            Slider {
                                placeName: "idle"
                                from: 1; to: 30; step: 1
                                value: lockPage.idle
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => { lockPage.idle = v; }
                                onDone: (v) => win.saveTimes()
                            }
                            Val { text: lockPage.idle + " min"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        label: "TAYLOR waits"
                        small: "How long she asks \"Still there?\" before locking"
                        Row {
                            spacing: 12
                            Slider {
                                placeName: "wait"
                                from: 0.5; to: 10; step: 0.5
                                value: lockPage.wait
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => { lockPage.wait = v; }
                                onDone: (v) => win.saveTimes()
                            }
                            Val { text: lockPage.wait + " min"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                // ---- TAYLOR ----
                Column {
                    width: parent.width
                    visible: win.page === "TAYLOR"
                    Head { title: "TAYLOR"; sub: "How she shows up on the desktop." }
                    SRow {
                        label: "Show TAYLOR on the desktop"
                        Switch { placeName: "showtaylor"; on: Prefs.showTaylor; onFlip: { Prefs.showTaylor = !Prefs.showTaylor; console.info("taylor-settings: show TAYLOR " + Prefs.showTaylor); } }
                    }
                    SRow {
                        label: "Status line under her"
                        small: "ALL CLEAR., THINKING., and so on"
                        Switch { placeName: "statusline"; on: Prefs.statusLine; onFlip: { Prefs.statusLine = !Prefs.statusLine; console.info("taylor-settings: status line " + Prefs.statusLine); } }
                    }
                    SRow {
                        label: "\"Ask TAYLOR\" in search"
                        Switch { placeName: "asktaylor"; on: Prefs.askTaylor; onFlip: { Prefs.askTaylor = !Prefs.askTaylor; console.info("taylor-settings: ask TAYLOR in search " + Prefs.askTaylor); } }
                    }
                }

                // ---- Sound ----
                Column {
                    id: sound
                    width: parent.width
                    visible: win.page === "Sound"
                    readonly property var sink: Pipewire.defaultAudioSink
                    function hw() { return Pipewire.nodes.values.filter(n => n && n.isSink && !n.isStream && !(n.name || "").startsWith("taylor_")); }
                    function isHeadset(n) {
                        const s = ((n.description || "") + " " + (n.name || "")).toLowerCase();
                        return s.includes("arctis") || s.includes("steelseries") || s.includes("gamedac") || s.includes("nova") || s.includes("headset") || s.includes("headphone");
                    }
                    function chan(key) { return Pipewire.nodes.values.find(n => n && n.isSink && !n.isStream && n.name === key) || null; }
                    readonly property var headset: hw().find(n => isHeadset(n)) || null
                    readonly property var speakers: hw().find(n => !isHeadset(n)) || null
                    readonly property var chans: [{ n: "Game", node: chan("taylor_game") }, { n: "Music", node: chan("taylor_music") }, { n: "Chat", node: chan("taylor_voice") }].filter(c => c.node)
                    PwObjectTracker { objects: [sound.sink].concat(sound.chans.map(c => c.node)).filter(n => n) }
                    Head { title: "Sound"; sub: sound.sink ? "Output and the mixer." : "No sound output found yet." }
                    SRow {
                        visible: sound.sink !== null
                        label: "Volume"
                        Row {
                            spacing: 12
                            Slider {
                                placeName: "volume"
                                from: 0; to: 100; step: 1
                                value: sound.sink && sound.sink.audio ? Math.round(sound.sink.audio.volume * 100) : 0
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => { if (sound.sink && sound.sink.audio) { sound.sink.audio.muted = false; sound.sink.audio.volume = v / 100; } }
                                onDone: (v) => console.info("taylor-settings: volume " + v)
                            }
                            Val { text: sound.sink && sound.sink.audio ? Math.round(sound.sink.audio.volume * 100) : ""; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        visible: sound.headset !== null && sound.speakers !== null
                        label: "Output"
                        Choice {
                            placePrefix: "output"
                            opts: [{ k: "speakers", n: "Speakers" }, { k: "headset", n: "Headphones" }]
                            value: sound.sink && sound.headset && sound.sink === sound.headset ? "headset" : "speakers"
                            onPick: (k) => {
                                const t = k === "headset" ? sound.headset : sound.speakers;
                                if (t) { Pipewire.preferredDefaultAudioSink = t; console.info("taylor-settings: output " + k); }
                            }
                        }
                    }
                    // her ask 2026-11-23: the mixer lives in Settings too, and its quick view on the desktop turns on and off here
                    SRow {
                        label: "Mixer"
                        small: "Every app's sound in one place."
                        Link {
                            placeName: "openmixer"
                            text: "Open the mixer"
                            onHit: { console.info("taylor-settings: open the mixer"); win.openMixer(); }
                        }
                    }
                    SRow {
                        label: "Mixer on the desktop"
                        small: "The quick view on the left of the desktop."
                        Switch { placeName: "mixerwidget"; on: Prefs.mixerWidget; onFlip: { Prefs.mixerWidget = !Prefs.mixerWidget; console.info("taylor-settings: mixer on the desktop " + Prefs.mixerWidget); } }
                    }
                    Repeater {
                        model: sound.chans
                        delegate: SRow {
                            id: cr
                            required property var modelData
                            label: modelData.n
                            Row {
                                spacing: 12
                                Slider {
                                    from: 0; to: 100; step: 1
                                    value: cr.modelData.node.audio ? Math.round(cr.modelData.node.audio.volume * 100) : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    onMoved: (v) => { if (cr.modelData.node.audio) cr.modelData.node.audio.volume = v / 100; }
                                }
                                Val { text: cr.modelData.node.audio ? Math.round(cr.modelData.node.audio.volume * 100) : ""; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }

                // ---- Display ----
                Column {
                    width: parent.width
                    visible: win.page === "Display"
                    Head { title: "Display"; sub: disp.name ? disp.name + (disp.now ? " · " + disp.now : "") : "Your screen." }
                    // the Windows layout (her ask 2026-11-25): resolution, refresh rate, scale, HDR, variable refresh
                    SRow {
                        label: "Resolution"
                        visible: disp.sizes.length > 1
                        Choice {
                            placePrefix: "res"
                            opts: disp.sizes.map((z) => ({ k: z, n: z.replace("x", " × ") }))
                            value: disp.size
                            onPick: (k) => disp.tryIt({ mode: k + "@" + disp.topRate(k) })
                        }
                    }
                    SRow {
                        label: "Refresh rate"
                        small: "Higher is smoother. Your screen's best is " + disp.topRate(disp.size) + " Hz."
                        visible: disp.rates.length > 0
                        Choice {
                            placePrefix: "rate"
                            opts: disp.rates.map((r) => ({ k: r, n: r + " Hz" }))
                            value: disp.rate
                            onPick: (k) => disp.tryIt({ mode: disp.size + "@" + k })
                        }
                    }
                    SRow {
                        label: "Scale"
                        small: "Makes text, apps and the dock bigger."
                        Choice {
                            placePrefix: "scale"
                            opts: [{ k: "0", n: "Auto" }, { k: "1", n: "100%" }, { k: "1.25", n: "125%" }, { k: "1.5", n: "150%" }, { k: "1.75", n: "175%" }, { k: "2", n: "200%" }]
                            value: String(disp.shown.scale)
                            onPick: (k) => disp.tryIt({ scale: Number(k) })
                        }
                    }
                    SRow {
                        label: "Use HDR"
                        small: disp.hdrOk === false ? "This screen doesn't say it can show HDR." : "Brighter highlights and deeper colour in games and videos made for HDR."
                        Switch { placeName: "hdr"; on: disp.shown.hdr; onFlip: disp.tryIt({ hdr: !disp.shown.hdr }) }
                    }
                    SRow {
                        visible: disp.shown.hdr
                        label: "SDR content brightness"
                        small: "How bright everything else looks while HDR is on"
                        Row {
                            spacing: 12
                            Slider {
                                id: sdrSlider
                                placeName: "sdr"
                                from: 50; to: 200; step: 5
                                value: Math.round(disp.shown.sdr * 100)
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => { value = v; }
                                onDone: (v) => disp.setSdr(v / 100)
                            }
                            Val { text: sdrSlider.value + "%"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        label: "Variable refresh rate"
                        small: "FreeSync or G-Sync: the screen waits for each new frame, so games don't tear or stutter."
                        Choice {
                            placePrefix: "vrr"
                            opts: [{ k: "0", n: "Off" }, { k: "2", n: "Games" }, { k: "1", n: "Always" }]
                            value: String(disp.shown.vrr)
                            onPick: (k) => disp.tryIt({ vrr: Number(k) })
                        }
                    }
                    // Windows' "Keep these display settings?": a screen that can't show a change comes back by itself
                    SRow {
                        visible: disp.pending
                        label: "Keep these display settings?"
                        small: "Going back in " + disp.left + " s"
                        Row {
                            spacing: 18
                            Link { placeName: "keep"; text: "Keep"; color: Theme.accent; onHit: disp.keep() }
                            Link { placeName: "revert"; text: "Go back"; onHit: disp.revert() }
                        }
                    }
                    SRow {
                        visible: Brightness.available
                        label: "Brightness"
                        Row {
                            spacing: 12
                            Slider {
                                placeName: "brightness"
                                from: 5; to: 100; step: 1
                                value: Brightness.level
                                anchors.verticalCenter: parent.verticalCenter
                                onMoved: (v) => Brightness.set(v)
                                onDone: (v) => { Prefs.brightness = v; console.info("taylor-settings: brightness " + v); }
                            }
                            Val { text: Brightness.level; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        visible: Brightness.probed && !Brightness.available
                        label: "Brightness"
                        small: "This screen doesn't take brightness from the PC. Use the buttons on the screen."
                    }
                    SRow {
                        label: "Warmer colors at night"
                        small: "From 8 in the evening to 7 in the morning"
                        Switch { placeName: "warm"; on: Prefs.warmNight; onFlip: { Prefs.warmNight = !Prefs.warmNight; console.info("taylor-settings: warmer at night " + Prefs.warmNight); } }
                    }
                }

                // ---- Network ----
                Column {
                    id: netPage
                    width: parent.width
                    visible: win.page === "Network"
                    property string wifi: "none"
                    property var nets: []
                    property var wired: []
                    property string joining: ""        // the new network whose password is being typed
                    property string busy: ""           // the network being connected to
                    Head { title: "Network"; sub: "Wi-Fi and wired." }
                    SRow {
                        visible: netPage.wifi !== "none"
                        label: "Wi-Fi"
                        Switch {
                            placeName: "wifi"
                            on: netPage.wifi === "on"
                            onFlip: { const to = netPage.wifi === "on" ? "off" : "on"; netPage.wifi = to; win.net(["wifi", to]); console.info("taylor-settings: wifi " + to); }
                        }
                    }
                    Repeater {
                        model: netPage.wifi === "on" ? netPage.nets : []
                        delegate: Column {
                            id: nr
                            required property var modelData
                            width: netPage.width
                            SRow {
                                label: nr.modelData.ssid
                                small: nr.modelData.inuse ? "Connected" : netPage.busy === nr.modelData.ssid ? "Connecting" : ""
                                clickable: !nr.modelData.inuse
                                onHit: {
                                    const m = nr.modelData;
                                    if (m.known || !m.secure) { netPage.busy = m.ssid; win.net(["connect", m.ssid]); }
                                    else netPage.joining = netPage.joining === m.ssid ? "" : m.ssid;
                                }
                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            required property int index
                                            width: 7; height: 7; radius: 3.5
                                            color: index < Math.max(1, Math.ceil(nr.modelData.signal / 25)) ? Theme.accent : Theme.dim
                                        }
                                    }
                                }
                            }
                            Item {
                                visible: netPage.joining === nr.modelData.ssid
                                width: parent.width; height: visible ? 34 : 0
                                Small { anchors.verticalCenter: parent.verticalCenter; text: "Password"; color: Theme.muted; font.pixelSize: 13 }
                                TextInput {
                                    id: pw
                                    x: 90; width: parent.width - 90; anchors.verticalCenter: parent.verticalCenter
                                    echoMode: TextInput.Password
                                    color: Theme.text; font.family: Theme.sans; font.pixelSize: 13
                                    focus: parent.visible
                                    onVisibleChanged: { if (visible) forceActiveFocus(); else text = ""; }
                                    onAccepted: { netPage.busy = nr.modelData.ssid; win.join(nr.modelData.ssid, text); text = ""; netPage.joining = ""; }
                                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: -3 } height: 1; color: Theme.accent }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: netPage.wired
                        delegate: SRow {
                            required property var modelData
                            label: "Wired"
                            small: modelData === "connected" ? "Connected" : modelData === "unavailable" ? "Not plugged in" : modelData.startsWith("connecting") ? "Connecting" : "Not connected"
                            Tag { text: modelData === "connected" ? "On" : "Off" }
                        }
                    }
                    SRow {
                        visible: netPage.wifi === "none" && netPage.wired.length === 0
                        label: "No network found yet"
                    }
                }

                // ---- About ----
                Column {
                    id: about
                    width: parent.width
                    visible: win.page === "About"
                    property string version: ""
                    property string cpu: ""
                    property string gpu: ""
                    property string auto: "unknown"
                    property bool checking: false
                    property int tick: 0
                    property string note: { tick; return win.updateNote(Prefs.updateState, Prefs.updateCheckedAt); }
                    Head { title: "About"; sub: "This PC." }
                    SRow { label: "TaylorOS"; Tag { text: about.version ? "Version " + about.version : "" } }
                    SRow { visible: about.cpu !== ""; label: "Processor"; Tag { text: about.cpu } }
                    SRow { visible: about.gpu !== ""; label: "Graphics"; Tag { text: about.gpu } }
                    SRow {
                        label: "Updates"
                        small: about.checking ? "Looking for a newer TaylorOS." : about.note
                        Link {
                            placeName: "checknow"
                            text: about.checking ? "Checking" : "Check now"
                            onHit: win.checkUpdates()
                        }
                    }
                    SRow {
                        label: "Install updates on their own"
                        small: "They download quietly at night and finish at the next restart"
                        Tag { text: about.auto === "on" ? "On" : about.auto === "off" ? "Off" : "" }
                    }
                }
            }
        }
    }

    // ---- what the rows do ----
    function setScheme(k) {
        if (Prefs.scheme === k) return;
        Prefs.scheme = k;
        console.info("taylor-settings: scheme " + k);
        reloadHypr.restart();
    }
    // Hyprland reads the scheme's accent for the window outline when it loads its settings (hyprland.lua)
    Timer {
        id: reloadHypr; interval: 500
        onTriggered: { Quickshell.execDetached(["hyprctl", "reload"]); console.info("taylor-settings: asked Hyprland to read its settings again"); }
    }
    function saveTimes() {
        Prefs.idleMinutes = lockPage.idle;
        Prefs.waitMinutes = lockPage.wait;
        console.info("taylor-settings: lock total=" + lockPage.total + " idle=" + lockPage.idle + " wait=" + lockPage.wait + " (it locks about " + lockPage.total + " minutes after she stops)");
    }

    // network
    function net(args) { netCmd.command = ["/usr/libexec/taylor-network"].concat(args); netCmd.running = true; }
    function join(ssid, pass) { joinCmd.pass = pass; joinCmd.command = ["/usr/libexec/taylor-network", "join", ssid]; joinCmd.running = true; }
    Process { id: netCmd; onExited: (code) => { console.info("taylor-settings: network change exit " + code); netPage.busy = ""; netState.running = true; } }
    Process {
        id: joinCmd
        property string pass: ""
        stdinEnabled: true
        onStarted: { write(pass + "\n"); pass = ""; }
        onExited: (code) => { console.info("taylor-settings: joined a new network, exit " + code); netPage.busy = ""; netState.running = true; }
    }
    Process {
        id: netState
        command: ["/usr/libexec/taylor-network", "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nets = [], wired = [];
                let wifi = "none";
                for (const line of this.text.split("\n")) {
                    const p = line.split(" ");
                    if (p[0] === "WIFI") wifi = p[1];
                    else if (p[0] === "NET" && p.length >= 6) nets.push({ inuse: p[1] === "1", signal: parseInt(p[2]) || 0, known: p[3] === "1", secure: p[4] === "1", ssid: p.slice(5).join(" ") });
                    else if (p[0] === "WIRED") wired.push(p.slice(1).join(" ").replace(/ \(.*\)$/, ""));
                }
                netPage.wifi = wifi; netPage.nets = nets; netPage.wired = wired;
                console.info("taylor-settings: network wifi=" + wifi + " networks=" + nets.length + " wired=" + wired.join(","));
            }
        }
    }
    // ---- her screen (Display): what it can do, from Hyprland; her picks in Prefs; Hyprland applies them through
    // taylor.display() in /usr/share/taylor-os/hypr/display.lua (which also reads them when the desktop starts)
    QtObject {
        id: disp
        property string name: ""
        property var modes: []          // [{w, h, hz}] from Hyprland, best first
        property real hz: 0             // what the screen runs at now
        property string now: ""
        property var hdrOk: null        // from the screen's EDID: true, false, or null (not known)
        property bool pending: false
        property int left: 15
        property var before: null
        property var pend: null
        readonly property var saved: ({ mode: Prefs.displayMode, scale: Prefs.displayScale, hdr: Prefs.hdr, sdr: Prefs.sdrBrightness, vrr: Prefs.vrr })
        readonly property var shown: pending && pend ? pend : saved
        readonly property var sizes: {
            const out = [];
            for (const m of modes) { const z = m.w + "x" + m.h; if (out.indexOf(z) < 0 && out.length < 4) out.push(z); }
            return out;
        }
        readonly property string size: shown.mode ? shown.mode.split("@")[0] : (sizes.length ? sizes[0] : "")
        readonly property var rates: {
            const out = [];
            for (const m of modes) {
                if (m.w + "x" + m.h !== size) continue;
                const r = String(Math.round(m.hz));
                if (out.indexOf(r) < 0 && Math.round(m.hz) >= 50) out.push(r);
            }
            return out.slice(0, 7);
        }
        readonly property string rate: shown.mode ? String(Math.round(Number(shown.mode.split("@")[1]))) : topRate(size)
        function topRate(z) {
            let best = 0;
            for (const m of modes) if (m.w + "x" + m.h === z) best = Math.max(best, Math.round(m.hz));
            return String(best || Math.round(hz) || 60);
        }
        function lua(v) {
            const mode = /^[0-9]+x[0-9]+@[0-9.]+$/.test(v.mode) ? v.mode : "";
            return "return taylor.display(\"" + mode + "\", " + Number(v.scale) + ", " + (v.hdr ? "true" : "false") + ", " + Number(v.sdr) + ", " + Math.round(v.vrr) + ")";
        }
        function apply(v) {
            console.info("taylor-settings: display " + JSON.stringify(v));
            applyProc.command = ["hyprctl", "eval", lua(v)];
            applyProc.running = true;
            relook.restart();
        }
        // a change she tries: shown at once, kept only when she says so
        function tryIt(change) {
            const base = pending && pend ? pend : saved;
            const next = { mode: base.mode, scale: base.scale, hdr: base.hdr, sdr: base.sdr, vrr: base.vrr };
            for (const k in change) next[k] = change[k];
            if (!pending) before = saved;
            pend = next;
            pending = true;
            left = 15;
            countdown.restart();
            apply(next);
        }
        function keep() {
            if (!pending) return;
            countdown.stop();
            Prefs.displayMode = pend.mode; Prefs.displayScale = pend.scale; Prefs.hdr = pend.hdr;
            Prefs.sdrBrightness = pend.sdr; Prefs.vrr = pend.vrr;
            pending = false;
            console.info("taylor-settings: display kept " + JSON.stringify(pend));
        }
        function revert() {
            if (!pending) return;
            countdown.stop();
            pending = false;
            console.info("taylor-settings: display back to " + JSON.stringify(before));
            apply(before);
        }
        // the SDR brightness can't hide the screen: it is kept as she lets go
        function setSdr(x) {
            if (pending) { tryIt({ sdr: x }); return; }
            Prefs.sdrBrightness = x;
            apply(saved);
        }
    }
    Timer {
        id: countdown
        interval: 1000; repeat: true
        onTriggered: { disp.left -= 1; if (disp.left <= 0) disp.revert(); }
    }
    Process { id: applyProc; stdout: StdioCollector { onStreamFinished: console.info("taylor-settings: hyprland says " + this.text.trim()) } }
    Timer { id: relook; interval: 1500; onTriggered: monProc.running = true }
    Process {
        id: monProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(this.text)[0];
                    if (!m) return;
                    disp.name = ((m.make || "") + " " + (m.model || "")).trim() || m.name;
                    disp.hz = m.refreshRate;
                    const list = [];
                    for (const a of (m.availableModes || [])) {
                        const r = /^([0-9]+)x([0-9]+)@([0-9.]+)Hz$/.exec(a);
                        if (r) list.push({ w: +r[1], h: +r[2], hz: +r[3] });
                    }
                    list.sort((x, y) => (y.w * y.h - x.w * x.h) || (y.hz - x.hz));
                    disp.modes = list;
                    disp.now = m.width + " × " + m.height + " at " + Math.round(m.refreshRate) + " Hz" + (m.colorManagementPreset === "hdr" ? ", HDR" : "") + (m.vrr ? ", variable refresh on" : "");
                    console.info("taylor-settings: screen " + m.name + " " + m.width + "x" + m.height + "@" + Math.round(m.refreshRate) + " scale " + m.scale + " cm " + m.colorManagementPreset + " vrr " + m.vrr);
                    if (disp.hdrOk === null) { edidProc.command = ["sh", "-c", "edid-decode /sys/class/drm/card*-" + m.name + "/edid 2>/dev/null | grep -q 'SMPTE ST2084' && echo yes || echo no"]; edidProc.running = true; }
                } catch (e) { console.info("taylor-settings: could not read the screen: " + e); }
            }
        }
    }
    Process { id: edidProc; stdout: StdioCollector { onStreamFinished: { const t = this.text.trim(); disp.hdrOk = t === "yes" ? true : (t === "no" ? false : null); } } }
    Timer { interval: 10000; repeat: true; triggeredOnStart: true; running: win.visible && win.page === "Display" && !disp.pending; onTriggered: monProc.running = true }

    Timer { interval: 10000; repeat: true; triggeredOnStart: true; running: win.visible && win.page === "Network"; onTriggered: netState.running = true }

    // about
    Process {
        id: aboutCmd
        running: win.visible && win.page === "About"
        command: ["sh", "-c",
            "/usr/libexec/taylor-update-check --local 2>/dev/null; " +
            "echo \"CPU $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)\"; " +
            "g=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null) && g=$(echo \"$g\" | head -1) || g=''; " +
            "[ -n \"$g\" ] || g=$(lspci -mm 2>/dev/null | grep -E '\"(VGA compatible controller|3D controller|Display controller)\"' | head -1 | sed -E 's/^[^\"]*\"[^\"]*\" \"[^\"]*\" \"([^\"]*)\".*/\\1/'); " +
            "echo \"GPU $g\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("TAYLOR-UPDATE")) {
                        const kv = win.kv(line);
                        about.version = kv.version && kv.version !== "-" ? kv.version.replace(/_/g, " ") : (kv.tag && kv.tag !== "latest" ? kv.tag : "");
                        about.auto = kv.auto || "unknown";
                    } else if (line.startsWith("CPU ")) about.cpu = win.cpuName(line.slice(4));
                    else if (line.startsWith("GPU ")) about.gpu = win.gpuName(line.slice(4));
                }
                console.info("taylor-settings: about version=" + about.version + " cpu=" + about.cpu + " gpu=" + about.gpu + " auto=" + about.auto);
            }
        }
    }
    function kv(line) {
        const o = {};
        for (const w of line.split(" ")) { const i = w.indexOf("="); if (i > 0) o[w.slice(0, i)] = w.slice(i + 1); }
        return o;
    }
    function cpuName(s) {
        return s.replace(/\((R|TM|tm|r)\)/g, "").replace(/\bCPU\b/g, "").replace(/@.*$/, "").replace(/\d+-Core Processor/i, "")
            .replace(/\bProcessor\b/g, "").replace(/^\s*(AMD|Intel)\s+/, "").replace(/\s+/g, " ").trim();
    }
    function gpuName(s) {
        const m = s.match(/\[([^\]]+)\]/);
        if (m) s = m[1];
        return s.replace(/^\s*NVIDIA\s+/, "").replace(/^GeForce\s+/, "").replace(/Corporation/g, "").replace(/\s+/g, " ").trim();
    }
    function checkUpdates() {
        if (about.checking) return;
        about.checking = true;
        console.info("taylor-settings: checking for updates");
        updCmd.running = true;
    }
    Process {
        id: updCmd
        command: ["/usr/libexec/taylor-update-check"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.split("\n").find(l => l.startsWith("TAYLOR-UPDATE")) || "";
                const kv = win.kv(line);
                Prefs.updateState = kv.state || "unknown";
                Prefs.updateCheckedAt = Date.now();
                if (kv.auto) about.auto = kv.auto;
                console.info("taylor-settings: update check " + (line || "gave no answer"));
            }
        }
        onExited: (code) => { about.checking = false; if (code !== 0) { Prefs.updateState = "unknown"; Prefs.updateCheckedAt = Date.now(); } }
    }
    function updateNote(state, at) {
        if (!at) return "Not checked yet.";
        const d = new Date(at), n = new Date();
        const mins = (n - d) / 60000;
        const sameDay = d.toDateString() === n.toDateString();
        const yest = new Date(n.getFullYear(), n.getMonth(), n.getDate() - 1).toDateString() === d.toDateString();
        const when = mins < 2 ? "Checked just now." : sameDay ? (d.getHours() < 12 ? "Last checked this morning." : d.getHours() < 18 ? "Last checked this afternoon." : "Last checked this evening.")
            : yest ? "Last checked yesterday." : "Last checked " + Qt.formatDate(d, "MMM d") + ".";
        const what = {
            uptodate: "Up to date.",
            staged: "A newer TaylorOS is ready: restart to finish.",
            newer: about.auto === "off" ? "A newer TaylorOS is out." : "A newer TaylorOS is out. It downloads on its own, then finishes at a restart.",
            offline: "Couldn't reach the update server. Try again later.",
            unknown: "Couldn't tell which TaylorOS this PC runs."
        }[state] || "";
        return when + " " + what;
    }
    // the "just now" wording ages while the window is open
    Timer { interval: 60000; repeat: true; running: win.visible; onTriggered: about.tick++ }
}
