.import "intro_points.js" as Pts
.import "dial_draw.js" as Dial
// Her login scene, three of her own pieces played as one, moved over line for line (the numbers are hers):
//   A. the opening (TaylorOS_boot_animation.html): sparks pour in, swirl into a ball, the dial draws round it, the ball
//      pulls back, the sparks spell "TaylorOS", two run off to play and hop home, a ripple goes out;
//   B. the hand-off (tayloros_step1_boot_to_login_handoff_v5.html): the word loosens, some sparks rise to become stars
//      over dark hills and a moon, the rest drift up and fade, the clock and date arrive, TAYLOR's dial draws itself
//      (her 1.75 s), and her name;
//   C. the login (tayloros_step2_login_screen_interactive_v2.html): each letter typed pulls a star down onto the dial
//      as a green dot; a good password fills the ring, spins it and sends a pulse out ("Welcome back"); a wrong one
//      shakes the dial and scatters the dots.
//   D. the unlock (tayloros_login_unlock_to_desktop_full_sequence.html): after "Welcome back" a pulse goes out, the
//      login fades, the dots on the ring rise to become stars, faint stars fall into her spot right of centre and
//      her desktop dial draws itself there. The desktop (quickshell/Arrival.qml) takes over from that picture.
// Her mockups are 380 px tall; here every length is multiplied by k = screen height / 380, so it is her layout, larger.
// Not a library on purpose: each screen gets its own copy.

var W = 0, H = 0, S = 1, R = 100, k = 1, P = [], t = 0, T = 0;
var cols = ['#4FB386', '#7FD0A8', '#3A9A70', '#A8E3C6', '#2E7F5C'], ACC = '#4FB386';
var A_END = 14.6;         // the opening hands over (the word has held and the first ripple has gone out)
var Dd = 1.75;            // her dial draw time
var tb = -1;              // seconds into the hand-off (B), -1 before it
var skipCover = 0;        // a key or click during the opening jumps to the login; this dark lifts over half a second
var FONT = 'Manrope';
// Qt's canvas takes a font line only as "<size>px <family>" (with normal/bold): a number weight such as 500 makes it
// throw the whole line away and draw at its tiny default size (2026-11-19 VM test).
function fontAt(px) { return Math.round(px) + 'px ' + FONT; }
var name = '';

// C, the login
var SL = 24, dots = [], free = [], mode = 'idle', tm = 0, fillDur = 0, hint = 'Type your password', hintT = 0, rot = 0;
var stars = [];           // the sparks that became stars (B), with their resting places
var fly = [], fall = [];  // D: the ring's dots rising to stars, and the faint stars falling into the desktop dial

function cl(v) { return Math.max(0, Math.min(1, v)); }
function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

function setSize(w, h) {
    W = w || 680; H = h || 380;
    S = Math.max(0.5, Math.min(W / 680, H / 380));
    R = Math.min(H * 0.27, W * 0.2);
    k = H / 380;
}
function setName(n) { name = n; }
function setFont(f) { if (f) FONT = f; }

function targets() {
    var F = Math.min(H * 0.3, W * 0.165), st = F * Pts.STEP, c = Pts.cells(), pts = [];
    for (var i = 0; i < c.length; i++) pts.push([W / 2 + c[i][0] * st, H / 2 + c[i][1] * st]);
    return pts;
}

function shuffle() {
    free = []; for (var i = 0; i < SL; i++) free.push(i);
    for (var j = SL - 1; j > 0; j--) { var q = Math.floor(Math.random() * (j + 1)), x = free[j]; free[j] = free[q]; free[q] = x; }
}

function spawn() {
    P = []; t = 0; T = 1000 * Math.random(); tb = -1; skipCover = 0;
    dots = []; shuffle(); mode = 'idle'; hint = 'Type your password'; rot = 0;
    var pts = targets(), n = pts.length, ring = 260, total = n + ring;
    for (var i = 0; i < total; i++) {
        var sx = W + (6 + Math.random() * 10) * S, sy = H + (6 + Math.random() * 10) * S;
        var th = 0.7854 + (Math.random() - 0.5) * 1.6, ct = Math.cos(th), st = Math.sin(th);
        var ray = Math.min(ct > 0.02 ? W / ct : 1e6, st > 0.02 ? H / st : 1e6);
        var kk = 1.9 + Math.random() * 0.9, s = kk * ray * (0.15 + 0.8 * Math.sqrt(Math.random()));
        var isT = i < n;
        P.push({ d: Math.pow(Math.random(), 1.2) * 1.7, x: sx, y: sy, vx: -ct * s, vy: -st * s, k: kk, age: 0, z: 0, g: 0, m: 0, role: 0,
            t: isT, tx: isT ? pts[i][0] : 0, ty: isT ? pts[i][1] : 0,
            phi: Math.acos(1 - 2 * Math.random()), th: Math.random() * 6.2832,
            ang: Math.random() * 6.2832, rr: (Math.random() - 0.5) * 26 * S, sp: 0.16 + Math.random() * 0.14,
            r: (isT ? 1.25 + Math.random() * 0.5 : 0.9 + Math.random() * 1.6) * S, col: cols[i % cols.length], ph: Math.random() * 6.28,
            // B (her hand-off): about a quarter become stars, high in the sky; the rest drift up and fade
            star: Math.random() < 0.24, dl: Math.random() * 0.9,
            ssx: Math.random() * W, ssy: (8 + Math.pow(Math.random(), 1.3) * 380 * 0.68) * k,
            up: (60 + Math.random() * 110) * k, dr: (Math.random() - 0.5) * 60 * k,
            sr: (0.45 + Math.random() * 0.95) * k, tw: 0.6 + Math.random() * 1.6, hx: 0, hy: 0, gone: 0 });
    }
    if (n > 2) {
        var li = 0, i2;
        for (i2 = 1; i2 < n; i2++) { if (P[i2].tx > P[li].tx || (P[i2].tx === P[li].tx && P[i2].ty > P[li].ty)) li = i2; }
        var fi = -1, bd = 1e12;
        for (i2 = 0; i2 < n; i2++) { if (i2 === li) continue; var ddx = P[i2].tx - P[li].tx, ddy = P[i2].ty - P[li].ty, dd = ddx * ddx + ddy * ddy; if (dd < bd) { bd = dd; fi = i2; } }
        P[li].role = 1; P[li].d = Math.min(P[li].d, 0.8); P[li].r = 1.6 * S;
        P[fi].role = 2; P[fi].d = Math.min(P[fi].d, 0.8); P[fi].r = 1.6 * S;
    }
    stars = [];
    for (var j = 0; j < P.length; j++) if (P[j].star) stars.push(P[j]);
}

// ---------- A: the opening (her code) ----------

function back(t) { return sm((t - 5.0) / 1.1); }

function story(p, t) {
    var ax = W * 0.14, ay = H * 0.8, hx = p.tx, hy = p.ty, u, px, py, HOP = 20 * S;
    if (p.role === 1) {
        if (t < 8.0) { u = sm((t - 6.0) / 2.0); px = W / 2 + (ax - W / 2) * u; py = H / 2 + (ay - H / 2) * u + Math.sin(u * 9.4) * 14 * S * (1 - u); }
        else if (t < 10.7) { px = ax + 16 * S * Math.sin((t - 8.0) * 2.4); py = ay + 3 * S * Math.sin((t - 8.0) * 5); }
        else if (t < 11.4) { px = ax; py = ay - (t < 11.15 ? Math.abs(Math.sin((t - 10.7) / 0.45 * 3.1416)) * HOP : 0); }
        else { u = sm((t - 11.4) / 1.9); px = ax + (hx - ax) * u; py = ay + (hy - ay) * u + Math.sin(u * 12.5) * 7 * S * Math.sin(u * 3.1416); }
    } else {
        var bx = ax + 22 * S, by = ay - 4 * S;
        if (t < 9.3) { px = hx; py = hy; }
        else if (t < 10.7) { u = sm((t - 9.3) / 1.4); px = hx + (bx - hx) * u; py = hy + (by - hy) * u + Math.sin(u * 12.5) * 9 * S * Math.sin(u * 3.1416); }
        else if (t < 11.35) { px = bx; py = by - ((t > 10.88 && t < 11.3) ? Math.abs(Math.sin((t - 10.88) / 0.42 * 3.1416)) * HOP * 0.58 : 0); }
        else { u = sm((t - 11.35) / 1.8); px = bx + (hx - bx) * u; py = by + (hy - by) * u + Math.sin(u * 12.5) * 7 * S * Math.sin(u * 3.1416); }
    }
    return [px, py];
}

function step(p, dt, T, t) {
    p.age += dt;
    var cx = W / 2, cy = H / 2, a1 = p.th + T * 0.7, sp = Math.sin(p.phi), Rs = R * (1 - 0.5 * back(t));
    var sx = cx + Rs * sp * Math.cos(a1), sy = cy + Rs * Math.cos(p.phi), z = sp * Math.sin(a1);
    var fx = p.tx, fy = p.ty;
    if (!p.t) { var a = p.ang + T * p.sp; fx = cx + Math.cos(a) * (W * 0.4 + p.rr); fy = cy + Math.sin(a) * (H * 0.37 + p.rr * 0.6); }
    var m = sm((t - 6.0) / 1.1), tx = sx + (fx - sx) * m, ty = sy + (fy - sy) * m, ks = 16 + (p.t ? 4 : -7) * m, dmp = 6.5;
    if (p.role && t >= 6.0) {
        var q = story(p, t), hop = sm((t - 10.4) / 0.3) * (1 - sm((t - 11.4) / 0.4));
        ks = 22 + 150 * hop; dmp = 6.5 + 12 * hop;
        if (p.role === 1) { tx = q[0]; ty = q[1]; m = 1; }
        else { tx = sx + (q[0] - sx) * m; ty = sy + (q[1] - sy) * m; }
    }
    p.z = z * (1 - m);
    var g = cl((p.age - 1.0) / 1.3);
    var dx = p.x - cx, dy = p.y - cy, sg = W * 0.2, gz = Math.exp(-(dx * dx + dy * dy) / (2 * sg * sg));
    var w = 1.2 * gz * (1 - g) * dt, cs = Math.cos(w), sn = Math.sin(w), vx = p.vx * cs - p.vy * sn, vy = p.vx * sn + p.vy * cs;
    vx += (tx - p.x) * ks * g * dt; vy += (ty - p.y) * ks * g * dt;
    var f = Math.exp(-(p.k * (1 - g) + dmp * g) * dt);
    p.vx = vx * f; p.vy = vy * f;
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.g = g; p.m = m;
}

function waves(x, al) {
    x.lineWidth = Math.max(1, S * 0.8);
    for (var j = 0; j < 9; j++) {
        x.globalAlpha = al;
        x.strokeStyle = 'rgba(165,172,168,' + (0.035 + j * 0.006) + ')';
        x.beginPath();
        var base = H * (0.1 + j * 0.105), amp = (5 + j * 1.1) * S, sp = 0.3 + j * 0.04, stp = Math.max(8, W / 120);
        for (var u = 0; u <= W + stp; u += stp) {
            var un = u / S, yy = base + Math.sin(un * 0.009 + T * sp + j * 1.7) * amp + Math.sin(un * 0.023 - T * sp * 0.7 + j * 0.9) * amp * 0.45;
            if (u === 0) x.moveTo(u, yy); else x.lineTo(u, yy);
        }
        x.stroke();
    }
    x.globalAlpha = 1;
}

function bigDial(x, t, T) {
    var a = sm((t - 2.3) / 1.5), out = back(t);
    if (a <= 0 || out >= 1) return;
    var cx = W / 2, cy = H / 2, sc = 1 - 0.5 * out, al = Math.pow(1 - out, 1.6), Rd = (R + 22 * S) * sc, q = sc * S, s0 = -1.5708, s1 = s0 + a * 6.2832;
    x.lineCap = 'round';
    x.strokeStyle = ACC;
    x.globalAlpha = 0.12 * al; x.lineWidth = 9 * q; x.beginPath(); x.arc(cx, cy, Rd, s0, s1, false); x.stroke();
    x.globalAlpha = 0.95 * al; x.lineWidth = Math.max(0.5, 1.5 * q); x.beginPath(); x.arc(cx, cy, Rd, s0, s1, false); x.stroke();
    x.strokeStyle = '#EDEFEE'; x.lineWidth = Math.max(0.5, q);
    var nt = Math.floor(72 * a);
    for (var i = 0; i < nt; i++) {
        var an = s0 + i / 72 * 6.2832, big = i % 6 === 0, r0 = Rd + 9 * q, r1 = Rd + (big ? 17 : 13) * q;
        x.globalAlpha = (big ? 0.55 : 0.28) * al;
        x.beginPath(); x.moveTo(cx + Math.cos(an) * r0, cy + Math.sin(an) * r0); x.lineTo(cx + Math.cos(an) * r1, cy + Math.sin(an) * r1); x.stroke();
    }
    x.strokeStyle = ACC; x.lineWidth = Math.max(0.6, 2.5 * q);
    var b = sm((t - 3.2) / 0.9);
    for (var j = 0; j < 3; j++) {
        var st = T * 0.35 + j * 2.0944;
        x.globalAlpha = 0.85 * al * b;
        x.beginPath(); x.arc(cx, cy, Rd + 26 * q, st, st + 0.3 + 0.7 * b, false); x.stroke();
    }
    x.globalAlpha = 1;
}

function drawOpening(x) {
    x.globalAlpha = 1; x.fillStyle = '#0B0D0C'; x.fillRect(0, 0, W, H);
    waves(x, 1);
    bigDial(x, t, T);
    var reach = Math.sqrt(W * W + H * H) / 2 + 80 * S, band = 46 * S;
    var wave = t > 14.0 ? ((t - 14.0) * 150 * S) % (reach + 200 * S) : -99999;
    var inStory = t > 6.0 && t < 13.7, grow = sm((t - 6.2) / 0.8) * (1 - sm((t - 13.1) / 0.6));
    x.lineCap = 'round';
    for (var i = 0; i < P.length; i++) {
        var p = P[i];
        if (t < p.d) continue;
        var sp2 = Math.sqrt(p.vx * p.vx + p.vy * p.vy), px = p.x, py = p.y, g = p.g, m = p.m;
        var al = p.t ? 0.9 : 0.5 + 0.25 * Math.sin(p.age * 1.3 + p.ph) + 0.3 * (1 - m) * g;
        var depth = (1 - m) * g, rad = p.r * (1 + 0.4 * p.z * depth) * (1 - 0.25 * back(t) * (1 - m));
        al = cl(al) * (1 - depth * 0.75 * (0.5 - 0.5 * p.z));
        var hero = p.role && inStory;
        if (p.role) rad = rad * (1 + 0.45 * grow);
        if (sp2 > 60 * S && !hero) {
            x.strokeStyle = p.col; x.globalAlpha = 0.3; x.lineWidth = p.r * 1.3;
            x.beginPath(); x.moveTo(px - p.vx * 0.03, py - p.vy * 0.03); x.lineTo(px, py); x.stroke();
        }
        var dx = px - W / 2, dy = py - H / 2, r = Math.sqrt(dx * dx + dy * dy) + 0.01, q = wave - r;
        if (q > 0 && q < band) {
            var b = Math.sin(q / band * 3.1416);
            px += dx / r * b * 3.5 * S; py += dy / r * b * 3.5 * S; al = Math.min(1, al + b * 0.4); rad = rad * (1 + b * 0.5);
        }
        if (p.t && !hero && m > 0.99 && sp2 < 20 * S) { px += Math.sin(T * 1.7 + p.ph) * 0.5 * S; py += Math.cos(T * 1.3 + p.ph) * 0.5 * S; }
        x.globalAlpha = al; x.fillStyle = p.col;
        x.beginPath(); x.arc(px, py, Math.max(0.4, rad), 0, 6.2832, false); x.fill();
        x.globalAlpha = 1;
    }
}

// ---------- B: the hand-off, and C: the login (her code) ----------

function beginHandoff(at) {
    for (var i = 0; i < P.length; i++) { P[i].hx = P[i].x; P[i].hy = P[i].y; P[i].r = P[i].r / S; }   // her hand-off sizes are unscaled
    tb = at || 0;
}

// Jump from the opening straight to the login (a key or a click during the opening).
function skipToLogin() {
    if (tb >= 0 && tb >= 7) return;
    if (tb < 0) beginHandoff(0);
    tb = 7.5; skipCover = 1;
}
function inLogin() { return tb >= 0; }

function hills(x, al) {
    x.globalAlpha = al;
    x.fillStyle = '#0E1512'; x.beginPath(); x.moveTo(0, H);
    for (var u = 0; u <= W + 10 * k; u += 10 * k) { var uu = u / k; x.lineTo(u, (338 + Math.sin(uu * 0.008 + 1.2) * 14 + Math.sin(uu * 0.021) * 6) * k); }
    x.lineTo(W, H); x.closePath(); x.fill();
    x.fillStyle = '#080B0A'; x.beginPath(); x.moveTo(0, H);
    for (var v = 0; v <= W + 10 * k; v += 10 * k) { var vv = v / k; x.lineTo(v, (356 + Math.sin(vv * 0.006 + 3.1) * 12 + Math.sin(vv * 0.017 + 0.6) * 5) * k); }
    x.lineTo(W, H); x.closePath(); x.fill();
    x.globalAlpha = 1;
}

function pad(n) { return n < 10 ? '0' + n : '' + n; }
var DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
var MONS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

function slotPos(i, spin) { var a = -1.5708 + i / SL * 6.2832 + (spin || 0); return [W / 2 + Math.cos(a) * 30 * k, 238 * k + Math.sin(a) * 30 * k]; }

function land(slot, born) {
    var pool = [];
    for (var i = 0; i < stars.length; i++) if (!stars[i].gone || T > stars[i].gone + 3.5) pool.push(stars[i]);
    if (!pool.length) pool = stars;
    var s = pool[Math.floor(Math.random() * pool.length)];
    var fx = s ? s.ssx : W / 2, fy = s ? s.ssy : 0;
    if (s) s.gone = born;
    dots.push({ slot: slot, fx: fx, fy: fy, born: born, col: cols[slot % 3 === 0 ? 0 : slot % 3 === 1 ? 1 : 3], vx: 0, vy: 0, x: fx, y: fy });
}

// Each letter: a dot (up to 24; the letters beyond still count, they just add no dot).
function addChar() {
    if (mode !== 'idle') return;
    if (free.length) { var q = Math.floor(Math.random() * free.length), slot = free.splice(q, 1)[0]; land(slot, T); }
    hint = 'Press Enter to unlock';
}
function delChar(left) {
    if (mode !== 'idle') return;
    if (dots.length > left) { var d = dots.pop(); free.push(d.slot); }
    if (left === 0) hint = 'Type your password';
}
function clearAll() { if (mode !== 'idle') return; dots = []; shuffle(); hint = 'Type your password'; }
function emptyEnter() { hint = 'Type a password first'; hintT = T; }

// Enter: the arcs quicken while the password is checked.
function waiting() { if (mode === 'idle') { mode = 'wait'; tm = T; hint = ''; } }

// A good password: the rest of the dots fly in, then the ring spins and a pulse goes out.
function accepted() {
    var n = 0;
    while (free.length) { var q = Math.floor(Math.random() * free.length), slot = free.splice(q, 1)[0]; land(slot, T + 0.15 + n * 0.045); n++; }
    fillDur = 0.15 + n * 0.045 + 0.55;
    mode = 'fill'; tm = T; hint = '';
}

// A wrong one: the dial shakes and the dots scatter.
function rejected() {
    if (!dots.length) { for (var i = 0; i < 6; i++) { mode = 'idle'; addChar(); } for (var j = 0; j < dots.length; j++) dots[j].born = T - 1; }
    mode = 'wrong'; tm = T; hint = 'Not quite. Try again.';
    for (var q = 0; q < dots.length; q++) {
        var d = dots[q], p = slotPos(d.slot), a = Math.atan2(p[1] - 238 * k, p[0] - W / 2) + (Math.random() - 0.5) * 1.2, s = (90 + Math.random() * 170) * k;
        d.x = p[0]; d.y = p[1]; d.vx = Math.cos(a) * s; d.vy = Math.sin(a) * s;
    }
}

// Seconds since "Welcome back" (-1 before it), for the launch: her unlock ends at 4.6 (0.7 + 3.9, the last faint star in).
function welcomeFor() { return mode === 'ok' ? T - tm : -1; }

// D: made when the unlock starts. Her numbers: 90 rise from the ring, 64 fall onto the desktop dial (70% onto it, the
// rest onto its outer arcs).
function makeAfter(cx, cy, Rd, sp) {
    fly = []; fall = [];
    var three = [cols[0], cols[1], cols[3]], i, a, b, r1;
    for (i = 0; i < 90; i++) {
        a = Math.random() * 6.2832;
        fly.push({ sx: cx + Math.cos(a) * Rd, sy: cy + Math.sin(a) * Rd, ex: Math.random() * W, ey: (8 + Math.pow(Math.random(), 1.3) * 380 * 0.62) * k,
            dl: Math.random() * 0.6, r: (1.3 + Math.random() * 1.3) * k, sr: (0.5 + Math.random() * 0.9) * k,
            ph: Math.random() * 6.28, tw: 0.6 + Math.random() * 1.6, col: three[i % 3] });
    }
    for (i = 0; i < 64; i++) {
        b = Math.random() * 6.2832; r1 = Math.random() < 0.7 ? sp.r : sp.r + 36 * k;
        fall.push({ sx: sp.x + (Math.random() - 0.5) * W * 0.7, sy: (8 + Math.random() * 190) * k, ex: sp.x + Math.cos(b) * r1, ey: sp.y + Math.sin(b) * r1,
            born: 1.7 + Math.random() * 1.3, r: (0.7 + Math.random() * 0.6) * k });
    }
}
function dot(x, px, py, r, al, col) {
    if (al <= 0) return;
    x.globalAlpha = cl(al); x.fillStyle = col; x.beginPath(); x.arc(px, py, Math.max(0.3, r), 0, 6.2832, false); x.fill();
}

function drawLogin(x, dt) {
    var u0 = tb;
    var K = sm((u0 - 1.3) / 2.8), L = sm((u0 - 3.7) / 1.5), D = sm((u0 - 4.3) / Dd), B = sm((u0 - (4.3 + Dd * 0.62)) / 1.1), N = sm((u0 - (4.3 + Dd * 0.8)) / 1.1);
    var cx = W / 2, DY = 238 * k, Rd = 30 * k;
    if (mode === 'fill' && T - tm > fillDur) { mode = 'ok'; tm = T; hint = 'Welcome back'; }
    var e = T - tm;
    // D: her unlock clock starts 0.7 s after "Welcome back" (when the spin has settled).
    var tt = mode === 'ok' ? e - 0.7 : -1, A = tt >= 0 ? sm((tt - 0.4) / 0.8) : 0, da = tt >= 0 ? 1 - sm((tt - 0.9) / 0.6) : 1;

    x.globalAlpha = 1; x.fillStyle = '#0B0D0C'; x.fillRect(0, 0, W, H);
    if (K > 0) {
        var gr = x.createLinearGradient(0, 0, 0, H);
        gr.addColorStop(0, '#090B0E'); gr.addColorStop(0.7, '#0E1716'); gr.addColorStop(1, '#14261F');
        x.globalAlpha = K; x.fillStyle = gr; x.fillRect(0, 0, W, H);
        var mx = W * 0.17, my = 70 * k;
        x.globalAlpha = K * 0.9; x.fillStyle = '#DDE8E2'; x.beginPath(); x.arc(mx, my, 15 * k, 0, 6.2832, false); x.fill();
        x.fillStyle = '#0A0D0F'; x.beginPath(); x.arc(mx + 7 * k, my - 4 * k, 14 * k, 0, 6.2832, false); x.fill();
        x.globalAlpha = 1;
    }
    if (K < 1) waves(x, 1 - K);

    // the sparks: stars rise to their places, the rest drift up and fade
    for (var i = 0; i < P.length; i++) {
        var p = P[i], u2 = sm((u0 - 1.2 - p.dl) / 2.7), px, py, rad;
        if (p.star) {
            px = p.hx + (p.ssx - p.hx) * u2; py = p.hy + (p.ssy - p.hy) * u2 - Math.sin(u2 * 3.1416) * 26 * k;
            rad = (p.r + (p.sr / k - p.r) * u2) * k;
            var twk = 0.55 + 0.4 * Math.sin(T * p.tw + p.ph);
            // a star a letter took is gone, and comes back after a while (her login)
            var backK = p.gone ? (T < p.gone ? 1 : sm((T - p.gone - 1.5) / 2)) : 1;
            if (u2 < 1) { x.globalAlpha = (p.t ? 0.9 : 0.6) * (1 - u2); x.fillStyle = p.col; x.beginPath(); x.arc(px, py, rad, 0, 6.2832, false); x.fill(); }
            if (u2 > 0) {
                x.globalAlpha = u2 * twk * backK * (1 - 0.5 * L * (1 - A) * Math.exp(-((px - cx) * (px - cx)) / (2 * 150 * k * 150 * k)));
                x.fillStyle = '#E4EEE8'; x.beginPath(); x.arc(px, py, rad, 0, 6.2832, false); x.fill();
            }
        } else {
            if (u2 >= 1) continue;
            px = p.hx + p.dr * u2; py = p.hy - p.up * u2 * u2;
            rad = p.r * k * (1 - 0.5 * u2);
            x.globalAlpha = (p.t ? 0.9 : 0.6) * (1 - u2) * (1 - u2); x.fillStyle = p.col;
            x.beginPath(); x.arc(px, py, rad, 0, 6.2832, false); x.fill();
        }
    }
    x.globalAlpha = 1;
    if (K > 0) hills(x, K);

    x.textAlign = 'center'; x.textBaseline = 'middle';
    if (L > 0) {
        var d0 = new Date(), h = d0.getHours() % 12 || 12;
        x.globalAlpha = L * 0.95 * (1 - A); x.fillStyle = '#EDEFEE';
        x.font = fontAt(Math.min(68 * k, W * 0.11));
        x.fillText(h + ':' + pad(d0.getMinutes()), cx, (104 - (1 - L) * 8 - A * 10) * k);
        x.globalAlpha = L * 0.85 * (1 - A); x.fillStyle = '#9AA19D'; x.font = fontAt(15 * k);
        x.fillText(DAYS[d0.getDay()] + ', ' + MONS[d0.getMonth()] + ' ' + d0.getDate(), cx, (152 - (1 - L) * 8 - A * 10) * k);
    }

    if (D > 0 && da > 0) {
        var shake = mode === 'wrong' ? Math.sin(e * 42) * 7 * k * Math.exp(-e * 5) : 0, dx = cx + shake;
        var okp = mode === 'ok' ? sm(e / 0.9) : 0;
        var s0 = -1.5708, s1 = s0 + D * 6.2832;
        x.lineCap = 'round'; x.strokeStyle = ACC;
        x.globalAlpha = (0.12 + 0.2 * okp) * da; x.lineWidth = (7 + 4 * okp) * k; x.beginPath(); x.arc(dx, DY, Rd, s0, s1, false); x.stroke();
        x.globalAlpha = 0.95 * da; x.lineWidth = (1.5 + 1.5 * okp) * k; x.beginPath(); x.arc(dx, DY, Rd, s0, s1, false); x.stroke();
        x.strokeStyle = '#EDEFEE'; x.lineWidth = k;
        var nt = Math.floor(48 * D);
        for (var q = 0; q < nt; q++) {
            var an = s0 + q / 48 * 6.2832, big = q % 4 === 0;
            x.globalAlpha = (big ? 0.5 : 0.25) * da;
            x.beginPath(); x.moveTo(dx + Math.cos(an) * (Rd + 6 * k), DY + Math.sin(an) * (Rd + 6 * k));
            x.lineTo(dx + Math.cos(an) * (Rd + (big ? 12 : 9) * k), DY + Math.sin(an) * (Rd + (big ? 12 : 9) * k)); x.stroke();
        }
        if (B > 0) {
            rot += (0.12 + (mode === 'ok' ? 1.6 * okp : 0) + (mode === 'fill' || mode === 'wait' ? 0.5 : 0) + (dots.length && mode === 'idle' ? 0.25 : 0)) * dt;
            x.strokeStyle = ACC; x.lineWidth = 2 * k;
            for (var j = 0; j < 3; j++) {
                var st = rot + j * 2.0944;
                x.globalAlpha = 0.8 * B * da * (0.85 + 0.15 * Math.sin(T * 0.8));
                x.beginPath(); x.arc(dx, DY, Rd + 18 * k, st, st + 0.2 + 0.7 * B, false); x.stroke();
            }
        }
        if (mode === 'ok' && e > 0.7) {
            var pu = cl((e - 0.7) / 1.3);
            x.strokeStyle = ACC; x.globalAlpha = 0.6 * (1 - pu); x.lineWidth = (2 * (1 - pu) + 0.5) * k;
            x.beginPath(); x.arc(cx, DY, Rd + pu * 130 * k, 0, 6.2832, false); x.stroke();
        }
        for (var m2 = 0; m2 < dots.length; m2++) {
            var d = dots[m2], px2, py2, al2 = 1, r2 = 2.6 * k;
            if (T < d.born || tt >= 0.9) continue;
            if (mode === 'wrong') {
                var f = Math.exp(-3 * dt); d.vx *= f; d.vy *= f; d.x += d.vx * dt; d.y += d.vy * dt;
                px2 = d.x; py2 = d.y; al2 = 1 - sm((e - 0.5) / 0.9);
            } else {
                var spin = mode === 'ok' ? okp * okp * 6.2832 * 1.5 : 0, sp3 = slotPos(d.slot, spin), uu = sm((T - d.born) / 0.45);
                px2 = d.fx + (sp3[0] - d.fx) * uu + shake; py2 = d.fy + (sp3[1] - d.fy) * uu; r2 = (1.2 + 1.4 * uu) * k;
            }
            x.globalAlpha = cl(al2) * da; x.fillStyle = d.col; x.beginPath(); x.arc(px2, py2, r2, 0, 6.2832, false); x.fill();
        }
    }
    // D: the desktop dial draws itself at her spot while the ring's dots rise and faint stars fall into it.
    if (tt >= 0) {
        var sp = Dial.spot(W, H);
        if (!fly.length) makeAfter(cx, DY, Rd, sp);
        Dial.draw(x, sp.x, sp.y, sp.r, 1, sm((tt - 2.1) / 1.5), sm((tt - 2.9) / 1.0), 0, Dial.arcAngle(), T);
        if (tt >= 0.9) {
            var f, u;
            for (var q3 = 0; q3 < fly.length; q3++) {
                f = fly[q3]; u = sm((tt - 0.9 - f.dl) / 1.3);
                var rx = f.sx + (f.ex - f.sx) * u, ry = f.sy + (f.ey - f.sy) * u, rr = f.r + (f.sr - f.r) * u;
                dot(x, rx, ry, rr, (1 - u) * 0.95, f.col);
                dot(x, rx, ry, rr, u * (0.55 + 0.4 * Math.sin(T * f.tw + f.ph)), '#E4EEE8');
            }
            for (var q4 = 0; q4 < fall.length; q4++) {
                f = fall[q4]; if (tt < f.born) continue;
                u = sm((tt - f.born) / 0.7);
                var gone = 1 - sm((tt - f.born - 0.6) / 0.3);
                if (gone <= 0) continue;
                dot(x, f.sx + (f.ex - f.sx) * u, f.sy + (f.ey - f.sy) * u, f.r, 0.6 * gone * Math.min(1, (tt - f.born) / 0.15), '#CFE9DC');
            }
        }
        x.globalAlpha = 1;
    }
    if (mode === 'wrong' && e > 1.5) { dots = []; shuffle(); mode = 'idle'; }
    if (mode === 'idle' && hint === 'Not quite. Try again.' && e > 3.2) hint = 'Type your password';
    if (hint === 'Type a password first' && T - hintT > 2.2) hint = 'Type your password';

    if (N > 0) {
        x.globalAlpha = N * 0.95 * (1 - A); x.fillStyle = '#EDEFEE'; x.font = fontAt(15 * k);
        x.fillText(name, cx, 298 * k);
        x.globalAlpha = N * 0.85 * (1 - A); x.fillStyle = mode === 'ok' ? '#A8E3C6' : '#9AA19D'; x.font = fontAt(12 * k);
        x.fillText(hint, cx, 318 * k);
    }
    x.globalAlpha = 1;
}

// ---------- the clock of the whole scene ----------

function advance(dt) {
    dt = Math.min(0.033, Math.max(0, dt));
    t += dt; T += dt;
    if (tb < 0) {
        for (var i = 0; i < P.length; i++) { if (t >= P[i].d) step(P[i], dt, T, t); }
        if (t >= A_END) beginHandoff(0);
    } else {
        tb += dt;
    }
    if (skipCover > 0) skipCover = Math.max(0, skipCover - dt / 0.5);
    lastDt = dt;
}
var lastDt = 0;

// Jump to second `at` of the scene (the tests' still frames).
function settleTo(at) { while (t < at) advance(Math.min(1 / 60, at - t + 1e-6)); }

function draw(x) {
    x.reset();
    if (tb < 0) drawOpening(x); else drawLogin(x, lastDt);
    if (skipCover > 0) { x.globalAlpha = skipCover; x.fillStyle = '#0B0D0C'; x.fillRect(0, 0, W, H); x.globalAlpha = 1; }
}

// The last half second before her desktop starts: fade to the desktop's own dark.
function fadeOut(x, a) { x.globalAlpha = a; x.fillStyle = '#0F1010'; x.fillRect(0, 0, W, H); x.globalAlpha = 1; }
