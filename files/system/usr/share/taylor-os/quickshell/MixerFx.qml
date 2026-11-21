pragma Singleton
// The mixer's sound shaping (her brief: Mixer window, "Clicking a channel name or tab opens its sound shaping").
// Step 2: the equalizer. Ten bands per channel, each a PipeWire filter-chain biquad (bq_peaking, bq_lowshelf,
// bq_highshelf, bq_highpass = Low cut, bq_lowpass = High cut), plus three broad ones for her Bass / Voice / Treble
// lines (a low shelf at 100 Hz, a bell at 1.8 kHz, a high shelf at 6 kHz).
//
// A channel only gets a filter-chain when something in it is on and not flat (her brief: keep the audio light): then
// a small PipeWire process runs for it (taylor-mixer-fx@<channel>.service, its settings written to
// ~/.config/taylor-os/mixer-fx/<channel>.conf) and the channel's out side plays through it:
//   app -> taylor_game -> taylor_game.out -> taylor_game_fx (the shaping) -> taylor_game_fx.out -> her output
// Moving a band (frequency, gain, width) changes the running filter at once (pw-cli set-param, no gap in the sound);
// only a change of shape (a band's type, the equalizer on or off) restarts the little process (a short gap).
// The curve drawn in the window is computed with the same formulas as PipeWire's own biquads (its biquad.c, the RBJ
// "Audio EQ Cookbook" filters), at 48 kHz, PipeWire's usual rate.
// The approach (a filter-chain per channel, live set-param, restart only on a change of shape) follows what Arctis
// Sound Manager does (GPL-3.0, github.com/loteran/arctis-sound-manager); none of its code is used.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "mixer_presets.js" as Presets

Singleton {
    id: fx

    readonly property var freqs: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var types: ["Bell", "Low shelf", "High shelf", "Low cut", "High cut"]
    readonly property var labels: ["bq_peaking", "bq_lowshelf", "bq_highshelf", "bq_highpass", "bq_lowpass"]
    readonly property var channels: ["game", "chat", "media", "aux", "mic"]
    readonly property real rate: 48000
    readonly property string dir: MixerCore.dir + "/mixer-fx"
    property int rev: 0                 // bumped on every change (the drawing follows it)

    function flatBands() { return freqs.map(f => ({ f: f, g: 0, q: 1.4, t: 0 })); }
    function fresh(k) { return { eqOn: true, bands: flatBands(), tone: [0, 0, 0], pre: "Flat", follow: k === "game" }; }
    // a channel's shaping (a copy is made the first time she changes it)
    function get(k) {
        rev;
        const all = MixerCore.saved.fx || {};
        const s = all[k];
        if (!s || !s.bands || s.bands.length !== 10) return fresh(k);
        return s;
    }
    function put(k, s) {
        const all = Object.assign({}, MixerCore.saved.fx || {});
        all[k] = s;
        MixerCore.saved.fx = all;
        rev++;
        saveSoon.restart();
    }
    Timer { id: saveSoon; interval: 400; onTriggered: MixerCore.save() }
    function copy(s) { return JSON.parse(JSON.stringify(s)); }
    function toneBands(s) {
        return [{ f: 100, g: s.tone[0], q: 0.7, t: 1 }, { f: 1800, g: s.tone[1], q: 0.9, t: 0 }, { f: 6000, g: s.tone[2], q: 0.7, t: 2 }];
    }

    // ---- what she changes ----
    function setBand(k, i, f, g, q) {
        const s = copy(get(k)), b = s.bands[i];
        if (f !== undefined && f !== null) b.f = Math.max(20, Math.min(20000, f));
        if (g !== undefined && g !== null) b.g = Math.max(-12, Math.min(12, g));
        if (q !== undefined && q !== null) b.q = Math.max(0.3, Math.min(8, q));
        s.pre = "";
        put(k, s); changed(k);
    }
    function cycleType(k, i) {
        const s = copy(get(k));
        s.bands[i].t = (s.bands[i].t + 1) % 5;
        s.pre = "";
        put(k, s); changed(k);
    }
    function setTone(k, which, g) {
        const s = copy(get(k));
        s.tone[which] = Math.max(-12, Math.min(12, g));
        put(k, s); changed(k);
    }
    function setEq(k, on) { const s = copy(get(k)); s.eqOn = on; put(k, s); changed(k); console.info("taylor-mixer:", k, "equalizer", on ? "on" : "off"); }
    function setFollow(k, on) { const s = copy(get(k)); s.follow = on; put(k, s); if (on) followNow(); }
    function usePreset(k, name) {
        const p = Presets.find(name);
        if (!p) return;
        const s = copy(get(k));
        s.bands = freqs.map((f, i) => ({ f: f, g: p.gains[i], q: 1.4, t: 0 }));
        s.tone = [0, 0, 0];
        s.pre = name;
        put(k, s); changed(k);
        console.info("taylor-mixer:", k, "preset", name);
    }
    function presetGroups() { return Presets.groups; }
    readonly property string madeUp: Presets.made_up

    // ---- the real response (PipeWire's biquad.c, RBJ cookbook) ----
    // magnitude in dB of one band at frequency f
    function bandDb(b, f) {
        if (b.t < 3 && Math.abs(b.g) < 1e-6) return 0;
        const fn = Math.max(0, Math.min(1, b.f / (rate / 2)));       // PipeWire passes freq / nyquist
        const w0 = Math.PI * fn, k = Math.cos(w0), A = Math.pow(10, b.g / 40);
        const Q = b.q > 0 ? b.q : 0.707106781186548;
        const alpha = Math.sin(w0) / (2 * Q);
        let b0, b1, b2, a0, a1, a2;
        if (b.t === 0) {                 // bq_peaking
            b0 = 1 + alpha * A; b1 = -2 * k; b2 = 1 - alpha * A; a0 = 1 + alpha / A; a1 = -2 * k; a2 = 1 - alpha / A;
        } else if (b.t === 1 || b.t === 2) {
            const k2 = 2 * Math.sqrt(A) * alpha, ap = A + 1, am = A - 1;
            if (b.t === 1) {             // bq_lowshelf
                b0 = A * (ap - am * k + k2); b1 = 2 * A * (am - ap * k); b2 = A * (ap - am * k - k2);
                a0 = ap + am * k + k2; a1 = -2 * (am + ap * k); a2 = ap + am * k - k2;
            } else {                     // bq_highshelf
                b0 = A * (ap + am * k + k2); b1 = -2 * A * (am + ap * k); b2 = A * (ap + am * k - k2);
                a0 = ap - am * k + k2; a1 = 2 * (am - ap * k); a2 = ap - am * k - k2;
            }
        } else if (b.t === 3) {          // Low cut = bq_highpass
            b0 = (1 + k) / 2; b1 = -(1 + k); b2 = (1 + k) / 2; a0 = 1 + alpha; a1 = -2 * k; a2 = 1 - alpha;
        } else {                         // High cut = bq_lowpass
            b0 = (1 - k) / 2; b1 = 1 - k; b2 = (1 - k) / 2; a0 = 1 + alpha; a1 = -2 * k; a2 = 1 - alpha;
        }
        const w = 2 * Math.PI * f / rate, cw = Math.cos(w), c2 = Math.cos(2 * w);
        const n = b0 * b0 + b1 * b1 + b2 * b2 + 2 * (b0 * b1 + b1 * b2) * cw + 2 * b0 * b2 * c2;
        const d = a0 * a0 + a1 * a1 + a2 * a2 + 2 * (a0 * a1 + a1 * a2) * cw + 2 * a0 * a2 * c2;
        return 10 * Math.log(Math.max(1e-12, n / d)) / Math.LN10;
    }
    function responseDb(k, f) {
        const s = get(k);
        let y = 0;
        for (const b of s.bands) y += bandDb(b, f);
        for (const b of toneBands(s)) y += bandDb(b, f);
        return y;
    }

    // ---- the filter-chain ----
    function eqActive(s) {
        if (!s.eqOn) return false;
        return s.bands.some(b => b.t >= 3 || Math.abs(b.g) > 0.05) || s.tone.some(x => Math.abs(x) > 0.05);
    }
    function active(k) { return eqActive(get(k)); }
    function shape(k) {                 // what needs a restart when it changes
        const s = get(k);
        return JSON.stringify({ eq: eqActive(s) ? s.bands.map(b => b.t) : null });
    }
    function num(v) { return Number(v).toFixed(3); }
    function nodes(k) {
        const s = get(k), list = [];
        if (eqActive(s)) {
            s.bands.forEach((b, i) => list.push({ name: "b" + (i + 1), label: labels[b.t], c: { Freq: b.f, Q: b.q, Gain: b.t >= 3 ? 0 : b.g } }));
            toneBands(s).forEach((b, i) => list.push({ name: "t" + (i + 1), label: labels[b.t], c: { Freq: b.f, Q: b.q, Gain: b.g } }));
        }
        return list;
    }
    function conf(k) {
        const name = MixerCore.names[k], ns = nodes(k);
        let t = "# The TaylorOS mixer's sound shaping for " + name + " (written by the desktop, MixerFx.qml; rewritten when she\n"
              + "# changes it in the Mixer window). Run by taylor-mixer-fx@" + k + ".service.\n"
              + "context.properties = { log.level = 0 }\n"
              + "context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }\n"
              + "context.modules = [\n"
              + "  { name = libpipewire-module-rt args = { } flags = [ ifexists nofail ] }\n"
              + "  { name = libpipewire-module-protocol-native }\n"
              + "  { name = libpipewire-module-client-node }\n"
              + "  { name = libpipewire-module-adapter }\n"
              + "  { name = libpipewire-module-filter-chain\n    args = {\n"
              + "      node.description = \"TaylorOS " + name + ", sound shaping\"\n"
              + "      media.name = \"TaylorOS " + name + ", sound shaping\"\n"
              + "      filter.graph = {\n        nodes = [\n";
        for (const n of ns) {
            let c = "";
            for (const key in n.c) c += " \"" + key + "\" = " + num(n.c[key]);
            t += "          { type = builtin name = " + n.name + " label = " + n.label + " control = {" + c + " } }\n";
        }
        t += "        ]\n        links = [\n";
        for (let i = 1; i < ns.length; i++) t += "          { output = \"" + ns[i - 1].name + ":Out\" input = \"" + ns[i].name + ":In\" }\n";
        t += "        ]\n      }\n";
        if (k === "mic")      // the microphone: hers in, a shaped microphone out that apps record from
            t += "      audio.channels = 1\n      audio.position = [ MONO ]\n"
               + "      capture.props = { node.name = \"taylor_mic_fx.in\" node.passive = true audio.position = [ MONO ] }\n"
               + "      playback.props = { node.name = \"taylor_mic_fx\" node.description = \"TaylorOS Mic\" media.class = Audio/Source audio.position = [ MONO ] priority.session = 0 priority.driver = 0 }\n";
        else
            t += "      audio.channels = 2\n      audio.position = [ FL FR ]\n"
               + "      capture.props = { node.name = \"taylor_" + k + "_fx\" media.class = Audio/Sink audio.position = [ FL FR ] priority.session = 0 priority.driver = 0 }\n"
               + "      playback.props = { node.name = \"taylor_" + k + "_fx.out\" node.passive = true audio.position = [ FL FR ] }\n";
        t += "    }\n  }\n]\n";
        return t;
    }
    // the live values, for pw-cli set-param
    function params(k) {
        let p = "";
        for (const n of nodes(k)) for (const key in n.c) p += " \"" + n.name + ":" + key + "\" " + num(n.c[key]);
        return "{ params = [" + p + " ] }";
    }

    property var lastShape: ({})        // channel -> the shape its running process has
    property var dirty: ({})
    function changed(k) { dirty[k] = true; applySoon.restart(); }
    Timer { id: applySoon; interval: 60; onTriggered: fx.applyAll(false) }

    function unit(k) { return "taylor-mixer-fx@" + k + ".service"; }
    function writeAnd(k, after) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/$3.conf.new\" && mv \"$1/$3.conf.new\" \"$1/$3.conf\"" + (after ? " && " + after : ""),
                                 "sh", dir, conf(k), k]);
    }
    function applyAll(startup) {
        for (const k of channels) {
            if (!startup && !dirty[k]) continue;
            dirty[k] = false;
            const on = active(k), sh = shape(k);
            if (!on) {
                if (startup || lastShape[k]) {
                    if (!startup) hushFor(k);
                    Quickshell.execDetached(["sh", "-c", (startup ? "" : "sleep 0.3; ") + "systemctl --user stop " + unit(k)]);
                    if (lastShape[k]) console.info("taylor-mixer:", k, "sound shaping off (its filter stops)");
                }
                lastShape[k] = "";
                continue;
            }
            if (startup) {
                writeAnd(k, "systemctl --user start " + unit(k));
                lastShape[k] = sh;
                startedAt[k] = Date.now();
                console.info("taylor-mixer:", k, "sound shaping on at start");
            } else if (lastShape[k] !== sh || (!fxNode(k) && Date.now() - (startedAt[k] || 0) > 5000)) {
                hushFor(k);
                writeAnd(k, "sleep 0.3 && systemctl --user restart " + unit(k));
                console.info("taylor-mixer:", k, lastShape[k] ? "shape changed, filter restarted" : "sound shaping on (its filter starts)");
                lastShape[k] = sh;
                startedAt[k] = Date.now();
            } else if (fxNode(k)) {
                live(k);
            } else {
                pending[k] = true; pending = Object.assign({}, pending);      // still starting: its settings file has the new values; send them once it is up
                saveConf.restart();
            }
        }
    }
    // While a channel's filter stops or restarts its level meter is let go first (a meter left on a node that goes away
    // makes Quickshell log an error line); it comes back 2.5 s later.
    property var hush: ({})
    function hushFor(k) { const h = Object.assign({}, hush); h[k] = true; hush = h; unhush.restart(); }
    Timer { id: unhush; interval: 2500; onTriggered: fx.hush = ({}) }
    property var startedAt: ({})
    property var pending: ({})
    function live(k) {
        const n = fxNode(k);
        if (!n) return;
        Quickshell.execDetached(["pw-cli", "set-param", String(n.id), "Props", params(k)]);
        saveConf.restart();
    }
    Timer {
        interval: 400; repeat: true
        running: Object.keys(fx.pending).some(k => fx.pending[k])
        onTriggered: { for (const k of fx.channels) if (fx.pending[k] && fx.fxNode(k)) { fx.pending[k] = false; fx.live(k); } fx.pending = Object.assign({}, fx.pending); }
    }
    Timer { id: saveConf; interval: 800; onTriggered: { for (const k of fx.channels) if (fx.active(k)) fx.writeAnd(k, ""); } }
    // the node that holds the filter's controls (the capture side)
    function fxNode(k) { return k === "mic" ? MixerCore.byName("taylor_mic_fx.in", true) : MixerCore.byName("taylor_" + k + "_fx", false); }
    property bool begun: false
    Timer {
        interval: 1500; running: Pipewire.ready && !fx.begun; repeat: false
        onTriggered: { if (fx.begun) return; fx.begun = true; fx.applyAll(true); }
    }
    // a filter that should run but is gone (PipeWire restarted, it crashed): start it again
    Timer {
        interval: 6000; running: Pipewire.ready; repeat: true
        onTriggered: {
            for (const k of fx.channels)
                if (fx.lastShape[k] && !fx.fxNode(k) && Date.now() - (fx.startedAt[k] || 0) > 10000) {
                    fx.startedAt[k] = Date.now();
                    fx.writeAnd(k, "systemctl --user start " + fx.unit(k));
                    console.info("taylor-mixer:", k, "filter missing, starting it again");
                }
        }
    }

    // ---- Follow the game (Game): the focused full-screen window's game picks Game's preset ----
    readonly property var top: ToplevelManager.activeToplevel
    property string followed: ""
    function followNow() {
        const s = get("game");
        if (!s.follow || !top || !top.fullscreen) return;
        const p = Presets.forWindow(top.appId, top.title);
        if (p && p !== s.pre) {
            usePreset("game", p);
            followed = p;
            console.info("taylor-mixer: following the game:", p);
        }
    }
    onTopChanged: followNow()
    Connections {
        target: fx.top
        ignoreUnknownSignals: true
        function onFullscreenChanged() { fx.followNow(); }
        function onAppIdChanged() { fx.followNow(); }
    }

    function report() {
        const r = { top: top ? [top.appId, top.title, top.fullscreen] : null };
        for (const k of channels) {
            const s = get(k);
            r[k] = { on: active(k), node: !!fxNode(k), pre: s.pre, eqOn: s.eqOn, follow: !!s.follow, b: s.bands.map(b => [Math.round(b.f), Math.round(b.g * 10) / 10, Math.round(b.q * 100) / 100, b.t]), tone: s.tone };
        }
        return r;
    }
}
