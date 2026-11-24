// Her login scene drawn by the graphics card (2026-11-24, her report: "still 60" and laggy on her 240 Hz screen).
// Qt's canvas paints every frame on the processor and sends the whole 2560 x 1440 picture to the graphics card, which
// on her PC topped out near 120 frames a second. This file stands in for the canvas: scene_engine.js draws into it
// exactly as before (the same calls, her numbers untouched), and each dot, line and arc becomes 6 texels of a small data
// texture that prims.vert / prims.frag turn into shapes on the graphics card. The sky gradient, the hills and the faint
// waves are shaders of their own (sky.frag, hills.frag, waves.frag), and the words are Qt Quick text (Scene.qml).
//
// Each shape, 6 texels of 3 bytes (alpha is always 255):
//   t0 x0 (16 bit, (x + 2048) * 8), type      t1 y0, alpha             t2 x1 (an arc: its radius * 8), half width * 4
//   t3 y1, sweep low byte                     t4 colour r g b          t5 start angle (16 bit of 2 pi), sweep high byte
// types: 0 a round-ended line or a filled circle (x1 y1 = x0 y0), 1 an arc, 2 a flat-ended line

function make(cols, rows) {
    var max = Math.floor(cols * rows / 6);
    var r = {
        gpu: true, cols: cols, rows: rows, max: max, img: null, ctx: null,
        n: 0, split: -1, skyK: 0, hillsK: 0, wavesAl: 0, wavesT: 0, wavesS: 1, labels: [], top: false, dropped: 0,
        // the canvas state scene_engine.js sets
        globalAlpha: 1, fillStyle: '#000000', strokeStyle: '#000000', lineWidth: 1, lineCap: 'butt',
        font: '', textAlign: 'start', textBaseline: 'alphabetic',
        path: []
    };
    var cache = {};
    function colour(s) {
        if (typeof s !== 'string') return null;
        var c = cache[s];
        if (c) return c;
        var m;
        if (s.charAt(0) === '#' && s.length === 7) c = [parseInt(s.substr(1, 2), 16), parseInt(s.substr(3, 2), 16), parseInt(s.substr(5, 2), 16), 1];
        else if ((m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/.exec(s))) c = [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
        else c = [255, 0, 255, 1];
        cache[s] = c;
        return c;
    }
    var TAU = 6.283185307179586, D = null;
    // one shape into the texture; the hot loops of scene_engine.js call this through dot() / seg() / ring()
    function prim(type, x0, y0, x1, y1, hw, al, col, start, sweep) {
        var a = (al * col[3] * 255 + 0.5) | 0;
        if (a <= 0) return;
        if (r.n >= r.max) { r.dropped++; return; }
        if (a > 255) a = 255;
        var o = r.n * 24, v;
        v = ((x0 + 2048) * 8 + 0.5) | 0; if (v < 0) v = 0; else if (v > 65535) v = 65535; D[o] = v >> 8; D[o + 1] = v & 255; D[o + 2] = type;
        v = ((y0 + 2048) * 8 + 0.5) | 0; if (v < 0) v = 0; else if (v > 65535) v = 65535; D[o + 4] = v >> 8; D[o + 5] = v & 255; D[o + 6] = a;
        v = ((type === 1 ? x1 : x1 + 2048) * 8 + 0.5) | 0; if (v < 0) v = 0; else if (v > 65535) v = 65535; D[o + 8] = v >> 8; D[o + 9] = v & 255;
        v = (hw * 4 + 0.5) | 0; D[o + 10] = v > 255 ? 255 : v < 0 ? 0 : v;
        var sw = 0, st = 0;
        if (type === 1) {
            sw = sweep <= 0 ? 0 : sweep >= TAU ? 65535 : (sweep / TAU * 65535 + 0.5) | 0;
            st = start - TAU * Math.floor(start / TAU); st = (st / TAU * 65535 + 0.5) | 0; if (st > 65535) st = 65535;
            D[o + 12] = 0; D[o + 13] = 0;
        } else {
            v = ((y1 + 2048) * 8 + 0.5) | 0; if (v < 0) v = 0; else if (v > 65535) v = 65535; D[o + 12] = v >> 8; D[o + 13] = v & 255;
        }
        D[o + 14] = sw & 255;
        D[o + 16] = col[0]; D[o + 17] = col[1]; D[o + 18] = col[2];
        D[o + 20] = st >> 8; D[o + 21] = st & 255; D[o + 22] = sw >> 8;
        r.n++;
    }
    r.col = colour;
    r.dot = function (x, y, rad, al, cc) { prim(0, x, y, x, y, rad, al, cc, 0, 0); };
    r.seg = function (x0, y0, x1, y1, hw, al, cc) { prim(0, x0, y0, x1, y1, hw, al, cc, 0, 0); };
    r.ring = function (cx, cy, rad, s0, s1, hw, al, cc) { prim(1, cx, cy, rad, 0, hw, al, cc, s0, s1 - s0); };

    // ---- once a frame ----
    r.begin = function (ctx) {
        if (!r.img) {
            r.img = ctx.createImageData(cols, rows);
            var d = r.img.data;
            for (var i = 3; i < cols * rows * 4; i += 4) d[i] = 255;
        }
        D = r.img.data;
        r.ctx = ctx; r.n = 0; r.split = -1; r.skyK = 0; r.hillsK = 0; r.wavesAl = 0; r.labels = []; r.top = false;
        r.globalAlpha = 1; r.fillStyle = '#000000'; r.strokeStyle = '#000000'; r.lineWidth = 1; r.lineCap = 'butt';
        r.textAlign = 'start'; r.textBaseline = 'alphabetic'; r.path = [];
    };
    r.end = function () {
        if (r.split < 0) r.split = r.n;
        var used = Math.max(1, Math.ceil(r.n * 6 / cols));
        // Qt 6.11's canvas takes putImageData only in its seven-number form (the three-number one draws nothing)
        r.ctx.putImageData(r.img, 0, 0, 0, 0, cols, used);
    };

    // ---- what scene_engine.js hands over besides shapes ----
    r.waves = function (al, vt, s) { r.wavesAl = al; r.wavesT = vt; r.wavesS = s; };
    r.hills = function (k) { r.hillsK = k; r.split = r.n; };      // the shapes after the hills are drawn over them
    r.toTop = function () { r.top = true; };                      // the words after this are over the dial
    r.label = function (s, px, py, size, al, col, skyAl, skyCol) {
        r.labels.push({ s: String(s), x: px, y: py, size: size, al: al, col: col, skyAl: skyAl, skyCol: skyCol, top: r.top });
    };

    // ---- the canvas calls scene_engine.js and dial_draw.js make ----
    r.reset = function () {};
    r.save = function () {}; r.restore = function () {};
    r.beginPath = function () { r.path = []; };
    r.closePath = function () {};
    r.moveTo = function (x, y) { r.path.push([0, x, y]); };
    r.lineTo = function (x, y) { r.path.push([1, x, y]); };
    r.arc = function (cx, cy, rad, s0, s1, acw) {
        var sw = acw ? s0 - s1 : s1 - s0, st = acw ? s1 : s0;
        r.path.push([2, cx, cy, rad, st, sw]);
    };
    r.stroke = function () {
        var col = colour(r.strokeStyle), hw = r.lineWidth / 2, al = r.globalAlpha, round = r.lineCap === 'round';
        var px = 0, py = 0, have = false;
        for (var i = 0; i < r.path.length; i++) {
            var p = r.path[i];
            if (p[0] === 0) { px = p[1]; py = p[2]; have = true; }
            else if (p[0] === 1) { if (have) prim(round ? 0 : 2, px, py, p[1], p[2], hw, al, col, 0, 0); px = p[1]; py = p[2]; have = true; }
            else { prim(1, p[1], p[2], p[3], 0, hw, al, col, p[4], p[5]); have = false; }
        }
    };
    r.fill = function () {
        var col = colour(r.fillStyle), al = r.globalAlpha;
        for (var i = 0; i < r.path.length; i++) {
            var p = r.path[i];
            if (p[0] === 2) prim(0, p[1], p[2], p[1], p[2], p[3], al, col, 0, 0);   // her filled shapes are all whole circles
        }
    };
    r.fillRect = function (x, y, w, h) {
        if (r.fillStyle && r.fillStyle.grad) { r.skyK = r.globalAlpha; return; }   // the login sky (sky.frag)
        // the opening's and the login's own dark: the window's colour already
    };
    r.createLinearGradient = function () { return { grad: true, addColorStop: function () {} }; };
    r.measureText = function () { return { width: 0 }; };
    r.text = function () {};
    return r;
}
