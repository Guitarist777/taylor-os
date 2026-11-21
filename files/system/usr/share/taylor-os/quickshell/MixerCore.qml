pragma Singleton
// The TaylorOS mixer's state, shared by the desktop widget (Mixer.qml) and the Mixer window (MixerWindow.qml).
// Her brief: Master, Game, Chat, Media, Aux, Mic; per-app routing that is remembered; each channel its own output.
//
//   Master  the main output (speakers or headset; the word in the widget's corner picks it, the volume keys move it)
//   Game, Chat, Media, Aux   virtual outputs made by /etc/pipewire/pipewire.conf.d/taylor-mixer.conf (taylor_game ...)
//           each plays on through its "out" side (taylor_game.out ...) into the output picked for it
//   Mic     the default microphone
//
// Routing: an app's sound is sent to the channel she last dragged it to (remembered per app in
// ~/.config/taylor-os/mixer.json, applied each time that app's sound starts, by PipeWire's own target.object metadata);
// an app she never moved keeps the first guess of taylor-mixer-rules.conf, and an app named nowhere goes to Media.
// An app that asked for a particular output itself is left alone until she moves it.
// The Game / Chat balance is the volume of taylor_game.out and taylor_chat.out (ChatMix on her headset turns the same).
// Live levels: Quickshell's peak monitor, on a channel's out side (what she hears from it, after its fader and the
// balance, before its sound shaping), sampled ten times a second, and only while that channel is playing (the microphone only while an app records
// or the Mixer window is open), so nothing listens when nothing plays.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: m

    readonly property var keys: ["master", "game", "chat", "media", "aux", "mic"]
    readonly property var names: ({ master: "Master", game: "Game", chat: "Chat", media: "Media", aux: "Aux", mic: "Mic" })
    readonly property var appChannels: ["game", "chat", "media", "aux"]
    function sinkName(k) { return "taylor_" + k; }

    // ---- the nodes ----
    readonly property var all: Pipewire.nodes.values
    function byName(n, stream) {
        for (let i = 0; i < all.length; i++) {
            const x = all[i];
            if (x && x.name === n && x.isStream === stream) return x;
        }
        return null;
    }
    function isOurs(n) { return n && String(n.name || "").startsWith("taylor_"); }
    // real outputs (never one of the mixer's own)
    // every device-like node that is not the mixer's own (no properties are read here: the tracker below binds these,
    // and a list that read properties would change while it is being bound, a binding loop)
    readonly property var devSinks: all.filter(n => n && n.isSink && !n.isStream && !isOurs(n))
    readonly property var devSources: all.filter(n => n && !n.isSink && !n.isStream && !isOurs(n))
    readonly property var outputs: devSinks.filter(n => String((n.properties || {})["media.class"] || "Audio/Sink").startsWith("Audio/Sink"))
    function isHeadset(n) {
        const s = ((n.description || "") + " " + (n.name || "") + " " + (n.nickname || "")).toLowerCase();
        return s.includes("arctis") || s.includes("steelseries") || s.includes("gamedac") || s.includes("nova pro") || s.includes("headset");
    }
    readonly property var headset: outputs.find(n => isHeadset(n)) || null
    readonly property var speakers: outputs.find(n => !isHeadset(n)) || null
    readonly property var mainOut: (Pipewire.defaultAudioSink && !isOurs(Pipewire.defaultAudioSink)) ? Pipewire.defaultAudioSink : (speakers || headset)
    readonly property string mainWord: mainOut && isHeadset(mainOut) ? "Headset" : "Speakers"
    function word(n) { return n && isHeadset(n) ? "Headset" : "Speakers"; }

    // her real microphone (never the mixer's own shaped one)
    readonly property var sources: devSources.filter(n => String((n.properties || {})["media.class"] || "").startsWith("Audio/Source"))
    // (while the shaped microphone is the default, hers is the one that was the default before it)
    property var lastMic: ({ name: "" })    // changed in place on purpose: no binding follows it
    readonly property var micHw: {
        const d = Pipewire.defaultAudioSource;
        if (d && !isOurs(d)) { lastMic.name = d.name; return d; }
        const named = lastMic.name ? all.find(n => n && n.name === lastMic.name && !n.isStream) : null;
        return named || sources[0] || null;
    }
    readonly property var micFx: byName("taylor_mic_fx", false)
    // while her microphone has sound shaping, apps record from the shaped one; without it, from hers again
    onMicFxChanged: {
        // (by wpctl: Quickshell only takes a node it is bound to, and the shaped microphone is never bound)
        if (micFx) { Quickshell.execDetached(["wpctl", "set-default", String(micFx.id)]); console.info("taylor-mixer: apps record the shaped microphone"); }
        else if (micHw && Pipewire.defaultAudioSource !== micHw) { Quickshell.execDetached(["wpctl", "set-default", String(micHw.id)]); console.info("taylor-mixer: apps record her microphone directly"); }
    }
    readonly property var sinks: ({ game: byName("taylor_game", false), chat: byName("taylor_chat", false), media: byName("taylor_media", false), aux: byName("taylor_aux", false) })
    readonly property var outs: ({ game: byName("taylor_game.out", true), chat: byName("taylor_chat.out", true), media: byName("taylor_media.out", true), aux: byName("taylor_aux.out", true) })
    // the node whose volume and mute a channel's line moves
    function node(k) {
        if (k === "master") return mainOut;
        if (k === "mic") return micHw;
        return sinks[k] || null;
    }

    // the app streams: every playback stream that is not the mixer's own
    // (a node's properties are only known once it is tracked). Quickshell 0.2.1 can crash when a node it is bound to
    // vanishes at the wrong moment (seen here, 2026-11-21, with nodes that live a split second and with the sound-shaping
    // nodes that come and go with a restart), so only nodes that stay are tracked or metered: never a recording stream,
    // never a sound-shaping node.
    // Only streams that PLAY into an output or a channel are tracked (a recording stream, which may last a split second,
    // is never bound: binding a node that is already gone can crash Quickshell 0.2.1).
    // (Quickshell calls a playing stream "isSink": it takes sound in from the app; a recording stream is not one)
    readonly property var anyStreams: all.filter(n => n && n.isStream && n.isSink && !isOurs(n))
    readonly property var streams: anyStreams.filter(n => (n.properties || {})["media.class"] === "Stream/Output/Audio")
    PwObjectTracker {
        objects: m.appChannels.map(k => m.sinks[k]).concat(m.appChannels.map(k => m.outs[k])).concat(m.devSinks).concat(m.devSources).concat(m.anyStreams).filter(n => n)
    }

    function appKey(n) {
        const p = n.properties || {};
        return String(p["application.name"] || p["application.process.binary"] || n.description || n.name || "");
    }
    function appLabel(n) { return appKey(n); }

    // ---- which apps play into which channel, live (from PipeWire's own links) ----
    readonly property var groups: Pipewire.linkGroups.values
    function isQs(n) { return String(n.name || "").startsWith("quickshell"); }   // the peak monitors' own streams
    // apps routed to channel k: [{ key, label, node }]
    function apps(k) {
        const sink = sinks[k];
        if (!sink) return [];
        const seen = {}, list = [];
        for (const g of groups) {
            const s = g && g.source;
            if (!s || g.target !== sink || !s.isStream || isOurs(s)) continue;
            const key = appKey(s);
            if (seen[key]) continue;
            seen[key] = true;
            list.push({ key: key, label: appLabel(s), node: s });
        }
        return list;
    }
    // an app is sending sound to channel k (Master: to any channel, or straight to the main output; Mic: an app records)
    // (PipeWire's link states are not used: following them made Quickshell log errors whenever a link went away)
    function linked(k) {
        if (k === "master") return appChannels.some(c => linked(c)) || groups.some(g => g && g.target === mainOut && g.source && g.source.isStream && !isOurs(g.source));
        if (k === "mic") {
            const src = micFx || micHw;
            return !!src && groups.some(g => g && g.source === src && g.target && g.target.isStream && !isQs(g.target));
        }
        const sink = sinks[k];
        return !!sink && groups.some(g => g && g.target === sink && g.source && g.source.isStream && !isOurs(g.source));
    }
    // something is playing into channel k now: an app is linked and its level was above -70 dB in the last 1.5 s
    // (a paused app stays linked but is silent, so its channel dims)
    property var loud: ({})
    function playing(k) {
        if (k === "mic") return linked("mic");
        if (k === "master") return appChannels.some(c => playing(c)) || (linked("master") && !!loud.master);
        return linked(k) && !!loud[k];
    }

    // where a channel's out side is linked now (the output it plays into)
    function outTarget(k) {
        const fo = fxOut(k);
        return linkedTo(fo && fxIn(k) ? fo : outs[k]);
    }

    // ---- volume, mute ----
    function vol(k) { const n = node(k); return n && n.audio ? Math.max(0, Math.min(1, n.audio.volume)) : 0; }
    function muted(k) { const n = node(k); return !!(n && n.audio && n.audio.muted); }
    function live(k) { const n = node(k); return !!(n && n.audio); }
    function setVol(k, v) {
        const n = node(k);
        if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute(k) {
        const n = node(k);
        if (n && n.audio) { n.audio.muted = !n.audio.muted; console.info("taylor-mixer:", names[k], n.audio.muted ? "muted" : "on"); }
    }

    // ---- the Game / Chat balance: -1 all Game .. 0 both full .. +1 all Chat ----
    readonly property real balance: {
        const g = outs.game && outs.game.audio ? outs.game.audio.volume : 1;
        const c = outs.chat && outs.chat.audio ? outs.chat.audio.volume : 1;
        return Math.max(-1, Math.min(1, c - g));
    }
    function setBalance(b) {
        b = Math.max(-1, Math.min(1, b));
        if (Math.abs(b) < 0.03) b = 0;
        if (outs.game && outs.game.audio) outs.game.audio.volume = 1 - Math.max(0, b);
        if (outs.chat && outs.chat.audio) outs.chat.audio.volume = 1 + Math.min(0, b);
    }

    // ---- outputs ----
    // the output a channel plays into: hers if she picked one for it, else the main output
    function chosenOut(k) {
        const w = (store.outs || {})[k] || "";
        if (w === "headset" && headset) return headset;
        if (w === "speakers" && speakers) return speakers;
        return mainOut;
    }
    function outWord(k) {
        if (k === "master") return "Everything";
        if (k === "mic") return "Microphone";
        return word(chosenOut(k));
    }
    // the word in the widget's corner: the main output for everything
    function toggleMain() {
        const to = isHeadset(mainOut) ? speakers : headset;
        if (!to) { console.info("taylor-mixer: only one output, nothing to switch to"); return; }
        Pipewire.preferredDefaultAudioSink = to;
        const o = {};
        store.outs = o;                 // every channel follows the main output again
        fv.writeAdapter();
        console.info("taylor-mixer: main output", word(to));
    }
    // the word under a channel's name: that channel alone to the other output
    function toggleOut(k) {
        if (appChannels.indexOf(k) < 0) return;
        const now = chosenOut(k);
        const to = isHeadset(now) ? speakers : headset;
        if (!to) { console.info("taylor-mixer: only one output, nothing to switch to"); return; }
        const o = Object.assign({}, store.outs || {});
        o[k] = to === mainOut ? "" : (isHeadset(to) ? "headset" : "speakers");
        store.outs = o;
        fv.writeAdapter();
        console.info("taylor-mixer:", names[k], "plays to", word(to));
        pinAll();
    }

    // Keep each channel's out side linked to its output (also after the main output changes, an output comes or goes,
    // or PipeWire restarts). Done by PipeWire's own target metadata; checked against the real links.
    property var pinned: ({})          // node id -> [target last asked for, when]
    function fxIn(k) { return byName("taylor_" + k + "_fx", false); }
    function fxOut(k) { return byName("taylor_" + k + "_fx.out", true); }
    function linkedTo(src) {
        if (!src) return null;
        for (const g of groups) if (g && g.source === src && g.target && !g.target.isStream) return g.target;
        return null;
    }
    function pinNode(src, want, label) {
        if (!src || !want) return;
        const now = linkedTo(src);
        if (now && now.name === want.name) return;
        const last = pinned[src.id];
        if (last && last[0] === want.name && Date.now() - last[1] < 4000) return;   // asked already; give it a moment
        pinned[src.id] = [want.name, Date.now()];
        Quickshell.execDetached(["pw-metadata", String(src.id), "target.object", want.name]);
        console.info("taylor-mixer:", label, "->", want.name);
    }
    // a channel's out side plays into its sound shaping when that runs, and the shaping (or the out side) into her output
    function pin(k) {
        const o = outs[k], want = chosenOut(k), fi = fxIn(k), fo = fxOut(k);
        if (fi && fo) { pinNode(o, fi, names[k] + " out"); pinNode(fo, want, names[k] + " shaping out"); }
        else pinNode(o, want, names[k] + " out");
    }
    function pinAll() {
        for (const k of appChannels) pin(k);
        // (the microphone's shaping is told its source in its own settings, MixerFx.conf)
    }
    Timer { interval: 1500; repeat: true; running: Pipewire.ready; onTriggered: m.pinAll() }

    // ---- routing ----
    property var handled: ({})         // stream id -> true, once routed
    function targetName(n) { const p = n.properties || {}; return String(p["target.object"] || p["node.target"] || ""); }
    function route(n) {
        if (!n || !n.ready || handled[n.id]) return;
        const p = n.properties || {};
        if (p["media.class"] !== "Stream/Output/Audio" || isOurs(n)) return;
        if (String(p["node.dont-move"] || "") === "true" || String(p["node.autoconnect"] || "") === "false") { handled[n.id] = true; return; }
        handled[n.id] = true;
        const key = appKey(n);
        const want = (store.routes || {})[key];
        let to = "";
        if (want && appChannels.indexOf(want) >= 0) to = sinkName(want);
        else {
            const t = targetName(n), role = String(p["media.role"] || "");
            if (t !== "") return;                         // a first guess of the rules, or the app's own choice
            to = role === "Game" ? "taylor_game" : (role === "Communication" || role === "Phone") ? "taylor_chat" : "taylor_media";
        }
        if (targetName(n) === to) return;
        Quickshell.execDetached(["pw-metadata", String(n.id), "target.object", to]);
        console.info("taylor-mixer: app", key, "->", to, want ? "(remembered)" : "(default)");
    }
    onStreamsChanged: { for (const s of streams) route(s); }
    Timer { interval: 700; repeat: true; running: m.streams.length > 0; onTriggered: { for (const s of m.streams) m.route(s); } }

    // her drag: app (its key) onto channel k; remembered
    function moveApp(key, k) {
        if (appChannels.indexOf(k) < 0 || !key) return;
        const r = Object.assign({}, store.routes || {});
        r[key] = k;
        store.routes = r;
        fv.writeAdapter();
        for (const s of streams) {
            if (appKey(s) === key) {
                handled[s.id] = true;
                Quickshell.execDetached(["pw-metadata", String(s.id), "target.object", sinkName(k)]);
            }
        }
        console.info("taylor-mixer: app", key, "moved to", names[k], "(remembered)");
    }
    function rememberedRoute(key) { return String((store.routes || {})[key] || ""); }
    function channelOfApp(key) {
        for (const k of appChannels) if (apps(k).some(a => a.key === key)) return k;
        return "";
    }

    // ---- live levels ----
    property bool widgetShown: false   // the widget and the window say when they are on screen
    property bool windowOpen: false
    property string shapingSub: ""     // the checks open a sound-shaping section by name
    readonly property int viewers: (widgetShown ? 1 : 0) + (windowOpen ? 1 : 0)
    function meterOn(k) {
        if (viewers <= 0) return false;
        if (MixerFx.hush[k]) return false;          // its filter is restarting
        if (k === "mic") return windowOpen || linked("mic");
        return linked(k);
    }
    PwNodePeakMonitor { id: pkMaster; node: m.mainOut; enabled: m.meterOn("master") }
    PwNodePeakMonitor { id: pkGame; node: m.outs.game; enabled: m.meterOn("game") }
    PwNodePeakMonitor { id: pkChat; node: m.outs.chat; enabled: m.meterOn("chat") }
    PwNodePeakMonitor { id: pkMedia; node: m.outs.media; enabled: m.meterOn("media") }
    PwNodePeakMonitor { id: pkAux; node: m.outs.aux; enabled: m.meterOn("aux") }
    PwNodePeakMonitor { id: pkMic; node: m.micHw; enabled: m.meterOn("mic") }
    readonly property var peakMon: ({ master: pkMaster, game: pkGame, chat: pkChat, media: pkMedia, aux: pkAux, mic: pkMic })
    // 0..1 for the dots: -60 dB .. 0 dB
    property var heard: ({})           // channel -> when it was last above -70 dB
    property var levels: ({ master: 0, game: 0, chat: 0, media: 0, aux: 0, mic: 0 })
    function dbFrac(p) { if (!(p > 0)) return 0; return Math.max(0, Math.min(1, (20 * Math.log(p) / Math.LN10 + 60) / 60)); }
    Timer {
        interval: 90; repeat: true
        running: m.viewers > 0
        onTriggered: {
            const L = {}, now = Date.now();
            let changed = false;
            const loud = Object.assign({}, m.loud);
            for (const k of m.keys) {
                const pm = m.peakMon[k];
                const raw = pm && pm.enabled ? pm.peak : 0;
                let p = raw;
                if (k === "master") p = p * Math.pow(m.vol("master"), 3);   // its monitor is before the output's own volume
                L[k] = m.muted(k) ? 0 : m.dbFrac(p);
                if (raw > 0.0003) m.heard[k] = now;
                const on = now - (m.heard[k] || 0) < 1500;
                if (!!loud[k] !== on) { loud[k] = on; changed = true; }
            }
            m.levels = L;
            if (changed) m.loud = loud;
        }
    }

    // ---- what she chose, remembered ----
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/taylor-os"
    FileView {
        id: fv
        path: m.dir + "/mixer.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: (err) => { if (err === FileViewError.FileNotFound) { Quickshell.execDetached(["mkdir", "-p", m.dir]); writeAdapter(); } }
        JsonAdapter {
            id: store
            property var routes: ({})      // app name -> game | chat | media | aux
            property var outs: ({})        // channel -> "" (the main output) | speakers | headset
            property var fx: ({})          // channel -> its sound shaping (MixerFx.qml)
        }
    }
    function save() { fv.writeAdapter(); }
    property alias saved: store

    // for the checks: where things are drawn ("x y" inside their own window; the widget's window sits 40 px from the
    // left and 138 px from the top of her main screen)
    property var spots: ({})
    function spot(name, item) { spots[name] = item; }
    function where(name) {
        if (name.startsWith("eq:band:")) {           // a band's dot on the equalizer graph shown now
            const g = spots["eq:graph"];
            if (!g || !g.visible) return "";
            const b = g.bandPos(parseInt(name.slice(8)) - 1), p = g.mapToItem(null, b.x, b.y);
            return Math.round(p.x) + " " + Math.round(p.y);
        }
        const it = spots[name];
        if (!it || !it.visible) return "";
        const p = it.mapToItem(null, it.width / 2, it.height / 2);
        return Math.round(p.x) + " " + Math.round(p.y);
    }

    // a short report for the checks (names and numbers only)
    function report() {
        const r = { main: mainOut ? mainOut.name : "", mainWord: mainWord, balance: Math.round(balance * 100) / 100, ch: {} };
        for (const k of keys) {
            r.ch[k] = { vol: Math.round(vol(k) * 100), muted: muted(k), playing: playing(k), dots: Math.round((levels[k] || 0) * 12), out: outWord(k) };
            if (appChannels.indexOf(k) >= 0) { r.ch[k].apps = apps(k).map(a => a.key); const t = outTarget(k); r.ch[k].to = t ? t.name : ""; }
        }
        r.streams = streams.map(s => ({ id: s.id, app: appKey(s), ready: s.ready, target: targetName(s), routed: !!handled[s.id] }));
        r.fx = MixerFx.report();
        return JSON.stringify(r);
    }
}
